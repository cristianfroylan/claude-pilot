import 'dart:async';
import 'dart:convert';

import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm/xterm.dart';

import '../../machines/providers/machines_provider.dart';

part 'ssh_session_provider.g.dart';

/// SSH terminal session provider.
///
/// Manages the full lifecycle of one SSH connection:
///   - SSHClient (transport) and SSHSession (PTY shell)
///   - xterm Terminal model (ANSI rendering state)
///   - Crash-safe transport error handling (T-03-03)
///   - Graceful cleanup on dispose (T-03-06)
///
/// Usage: `ref.watch(sshSessionProvider(machineId))`
/// Returns `AsyncValue<Terminal>` — loading while connecting, error on failure.
@riverpod
class SshSession extends _$SshSession {
  SSHClient? _client;

  // SSHSession from dartssh2 — distinct from this Riverpod class `SshSession`
  // (PascalCase). The dartssh2 type is `SSHSession` (all-caps prefix).
  // Stored as a field to allow sendText/sendBytes/resizeTerminal calls.
  SSHSession? _sshSession; // dartssh2 SSHSession (PTY shell)

  bool _disposed = false;

  final _permissionController = StreamController<String>.broadcast();

  /// Broadcast stream of raw stdout/stderr chunks for permission detection.
  Stream<String> get permissionStream => _permissionController.stream;

  static const maxAttempts = 3;

  @override
  Future<Terminal> build(String machineId) async {
    // Register cleanup FIRST — before any awaits — so dispose always fires.
    ref.onDispose(() {
      _disposed = true;
      _sshSession?.close();
      _client?.close();
      _permissionController.close(); // prevent stream leak (T-02-05)
    });

    final machine = ref.read(machineProvider.notifier).get(machineId);
    if (machine == null) throw StateError('Machine $machineId not found');

    final password =
        await ref.read(machineProvider.notifier).getPassword(machineId);

    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (_disposed) break;
      try {
        return await _connectOnce(
            machine.host, machine.port, machine.username, password);
      } catch (e) {
        lastError = e;
        _client?.close();
        _client = null;
        _sshSession = null;
        if (attempt < maxAttempts - 1 && !_disposed) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    throw lastError ?? StateError('Connection failed after $maxAttempts attempts');
  }

  Future<Terminal> _connectOnce(
      String host, int port, String username, String? password) async {
    // Establish SSH transport connection.
    _client = SSHClient(
      await SSHSocket.connect(host, port),
      username: username,
      onPasswordRequest: () => password ?? '',
      keepAliveInterval: const Duration(seconds: 30),
    );

    // CRITICAL — guard transport close (T-03-03 / SSH-03):
    // Without this, a network drop produces an unhandled SSHStateError crash.
    // With it, the error is routed to state = AsyncError, triggering the dialog.
    _client!.done.catchError((Object e) {
      if (!_disposed) state = AsyncError(e, StackTrace.current);
    });

    final terminal = Terminal(maxLines: 2000);

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
        terminal.write(data);
      } catch (_) {}
      _permissionController.add(data); // feed all stdout/stderr to permission detector
    }

    _sshSession!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(safeWrite);

    _sshSession!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(safeWrite);

    terminal.onOutput = (data) => _sshSession?.write(utf8.encode(data));

    return terminal;
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
