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
/// Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so this
/// provider rebuilds on each tick. Re-subscription is lightweight; .select() is not
/// supported on generated provider types in Riverpod 3.x / riverpod_generator 4.x.
@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) {
    // Watch the full session state and derive isActive from the value type.
    // Note: the SSH provider emits AsyncData on every countdown tick (1 Hz), so
    // this provider rebuilds on each tick. The re-subscription is lightweight and
    // the original CR-02 concern (stream gap dropping permission lines) is accepted
    // as a known limitation — .select() is not supported on generated provider types
    // in Riverpod 3.x / riverpod_generator 4.x.
    final sessionValue = ref.watch(sshSessionProvider(machineId)).value;
    final isActive = sessionValue is SshConnected ||
        sessionValue is SshReconnecting ||
        sessionValue is SshFailed;

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
        return _truncate(trimmed, 80);
      }
    }
    return null;
  }

  /// Truncates [s] to at most [maxChars] Unicode code points (runes), appending
  /// '...' if truncated. Uses runes instead of String.length (UTF-16 code units)
  /// to avoid splitting surrogate pairs when [s] contains emoji or supplementary
  /// CJK characters.
  String _truncate(String s, int maxChars) {
    final runes = s.runes.toList();
    if (runes.length <= maxChars) return s;
    // Reserve 3 chars for the ellipsis.
    return String.fromCharCodes(runes.take(maxChars - 3)) + '...';
  }
}
