import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/utils/biometric_guard.dart';
import '../providers/machines_provider.dart';
import '../widgets/machine_list_tile.dart';

class MachineListScreen extends ConsumerWidget {
  const MachineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machinesAsync = ref.watch(machineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Machines',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      body: machinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (machines) => machines.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                itemCount: machines.length,
                itemBuilder: (context, i) => MachineListTile(
                  machine: machines[i],
                  onTap: () =>
                      context.push('/machines/${machines[i].id}/terminal'),
                  onEdit: () async {
                    final ok = await requireBiometric();
                    if (ok && context.mounted) {
                      context.push('/machines/${machines[i].id}/edit');
                    }
                  },
                  onDelete: () async {
                    final ok = await requireBiometric();
                    if (ok) {
                      ref.read(machineProvider.notifier).delete(machines[i].id);
                    }
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/machines/add'),
        tooltip: 'Add Machine',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No machines yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first machine',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
