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
  final _folderPathCtrl = TextEditingController();
  List<String> _folderPaths = [];
  bool _obscurePassword = true;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _folderPathCtrl.dispose();
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
    _folderPaths = List<String>.from(machine.folderPaths);
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
      folderPaths: _folderPaths,
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

  void _addFolderPath() {
    final path = _folderPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _folderPaths.add(path);
      _folderPathCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    _loadExistingMachine();

    final isEdit = widget.machineId != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Machine' : 'Add Machine',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surfaceContainerHigh,
        actions: isEdit
            ? [
                Semantics(
                  label: 'Delete machine',
                  child: IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: colorScheme.error,
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
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Working folders',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                if (_folderPaths.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No folders configured. Add a path to enable the session picker.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _folderPaths.removeAt(oldIndex);
                        _folderPaths.insert(newIndex, item);
                      });
                    },
                    children: [
                      for (int i = 0; i < _folderPaths.length; i++)
                        Padding(
                          key: ValueKey('folder_$i'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Semantics(
                                label: 'Reorder',
                                child: const Icon(Icons.drag_handle),
                              ),
                              title: Text(
                                _folderPaths[i],
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: Semantics(
                                label: 'Remove folder path',
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () =>
                                      setState(() => _folderPaths.removeAt(i)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _folderPathCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Folder path',
                          hintText: '/home/user/projects/myapp',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _addFolderPath(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'Add folder path',
                      child: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addFolderPath,
                      ),
                    ),
                  ],
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
