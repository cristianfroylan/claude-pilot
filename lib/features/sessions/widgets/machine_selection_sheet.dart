import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../machines/providers/machines_provider.dart';

/// Bottom sheet for selecting a machine to open a new SSH session.
///
/// Displayed when the user taps the add button in SessionsScreen.
/// Dismissible — the user can drag down or tap outside to cancel.
class MachineSelectionSheet extends ConsumerWidget {
  final void Function(String machineId) onMachineTap;

  const MachineSelectionSheet({super.key, required this.onMachineTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final machinesAsync = ref.watch(machineProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — decorative, matches SessionPickerSheet pattern.
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sheet title — left-aligned, semibold.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Open a session',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),

              const SizedBox(height: 16),

              // Machine list or empty/error state.
              machinesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Error: $e'),
                ),
                data: (machines) => machines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No machines configured.',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                context.push('/machines/add');
                              },
                              child: const Text('Add a machine'),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: machines.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => Semantics(
                            label: 'Open session in ${machines[index].name}',
                            child: ListTile(
                              tileColor: colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(
                                Icons.computer_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              title: Text(
                                machines[index].name,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                machines[index].host,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context)
                                    .pop(); // pop FIRST (session_picker_sheet.dart pattern)
                                onMachineTap(machines[index].id);
                              },
                            ),
                          ),
                        ),
                      ),
              ),

              // Bottom padding — matches session_picker_sheet.dart pattern.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  32 + MediaQuery.of(context).padding.bottom,
                ),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
