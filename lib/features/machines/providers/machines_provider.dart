import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/machine.dart';
import '../../../core/repositories/machine_repository.dart';

part 'machines_provider.g.dart';

/// Riverpod AsyncNotifier for Machine CRUD.
/// Generated provider name: machineNotifierProvider.
/// (Named MachineNotifier to avoid collision with MachineRepository class.)
@riverpod
class MachineNotifier extends _$MachineNotifier {
  MachineRepository? _repo;

  @override
  Future<List<Machine>> build() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    _repo = MachineRepository(prefs, secure);
    return _repo!.loadAll();
  }

  Future<void> save(Machine machine, String password) async {
    await _repo?.save(machine, password);
    ref.invalidateSelf();
  }

  Future<void> delete(String machineId) async {
    await _repo?.delete(machineId);
    ref.invalidateSelf();
  }

  Machine? get(String machineId) {
    final machines = state.value;
    if (machines == null) return null;
    try {
      return machines.firstWhere((m) => m.id == machineId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getPassword(String machineId) =>
      _repo?.getPassword(machineId) ?? Future.value(null);
}
