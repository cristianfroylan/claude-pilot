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
@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) {
    final sessionAsync = ref.watch(sshSessionProvider(machineId));
    return sessionAsync.when(
      loading: () => const Stream.empty(),
      error: (_, __) => const Stream.empty(),
      data: (sessionState) {
        return switch (sessionState) {
          // No terminal yet — suppress the permission stream until connected.
          SshConnecting() => const Stream.empty(),
          // All other states carry a terminal — keep the permission stream live.
          SshConnected() ||
          SshReconnecting() ||
          SshFailed() =>
            ref
                .read(sshSessionProvider(machineId).notifier)
                .permissionStream
                .map(_detect),
        };
      },
    );
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
