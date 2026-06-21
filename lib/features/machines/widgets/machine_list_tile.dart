import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/machine.dart';
import '../providers/machine_status_provider.dart';

class MachineListTile extends ConsumerWidget {
  final Machine machine;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MachineListTile({
    super.key,
    required this.machine,
    required this.onTap,
    required this.onDelete,
  });

  static IconData _platformIcon(RemotePlatform platform) => switch (platform) {
        RemotePlatform.linux   => Icons.terminal,
        RemotePlatform.macos   => Icons.laptop_mac,
        RemotePlatform.windows => Icons.desktop_windows,
      };

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar máquina'),
          content: Text(
            '¿Eliminar "${machine.name}"? Se borrarán las credenciales guardadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusAsync = ref.watch(machineStatusProvider(machine));

    final Color dotColor;
    if (statusAsync.isLoading) {
      dotColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    } else if (statusAsync.hasError) {
      dotColor = colorScheme.error;
    } else {
      dotColor = switch (statusAsync.value) {
        MachineStatus.reachable   => Colors.green.shade400,
        MachineStatus.unreachable => colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        MachineStatus.error       => colorScheme.error,
        null                      => colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      };
    }

    return GestureDetector(
      onLongPress: () async {
        final confirm = await _confirmDelete(context);
        if (confirm == true) onDelete();
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Platform icon + status dot
              SizedBox(
                width: 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _platformIcon(machine.platform),
                      size: 22,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Name + connection info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${machine.username}@${machine.host}:${machine.port}  ·  ${machine.platform.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron hint
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
