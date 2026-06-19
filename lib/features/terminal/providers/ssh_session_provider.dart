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

  @override
  Future<Terminal> build(String machineId) async {
    // Register cleanup FIRST — before any awaits — so dispose always fires.
    ref.onDispose(() {
      _disposed = true;
      _sshSession?.close();
      _client?.close();
    });

    // Fetch machine metadata from the machine provider.
    final machine = ref.read(machineProvider.notifier).get(machineId);
    if (machine == null) {
      throw StateError('Machine $machineId not found');
    }

    // Fetch SSH password from flutter_secure_storage.
    final password =
        await ref.read(machineProvider.notifier).getPassword(machineId);

    // Establish SSH transport connection.
    _client = SSHClient(
      await SSHSocket.connect(machine.host, machine.port),
      username: machine.username,
      onPasswordRequest: () => password ?? '',
    );

    // CRITICAL — guard transport close (T-03-03 / SSH-03):
    // Without this, a network drop produces an unhandled SSHStateError crash.
    // With it, the error is routed to state = AsyncError, showing a SnackBar.
    _client!.done.catchError((Object e) {
      if (!_disposed) state = AsyncError(e, StackTrace.current);
    });

    // Create xterm Terminal model — ANSI rendering state machine.
    final terminal = Terminal(maxLines: 2000);

    // Open interactive PTY shell on the SSH connection.
    _sshSession = await _client!.shell(
      pty: const SSHPtyConfig(
        type: 'xterm-256color',
        width: 80,
        height: 24,
      ),
      environment: {
        'TERM': 'xterm-256color',
        'LANG': 'en_US.UTF-8',
      },
    );

    // Wire stdout → terminal (ANSI sequences render colors, cursor movement).
    _sshSession!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    // Wire stderr → terminal (same treatment — e.g., Claude Code stderr output).
    _sshSession!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    // Wire terminal keyboard output → SSH stdin.
    // Called when the user types directly in TerminalView (not InputBar).
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
