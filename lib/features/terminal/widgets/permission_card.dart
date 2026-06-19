import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/permission_detector_provider.dart';
import '../providers/ssh_session_provider.dart';

/// Sticky card that appears above InputBar when a Claude Code permission prompt
/// is detected in terminal output.
///
/// Shows the matched permission line and provides one-tap Approve (y\n) and
/// Reject (n\n) buttons. Both buttons immediately invalidate the detector
/// provider to dismiss the card on the same frame (T-02-04: no dismiss-reappear
/// loop from the echoed y/n character).
class PermissionCard extends ConsumerWidget {
  final String machineId;
  final String line;

  const PermissionCard({
    super.key,
    required this.machineId,
    required this.line,
  });

  void _approve(WidgetRef ref) {
    ref.read(sshSessionProvider(machineId).notifier).sendText('y\n');
    // Invalidate immediately so the card dismisses on the same frame,
    // before the echoed 'y' can re-trigger the detector (T-02-04, Pitfall 5).
    ref.invalidate(permissionDetectorProvider(machineId));
  }

  void _reject(WidgetRef ref) {
    ref.read(sshSessionProvider(machineId).notifier).sendText('n\n');
    // Invalidate immediately so the card dismisses on the same frame,
    // before the echoed 'n' can re-trigger the detector (T-02-04, Pitfall 5).
    ref.invalidate(permissionDetectorProvider(machineId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _reject(ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _approve(ref),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}
