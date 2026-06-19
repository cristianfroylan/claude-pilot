import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/permission_detector.dart';
import 'ssh_session_provider.dart';

part 'permission_detector_provider.g.dart';

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Emits the matched permission line (truncated to 80 chars) when a prompt is
/// detected, or null when no permission prompt is present. The null emission
/// drives the AnimatedSwitcher to hide the PermissionCard.
///
/// Detection is gated on session state — emits Stream.empty() while connecting
/// or on error, so the card never appears when there is no active SSH session.
@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) {
    final sessionAsync = ref.watch(sshSessionProvider(machineId));
    return sessionAsync.when(
      loading: () => const Stream.empty(),
      error: (_, __) => const Stream.empty(),
      data: (_) {
        final notifier = ref.read(sshSessionProvider(machineId).notifier);
        return notifier.permissionStream.map(_detect);
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
