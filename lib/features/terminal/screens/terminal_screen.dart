import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub screen — full implementation in Plan 03.
class TerminalScreen extends ConsumerWidget {
  final String machineId;

  const TerminalScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terminal: $machineId'),
      ),
      body: Center(
        child: Text('Terminal: $machineId'),
      ),
    );
  }
}
