import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/machine.dart';
import '../providers/machine_status_provider.dart';

class MachineListTile extends ConsumerWidget {
  final Machine machine;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MachineListTile({
    super.key,
    required this.machine,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete machine?'),
        content: Text(
          'This will remove ${machine.name} and its saved credentials. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Machine'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(machineStatusProvider(machine));

    final Color dotColor;
    if (statusAsync.isLoading) {
      dotColor = Colors.grey;
    } else if (statusAsync.hasError) {
      dotColor = Theme.of(context).colorScheme.error;
    } else {
      dotColor = switch (statusAsync.value) {
        MachineStatus.reachable => Colors.green,
        MachineStatus.unreachable => Colors.grey,
        MachineStatus.error => Theme.of(context).colorScheme.error,
        null => Colors.grey,
      };
    }

    return Dismissible(
      key: Key(machine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        title: Text(
          machine.name,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${machine.username}@${machine.host}:${machine.port}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
        trailing: Semantics(
          label: 'Edit machine',
          child: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
        ),
      ),
    );
  }
}
