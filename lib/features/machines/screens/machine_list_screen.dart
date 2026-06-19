import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub screen — full implementation in Plan 02.
class MachineListScreen extends ConsumerWidget {
  const MachineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machines'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      body: const Center(
        child: Text('No machines yet'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Add Machine',
        child: const Icon(Icons.add),
      ),
    );
  }
}
