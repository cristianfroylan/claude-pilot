import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine.dart';

class MachineRepository {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _machinesKey = 'machines_v1';
  static String _passwordKey(String id) => 'ssh_password_$id';

  MachineRepository(this._prefs, this._secure);

  Future<List<Machine>> loadAll() async {
    final jsonList = _prefs.getStringList(_machinesKey) ?? [];
    return jsonList
        .map((s) => Machine.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(Machine machine, String password) async {
    final machines = await loadAll();
    final index = machines.indexWhere((m) => m.id == machine.id);
    if (index >= 0) {
      machines[index] = machine;
    } else {
      machines.add(machine);
    }
    await _prefs.setStringList(
      _machinesKey,
      machines.map((m) => jsonEncode(m.toJson())).toList(),
    );
    await _secure.write(key: _passwordKey(machine.id), value: password);
  }

  Future<void> delete(String machineId) async {
    final machines = await loadAll();
    machines.removeWhere((m) => m.id == machineId);
    await _prefs.setStringList(
      _machinesKey,
      machines.map((m) => jsonEncode(m.toJson())).toList(),
    );
    await _secure.delete(key: _passwordKey(machineId));
  }

  Future<String?> getPassword(String machineId) =>
      _secure.read(key: _passwordKey(machineId));
}
