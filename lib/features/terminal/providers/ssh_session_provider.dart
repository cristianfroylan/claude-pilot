import 'dart:async';
import 'dart:convert';

import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm/xterm.dart';

import '../../machines/providers/machines_provider.dart';
import '../models/ssh_session_state.dart';

part 'ssh_session_provider.g.dart';

/// Top-level function to disable Riverpod 3 auto-retry.
///
/// Must be top-level (not static, not lambda) — static method references cause
/// a PrefixedIdentifierImpl cast error in riverpod_generator (GitHub #4332).
Duration? _noRetry(int retryCount, Object error) => null;

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection and its reconnection state
/// machine:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state, promoted to instance field)
///   - Initial retry loop: 5 attempts, backoff 1/2/4/8/16 seconds (RECON-01)
///   - Mid-session retry loop: 3 attempts, backoff 2/4/8 seconds (RECON-02)
///   - Per-second countdown via Timer.periodic exposed on SshSessionState
///   - cancel() and reconnect() public methods (RECON-03, RECON-04)
///   - Terminal scrollback preserved across all reconnect attempts (RECON-05)
///   - Graceful cleanup on dispose
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<SshSessionState>` — always AsyncData after first emit.
@Riverpod(retry: _noRetry)
class SshSession extends _$SshSession {
  SSHClient? _client;

  // SSHSession from dartssh2 — distinct from this Riverpod class `SshSession`
  // (PascalCase). The dartssh2 type is `SSHSession` (all-caps prefix).
  // Stored as a field to allow sendText/sendBytes/resizeTerminal calls.
  SSHSession? _sshSession; // dartssh2 SSHSession (PTY shell)

  /// xterm Terminal instance — promoted from local variable to instance field
  /// so it survives every reconnect attempt without destroying scrollback (RECON-05).
  Terminal? _terminal;

  bool _disposed = false;
  bool _isMidSession = false;
  bool _cancelRequested = false;
  Timer? _countdownTimer;

  /// Generation counter to guard against stale done-callbacks from replaced
  /// SSHClient instances firing into the wrong connection (Pitfall 5).
  int _connectionGeneration = 0;

  /// StreamSubscriptions for stdout/stderr — cancelled and re-registered
  /// on each _connectOnce call to avoid duplicate listeners (Pitfall 6).
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  final _permissionController = StreamController<String>.broadcast();

  /// Broadcast stream of raw stdout/stderr chunks for permission detection.
  Stream<String> get permissionStream => _permissionController.stream;

  static const _initialMaxAttempts = 5;
  static const _midSessionMaxAttempts = 3;
  static const _initialBackoff = [1, 2, 4, 8, 16]; // seconds
  static const _midSessionBackoff = [2, 4, 8]; // seconds

  @override
  Future<SshSessionState> build(String machineId) async {
    // Register cleanup FIRST — before any awaits — so dispose always fires.
    ref.onDispose(() {
      _disposed = true;
      _countdownTimer?.cancel();
      _stdoutSub?.cancel();
      _stderrSub?.cancel();
      _sshSession?.close();
      _client?.close();
      _permissionController.close(); // prevent stream leak
    });

    // Create the Terminal once per provider lifetime; reuse it on all reconnects.
    _terminal ??= Terminal(maxLines: 2000);

    _cancelRequested = false;
    _isMidSession = false;

    final machine = ref.read(machineProvider.notifier).get(machineId);
    if (machine == null) throw StateError('Machine $machineId not found');

    final password =
        await ref.read(machineProvider.notifier).getPassword(machineId);

    // Run the initial retry loop (5 attempts, backoff 1/2/4/8/16s).
    for (var attempt = 1; attempt <= _initialMaxAttempts; attempt++) {
      if (_cancelRequested || _disposed) {
        return SshFailed(_terminal!);
      }

      state = AsyncData(SshConnecting(
        attempt: attempt,
        maxAttempts: _initialMaxAttempts,
        secondsLeft: 0,
      ));

      try {
        await _connectOnce(
            machine.host, machine.port, machine.username, password);

        // Success — install the mid-session done-watcher with generation guard.
        _installDoneWatcher();

        _isMidSession = true;
        return SshConnected(_terminal!);
      } catch (_) {
        _client?.close();
        _client = null;
        _sshSession = null;

        // Wait with countdown before next attempt (not after the last one).
        if (attempt < _initialMaxAttempts && !_cancelRequested && !_disposed) {
          await _waitWithCountdown(
            _initialBackoff[attempt - 1],
            isMidSession: false,
            attempt: attempt,
            maxAttempts: _initialMaxAttempts,
          );
        }
      }
    }

    return SshFailed(_terminal!);
  }

  /// Install a mid-session done-watcher on the current [_client] with a
  /// generation guard so stale callbacks from replaced clients do not fire
  /// into the wrong connection (Pitfall 5).
  void _installDoneWatcher() {
    final gen = ++_connectionGeneration;
    _client!.done.then(
      (_) {
        if (!_disposed && _isMidSession && gen == _connectionGeneration) {
          _runMidSessionRetry();
        }
      },
      onError: (Object _) {
        if (!_disposed && _isMidSession && gen == _connectionGeneration) {
          _runMidSessionRetry();
        }
      },
    );
  }

  /// Wait [seconds] with a per-second countdown, emitting state updates.
  ///
  /// Cancels immediately if [_cancelRequested] or [_disposed] is set.
  Future<void> _waitWithCountdown(
    int seconds, {
    required bool isMidSession,
    required int attempt,
    required int maxAttempts,
  }) async {
    // Pitfall 2: cancel any existing timer before creating a new one.
    _countdownTimer?.cancel();
    _countdownTimer = null;

    var secondsLeft = seconds;
    final completer = Completer<void>();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsLeft--;

      if (_cancelRequested || _disposed || secondsLeft <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        if (!completer.isCompleted) completer.complete();
        return;
      }

      if (isMidSession) {
        state = AsyncData(SshReconnecting(
          terminal: _terminal!,
          attempt: attempt,
          maxAttempts: maxAttempts,
          secondsLeft: secondsLeft,
        ));
      } else {
        state = AsyncData(SshConnecting(
          attempt: attempt,
          maxAttempts: maxAttempts,
          secondsLeft: secondsLeft,
        ));
      }
    });

    await completer.future;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Mid-session retry loop — triggered when SSHClient.done fires after a
  /// successful initial connection (RECON-02).
  ///
  /// Runs 3 attempts with backoff 2/4/8s. The Terminal instance is preserved.
  Future<void> _runMidSessionRetry() async {
    if (_disposed) return;
    _cancelRequested = false;

    // Close the dead client from the previous connection.
    _client?.close();
    _client = null;
    _sshSession = null;

    // machineId is exposed as a getter by the generated _$SshSession base class.
    final machine = ref.read(machineProvider.notifier).get(machineId);
    if (machine == null) {
      state = AsyncData(SshFailed(_terminal!));
      return;
    }
    final password =
        await ref.read(machineProvider.notifier).getPassword(machineId);

    for (var attempt = 1; attempt <= _midSessionMaxAttempts; attempt++) {
      if (_cancelRequested || _disposed) {
        state = AsyncData(SshFailed(_terminal!));
        return;
      }

      // Show countdown before attempting — user sees "retrying in Xs".
      state = AsyncData(SshReconnecting(
        terminal: _terminal!,
        attempt: attempt,
        maxAttempts: _midSessionMaxAttempts,
        secondsLeft: _midSessionBackoff[attempt - 1],
      ));

      await _waitWithCountdown(
        _midSessionBackoff[attempt - 1],
        isMidSession: true,
        attempt: attempt,
        maxAttempts: _midSessionMaxAttempts,
      );

      if (_cancelRequested || _disposed) {
        state = AsyncData(SshFailed(_terminal!));
        return;
      }

      try {
        await _connectOnce(
            machine.host, machine.port, machine.username, password);

        // Success — install fresh done-watcher.
        _installDoneWatcher();

        state = AsyncData(SshConnected(_terminal!));
        return;
      } catch (_) {
        _client?.close();
        _client = null;
        _sshSession = null;
      }
    }

    state = AsyncData(SshFailed(_terminal!));
  }

  /// Establish one SSH connection attempt.
  ///
  /// Mutates [_client], [_sshSession]; wires stdout/stderr to [_terminal!].
  /// Does NOT install the done-watcher (caller does it with generation guard).
  /// Does NOT create a new Terminal — uses [_terminal!] (instance field).
  /// Cancels previous stdout/stderr subscriptions before re-subscribing (Pitfall 6).
  Future<void> _connectOnce(
      String host, int port, String username, String? password) async {
    // Cancel stale subscriptions from any previous connection (Pitfall 6).
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;

    _client = SSHClient(
      await SSHSocket.connect(host, port),
      username: username,
      onPasswordRequest: () => password ?? '',
      keepAliveInterval: const Duration(seconds: 30),
    );

    _sshSession = await _client!.shell(
      pty: const SSHPtyConfig(
        type: 'xterm-256color',
        width: 80,
        height: 24,
      ),
    );

    // xterm 4.0.0 bug: EscapeParser._csiHandleSgr throws RangeError on certain
    // SGR sequences (e.g. 256-color codes where params.length < expected).
    // Catch and discard to keep the stream alive — the byte is lost but the
    // session continues rendering correctly for all other sequences.
    void safeWrite(String data) {
      try {
        _terminal!.write(data);
      } catch (_) {}
      // Guard against StateError if _permissionController is closed (dispose race).
      if (!_permissionController.isClosed) {
        _permissionController.add(data); // feed all stdout/stderr to permission detector
      }
    }

    _stdoutSub = _sshSession!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(safeWrite);

    _stderrSub = _sshSession!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(safeWrite);

    _terminal!.onOutput = (data) => _sshSession?.write(utf8.encode(data));
  }

  /// Stop the active retry loop. Sets [_cancelRequested] so the next loop
  /// iteration lands in SshFailed (RECON-03).
  void cancel() {
    _cancelRequested = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Attempt one manual reconnection after automatic retries are exhausted
  /// (RECON-04). Spec: "attempt one more connection manually" — single try,
  /// no loop. Reuses [_terminal!] so scrollback is preserved (RECON-05).
  ///
  /// Does NOT call ref.invalidateSelf() (Pitfall 1 — would destroy scrollback).
  Future<void> reconnect() async {
    if (_disposed) return;
    _cancelRequested = false;

    final machine = ref.read(machineProvider.notifier).get(machineId);
    if (machine == null) {
      state = AsyncData(SshFailed(_terminal!));
      return;
    }
    final password =
        await ref.read(machineProvider.notifier).getPassword(machineId);

    // Emit the appropriate connecting state depending on whether we were in
    // a mid-session context or an initial-connect context.
    if (_isMidSession) {
      state = AsyncData(SshReconnecting(
        terminal: _terminal!,
        attempt: 1,
        maxAttempts: 1,
        secondsLeft: 0,
      ));
    } else {
      state = AsyncData(SshConnecting(
        attempt: 1,
        maxAttempts: 1,
        secondsLeft: 0,
      ));
    }

    try {
      await _connectOnce(
          machine.host, machine.port, machine.username, password);

      // Install done-watcher with generation guard.
      _installDoneWatcher();

      _isMidSession = true;
      state = AsyncData(SshConnected(_terminal!));
    } catch (_) {
      _client?.close();
      _client = null;
      _sshSession = null;
      state = AsyncData(SshFailed(_terminal!));
    }
  }

  /// Send a text command to the remote shell (InputBar "Send" button).
  /// Caller is responsible for appending '\n' if a newline is desired.
  void sendText(String text) => _sshSession?.write(utf8.encode(text));

  /// Send raw control bytes to the remote shell.
  /// Used for Ctrl+C (0x03), Ctrl+D (0x04), ESC (0x1b).
  void sendBytes(List<int> bytes) =>
      _sshSession?.write(Uint8List.fromList(bytes));

  /// Notify the remote PTY of a terminal resize.
  /// Called by TerminalViewWrapper via LayoutBuilder whenever dimensions change.
  void resizeTerminal(int cols, int rows) =>
      _sshSession?.resizeTerminal(cols, rows, 0, 0);
}
