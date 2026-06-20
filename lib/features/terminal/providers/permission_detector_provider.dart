import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/permission_detector.dart';
import '../models/ssh_session_state.dart';
import 'ssh_session_provider.dart';

part 'permission_detector_provider.g.dart';

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Emits the matched permission line (truncated to 80 chars) when a prompt is
/// detected, or null when no permission prompt is present. The null emission
/// drives the AnimatedSwitcher to hide the PermissionCard.
///
/// Detection is gated on session state — emits Stream.empty() while the initial
/// connection is in progress (SshConnecting, loading, error). For all states that
/// carry an active Terminal (SshConnected, SshReconnecting, SshFailed), the
/// permission stream remains live so permission prompts still surface from the
/// scrollback even during a mid-session drop.
///
/// CR-02: Uses .select() to watch only the state TYPE, not the full state value.
/// The SSH provider emits AsyncData on every countdown tick (1 Hz); watching the
/// full state would rebuild and re-subscribe the broadcast stream on each tick,
/// dropping permission lines during the ~0 ms subscription gap.
@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) {
    // Watch only the connectivity class (whether a terminal-bearing state is active).
    // This does NOT rebuild on every countdown tick — only when the state TYPE changes
    // (e.g., SshConnecting→SshConnected, SshConnected→SshReconnecting).
    final isActive = ref.watch(
      sshSessionProvider(machineId).select((async) {
        final s = async.value;
        return s is SshConnected || s is SshReconnecting || s is SshFailed;
      }),
    );

    if (!isActive) return const Stream.empty();

    return ref
        .read(sshSessionProvider(machineId).notifier)
        .permissionStream
        .map(_detect);
  }

  /// Scans a stdout chunk for permission patterns.
  ///
  /// Iterates lines in reverse to find the most-recent matching line.
  /// Returns the matched line trimmed and truncated to 80 chars, or null
  /// when no line matches kPermissionPattern.
  String? _detect(String chunk) {
    final pattern = RegExp(kPermissionPattern);
    final lines = chunk.split('\n');
    for (final line in lines.reversed) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && pattern.hasMatch(trimmed)) {
        if (trimmed.length > 80) {
          return '${trimmed.substring(0, 77)}...';
        }
        return trimmed;
      }
    }
    return null;
  }
}
