import 'package:xterm/xterm.dart';

/// Contract for the SSH session lifecycle state machine.
///
/// All Phase 4 components pattern-match exhaustively on these four variants.
/// The [Terminal] instance is carried in every variant that represents a
/// connected-or-later state so the xterm scrollback buffer is never destroyed
/// by a reconnection cycle (RECON-05).
///
/// This sealed class lives inside `AsyncData(...)` — the provider never emits
/// `AsyncLoading` or `AsyncError` after first connection, ensuring the
/// [TerminalView] widget stays mounted at all times.
sealed class SshSessionState {
  const SshSessionState();
}

/// Initial connection attempt in progress. No terminal has been rendered yet
/// (pre-connection state). The UI shows a full-screen overlay with spinner,
/// attempt counter, and countdown until next retry.
class SshConnecting extends SshSessionState {
  const SshConnecting({
    required this.attempt,
    required this.maxAttempts,
    required this.secondsLeft,
  });

  /// Current attempt number (1-based).
  final int attempt;

  /// Maximum number of attempts for initial connection (5 per RECON-01).
  final int maxAttempts;

  /// Seconds remaining before the next retry attempt fires.
  final int secondsLeft;
}

/// Connected and live. The SSH shell is active and the terminal is rendering
/// remote output. Normal operation state.
class SshConnected extends SshSessionState {
  const SshConnected(this.terminal);

  /// The live xterm Terminal instance carrying the scrollback buffer.
  final Terminal terminal;
}

/// Mid-session drop detected: the SSH transport closed unexpectedly while a
/// session was active. The terminal is kept alive so the scrollback buffer is
/// preserved. The UI shows an inline banner at the top of the terminal view
/// with attempt counter and countdown (RECON-02).
class SshReconnecting extends SshSessionState {
  const SshReconnecting({
    required this.terminal,
    required this.attempt,
    required this.maxAttempts,
    required this.secondsLeft,
  });

  /// The xterm Terminal instance preserved from the active session (RECON-05).
  final Terminal terminal;

  /// Current reconnection attempt number (1-based).
  final int attempt;

  /// Maximum number of mid-session reconnection attempts (3 per RECON-02).
  final int maxAttempts;

  /// Seconds remaining before the next retry attempt fires.
  final int secondsLeft;
}

/// All automatic retries exhausted. The terminal is kept alive so the user can
/// read prior output and tap a manual Retry button (RECON-04). The provider
/// exposes a public `reconnect()` method that re-runs the retry loop without
/// recreating the [Terminal] instance.
class SshFailed extends SshSessionState {
  const SshFailed(this.terminal);

  /// The xterm Terminal instance preserved from the last active session (RECON-05).
  final Terminal terminal;
}
