import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/permission_detector_provider.dart';
import '../providers/ssh_session_provider.dart';

class PermissionCard extends ConsumerWidget {
  final String machineId;
  final String tabId;
  final String line;

  const PermissionCard({
    super.key,
    required this.machineId,
    required this.tabId,
    required this.line,
  });

  void _approve(WidgetRef ref) {
    ref.read(sshSessionProvider(machineId, tabId).notifier).sendText('y\n');
    ref.invalidate(permissionDetectorProvider(machineId, tabId));
  }

  void _reject(WidgetRef ref) {
    ref.read(sshSessionProvider(machineId, tabId).notifier).sendText('n\n');
    ref.invalidate(permissionDetectorProvider(machineId, tabId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurfaceVariant),
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
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
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
