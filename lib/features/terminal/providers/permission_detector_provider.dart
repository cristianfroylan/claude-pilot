import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/permission_detector.dart';
import '../models/ssh_session_state.dart';
import 'ssh_session_provider.dart';

part 'permission_detector_provider.g.dart';

/// StreamNotifier that scans terminal stdout for Claude Code permission prompts.
///
/// Keyed by (machineId, tabId) so each tab has an independent detector instance
/// even when two tabs connect to the same machine (SESS-TAB-01).
@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId, String tabId) {
    final sessionValue =
        ref.watch(sshSessionProvider(machineId, tabId)).value;
    final isActive = sessionValue is SshConnected ||
        sessionValue is SshReconnecting ||
        sessionValue is SshFailed;

    if (!isActive) return const Stream.empty();

    return ref
        .read(sshSessionProvider(machineId, tabId).notifier)
        .permissionStream
        .map(_detect);
  }

  String? _detect(String chunk) {
    final pattern = RegExp(kPermissionPattern);
    final lines = chunk.split('\n');
    for (final line in lines.reversed) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && pattern.hasMatch(trimmed)) {
        return _truncate(trimmed, 80);
      }
    }
    return null;
  }

  String _truncate(String s, int maxChars) {
    final runes = s.runes.toList();
    if (runes.length <= maxChars) return s;
    return String.fromCharCodes(runes.take(maxChars - 3)) + '...';
  }
}
