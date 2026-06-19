import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/machine.dart';
import '../providers/machines_provider.dart';

class AddEditMachineScreen extends ConsumerStatefulWidget {
  final String? machineId;

  const AddEditMachineScreen({super.key, this.machineId});

  @override
  ConsumerState<AddEditMachineScreen> createState() =>
      _AddEditMachineScreenState();
}

class _AddEditMachineScreenState extends ConsumerState<AddEditMachineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _loadExistingMachine() {
    if (_loaded || widget.machineId == null) return;
    final machine = ref.read(machineProvider.notifier).get(widget.machineId!);
    if (machine == null) return;
    _nameCtrl.text = machine.name;
    _hostCtrl.text = machine.host;
    _portCtrl.text = machine.port.toString();
    _usernameCtrl.text = machine.username;
    // Load password from secure storage
    ref
        .read(machineProvider.notifier)
        .getPassword(widget.machineId!)
        .then((password) {
      if (password != null && mounted) {
        _passwordCtrl.text = password;
      }
    });
    _loaded = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.machineId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final machine = Machine(
      id: id,
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _usernameCtrl.text.trim(),
    );

    await ref
        .read(machineProvider.notifier)
        .save(machine, _passwordCtrl.text);

    if (mounted) context.pop();
  }

  Future<void> _deleteAndPop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete machine?'),
        content: Text(
          'This will remove ${_nameCtrl.text} and its saved credentials. '
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
    if (confirmed == true && mounted) {
      await ref
          .read(machineProvider.notifier)
          .delete(widget.machineId!);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExistingMachine();

    final isEdit = widget.machineId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Machine' : 'Add Machine',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        actions: isEdit
            ? [
                Semantics(
                  label: 'Delete machine',
                  child: IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _deleteAndPop,
                  ),
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'My Laptop',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: '192.168.1.100',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '22',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final port = int.tryParse(v.trim());
                    if (port == null || port < 1 || port > 65535) {
                      return 'Port must be between 1 and 65535';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'cristian',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '••••••••',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save Machine'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
