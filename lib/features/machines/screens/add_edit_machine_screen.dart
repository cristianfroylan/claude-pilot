import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub screen — full implementation in Plan 02.
class AddEditMachineScreen extends ConsumerWidget {
  final String? machineId;

  const AddEditMachineScreen({super.key, this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(machineId == null ? 'Add Machine' : 'Edit Machine'),
      ),
      body: const Center(
        child: Text('Add Machine'),
      ),
    );
  }
}
