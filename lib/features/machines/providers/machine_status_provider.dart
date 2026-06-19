import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/machine.dart';

enum MachineStatus { reachable, unreachable, error }

/// TCP reachability probe for a machine.
/// Runs independently from the SSH session — tests port reachability only.
/// autoDispose ensures the provider is GC'd when the tile scrolls off screen.
final machineStatusProvider =
    FutureProvider.autoDispose.family<MachineStatus, Machine>(
  (ref, machine) async {
    try {
      final socket = await Socket.connect(
        machine.host,
        machine.port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return MachineStatus.reachable;
    } on SocketException {
      return MachineStatus.unreachable;
    } catch (_) {
      return MachineStatus.error;
    }
  },
);
