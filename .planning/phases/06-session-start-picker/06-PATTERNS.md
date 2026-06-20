# Phase 6: Session Start Picker — Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 5 (1 new, 4 modified)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/core/models/machine.dart` | model | CRUD | `lib/core/models/machine.dart` (self — extend) | exact |
| `lib/core/repositories/machine_repository.dart` | repository | CRUD | `lib/core/repositories/machine_repository.dart` (self — no change if toJson/fromJson updated) | exact |
| `lib/features/machines/screens/add_edit_machine_screen.dart` | component | CRUD | `lib/features/machines/screens/add_edit_machine_screen.dart` (self — extend) | exact |
| `lib/features/terminal/screens/terminal_screen.dart` | component | event-driven | `lib/features/terminal/widgets/input_bar.dart` | role-match |
| `lib/features/terminal/widgets/session_picker_sheet.dart` | component | request-response | `lib/features/terminal/widgets/voice_bottom_sheet.dart` | exact |

---

## Pattern Assignments

### `lib/core/models/machine.dart` (model, CRUD)

**Analog:** Self — existing file is the pattern base. Extend it; do not restructure.

**Existing field + constructor pattern** (lines 1–14):
```dart
class Machine {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;

  const Machine({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
  });
```

**copyWith pattern** (lines 34–46) — add `folderPaths` param following the exact same null-coalescing convention:
```dart
Machine copyWith({
  String? name,
  String? host,
  int? port,
  String? username,
}) =>
    Machine(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
    );
```
New field follows the same pattern:
```dart
// Add to copyWith signature:
List<String>? folderPaths,
// Add to Machine(...) constructor call:
folderPaths: folderPaths ?? this.folderPaths,
```

**fromJson pattern** (lines 48–54) — existing style uses direct cast `as Type`. New field uses nullable cast + default:
```dart
factory Machine.fromJson(Map<String, dynamic> json) => Machine(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
    );
```
New field appended using backward-compat null fallback (existing machines have no `folderPaths` key):
```dart
// Append to fromJson:
folderPaths: (json['folderPaths'] as List<dynamic>?)?.cast<String>() ?? const [],
```

**toJson pattern** (lines 56–62) — append new key to the existing map literal:
```dart
Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
    };
// Add:
      'folderPaths': folderPaths,
```

**Default value** — `Machine.generate` and the main constructor both need `folderPaths = const []` as a named parameter with a default. No required annotation.

---

### `lib/core/repositories/machine_repository.dart` (repository, CRUD)

**Analog:** Self — no logic change needed. The repository stores machines via `jsonEncode(m.toJson())` and loads via `Machine.fromJson(jsonDecode(s))`. Once `Machine.toJson` includes `folderPaths` and `Machine.fromJson` has the backward-compat default, the repository requires zero changes.

**Storage pattern** (lines 17–36) — verified; `folderPaths` flows transparently through this:
```dart
static const _machinesKey = 'machines_v1';

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
```

**No new storage key.** `folderPaths` serializes inside the existing per-machine JSON blob under `machines_v1`.

---

### `lib/features/machines/screens/add_edit_machine_screen.dart` (component, CRUD)

**Analog:** Self — extend the existing `ConsumerStatefulWidget`. Component A (Folder Path Editor) is inserted between the Password field and Save button.

**Widget class + state pattern** (lines 8–16):
```dart
class AddEditMachineScreen extends ConsumerStatefulWidget {
  final String? machineId;
  const AddEditMachineScreen({super.key, this.machineId});

  @override
  ConsumerState<AddEditMachineScreen> createState() =>
      _AddEditMachineScreenState();
}
```

**Controller declaration pattern** (lines 19–26) — new state fields follow the same pattern:
```dart
// Existing controllers:
final _nameCtrl = TextEditingController();
final _passwordCtrl = TextEditingController();
bool _obscurePassword = true;
bool _loaded = false;

// New fields to add (same style):
final _folderPathCtrl = TextEditingController();
List<String> _folderPaths = [];
```

**dispose pattern** (lines 29–36) — new controller must be disposed here:
```dart
@override
void dispose() {
  _nameCtrl.dispose();
  _hostCtrl.dispose();
  _portCtrl.dispose();
  _usernameCtrl.dispose();
  _passwordCtrl.dispose();
  // Add:
  _folderPathCtrl.dispose();
  super.dispose();
}
```

**_loadExistingMachine pattern** (lines 38–56) — load `folderPaths` from the machine here:
```dart
void _loadExistingMachine() {
  if (_loaded || widget.machineId == null) return;
  final machine = ref.read(machineProvider.notifier).get(widget.machineId!);
  if (machine == null) return;
  _nameCtrl.text = machine.name;
  // ... existing fields ...
  // Add:
  _folderPaths = List<String>.from(machine.folderPaths);
  _loaded = true;
}
```

**_save pattern** (lines 58–76) — pass `folderPaths` when constructing Machine:
```dart
final machine = Machine(
  id: id,
  name: _nameCtrl.text.trim(),
  host: _hostCtrl.text.trim(),
  port: int.parse(_portCtrl.text.trim()),
  username: _usernameCtrl.text.trim(),
  // Add:
  folderPaths: _folderPaths,
);
```

**Form field insertion point** (lines 216–224) — insert Component A between Password field's `SizedBox(height: 24)` and the `FilledButton`:
```dart
// Existing last SizedBox before Save:
const SizedBox(height: 24),
// INSERT Component A here (section divider + ReorderableListView + add path row)
SizedBox(
  width: double.infinity,
  child: FilledButton(
    onPressed: _save,
    child: const Text('Save Machine'),
  ),
),
```

**TextFormField pattern** (lines 146–155) — use the same `OutlineInputBorder` style for the "Folder path" add field:
```dart
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
```

**Semantics pattern** (lines 125–134) — used on the AppBar delete icon; apply same pattern to add/delete/reorder icons in Component A:
```dart
Semantics(
  label: 'Delete machine',
  child: IconButton(
    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
    onPressed: _deleteAndPop,
  ),
),
```

**colorScheme access pattern** — accessed via `Theme.of(context).colorScheme` inline in build (e.g., line 95). Use the same style:
```dart
final colorScheme = Theme.of(context).colorScheme;
// Then: colorScheme.error, colorScheme.onSurfaceVariant, etc.
```

---

### `lib/features/terminal/screens/terminal_screen.dart` (component, event-driven)

**Analog:** Self — mechanical conversion from `ConsumerWidget` to `ConsumerStatefulWidget`. The `_pickerShown` guard cannot live in `build` local scope.

**Current widget declaration** (line 24) — must change to:
```dart
// Current (line 24):
class TerminalScreen extends ConsumerWidget {
// Change to:
class TerminalScreen extends ConsumerStatefulWidget {
  // ... existing fields unchanged ...
  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  bool _pickerShown = false;
  // build method body moves here unchanged
}
```

**Existing ref.listen hook** (lines 49–67) — picker trigger is added inside this same listener block, after the existing snackbar logic:
```dart
ref.listen(sshSessionProvider(machineId), (prev, next) {
  final prevState = prev?.value;
  final nextState = next.value;

  // Existing: reconnect snackbar
  if (prevState is SshReconnecting && nextState is SshConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reconnected'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Existing: failed snackbar
  if (nextState is SshFailed && prevState is! SshFailed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not connect to $machineName.')),
    );
  }

  // NEW: picker trigger — first SshConnected transition only
  if (!_pickerShown && nextState is SshConnected) {
    _pickerShown = true;
    final machine = ref.read(machineProvider).value
        ?.cast<dynamic>().firstWhere(
          (m) => m.id == machineId,
          orElse: () => null,
        );
    if (machine != null && (machine.folderPaths as List).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder: (_) => SessionPickerSheet(
            folderPaths: List<String>.from(machine.folderPaths as List),
            onFolderSelected: (path) {
              ref
                  .read(sshSessionProvider(machineId).notifier)
                  .sendText('cd $path\n');
            },
          ),
        );
      });
    }
  }
});
```

**machineProvider access pattern** (lines 40–45) — existing pattern for looking up a machine by id; reuse exactly:
```dart
final machines = ref.watch(machineProvider).value;
final machine = machines?.cast<dynamic>().firstWhere(
  (m) => m.id == machineId,
  orElse: () => null,
);
```

**ConsumerStatefulWidget ref access** — in `ConsumerState`, `ref` is a field (no `WidgetRef ref` parameter in `build`). The existing `ref.watch`, `ref.read`, and `ref.listen` calls do not change syntax — just move from `build(BuildContext context, WidgetRef ref)` to `build(BuildContext context)` with `ref` from `ConsumerState`.

**machineId access** — in `ConsumerState`, use `widget.machineId` instead of the local `machineId` parameter that existed in `ConsumerWidget.build`. Check if the existing code uses a local `machineId` getter or direct field access.

---

### `lib/features/terminal/widgets/session_picker_sheet.dart` (component, request-response) — NEW FILE

**Analog:** `lib/features/terminal/widgets/voice_bottom_sheet.dart` — exact match (same role: non-dismissible bottom sheet; same data flow: user picks, callback fires, sheet pops).

**Imports pattern** (lines 1–2 of voice_bottom_sheet.dart):
```dart
import 'package:flutter/material.dart';
// No riverpod import in the sheet widget — callbacks passed as constructor params.
```

**Widget signature pattern** (lines 7–14 of voice_bottom_sheet.dart) — callbacks injected via constructor, no provider reads inside the sheet:
```dart
class VoiceBottomSheet extends StatelessWidget {
  final String transcript;
  final VoidCallback onSend;

  const VoiceBottomSheet({
    super.key,
    required this.transcript,
    required this.onSend,
  });
```
New widget follows same structure:
```dart
class SessionPickerSheet extends StatelessWidget {
  final List<String> folderPaths;
  final void Function(String path) onFolderSelected;

  const SessionPickerSheet({
    super.key,
    required this.folderPaths,
    required this.onFolderSelected,
  });
```

**Drag handle pattern** (lines 34–43 of voice_bottom_sheet.dart) — copy exactly:
```dart
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
```

**Outer padding pattern** (lines 22–28 of voice_bottom_sheet.dart):
```dart
return Padding(
  padding: EdgeInsets.fromLTRB(
    16,
    8,
    16,
    16 + MediaQuery.of(context).viewInsets.bottom,
  ),
```
For `SessionPickerSheet`, use safe area padding instead of `viewInsets.bottom` (sheet is shown before keyboard opens):
```dart
return Padding(
  padding: EdgeInsets.fromLTRB(
    16,
    8,
    16,
    32 + MediaQuery.of(context).padding.bottom,
  ),
```

**colorScheme access pattern** (line 19 of voice_bottom_sheet.dart):
```dart
final colorScheme = Theme.of(context).colorScheme;
```

**TextButton pattern** (lines 74–78 of voice_bottom_sheet.dart) — "Start blank" button follows the same `TextButton` style used for "Discard":
```dart
TextButton(
  onPressed: () => Navigator.of(context).pop(),
  child: const Text('Discard'),
),
```
"Start blank" variant:
```dart
TextButton(
  onPressed: () => Navigator.of(context).pop(),
  style: TextButton.styleFrom(
    foregroundColor: colorScheme.onSurfaceVariant,
  ),
  child: const Text('Start blank'),
),
```

**surfaceContainerHighest container pattern** (lines 57–68 of voice_bottom_sheet.dart) — used for the transcript box; reuse for each folder path row background:
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(8),
  ),
  child: ...
),
```

**sendText call pattern** (input_bar.dart line 150) — called from the `onFolderSelected` callback in `terminal_screen.dart`, not inside the sheet. The sheet only calls `onFolderSelected(path)`:
```dart
ref
    .read(sshSessionProvider(widget.machineId).notifier)
    .sendText(text);
// Note: sendText does NOT append \n — caller must include it.
// The picker trigger passes: sendText('cd $path\n')
```

**showModalBottomSheet call pattern** (input_bar.dart lines 112–125) — the existing `_showReviewSheet` in `InputBar` uses `isScrollControlled: true`; the picker sheet does NOT need this (fixed height, no keyboard):
```dart
// Existing (voice sheet):
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => VoiceBottomSheet(...),
);

// Picker sheet (new, non-dismissible):
showModalBottomSheet<void>(
  context: context,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: colorScheme.surface,
  builder: (_) => SessionPickerSheet(...),
);
```

---

## Shared Patterns

### ConsumerStatefulWidget + ConsumerState
**Source:** `lib/features/machines/screens/add_edit_machine_screen.dart` (lines 8–16)
**Apply to:** `terminal_screen.dart` (conversion), `session_picker_sheet.dart` does NOT need it (StatelessWidget is correct)
```dart
class AddEditMachineScreen extends ConsumerStatefulWidget {
  const AddEditMachineScreen({super.key, this.machineId});

  @override
  ConsumerState<AddEditMachineScreen> createState() =>
      _AddEditMachineScreenState();
}
class _AddEditMachineScreenState extends ConsumerState<AddEditMachineScreen> {
  // ref is available as a field — no WidgetRef parameter in build
}
```

### colorScheme Token Access
**Source:** `lib/features/terminal/widgets/voice_bottom_sheet.dart` (line 19), `lib/features/machines/screens/add_edit_machine_screen.dart` (line 95)
**Apply to:** All new/modified widgets in Phase 6
```dart
final colorScheme = Theme.of(context).colorScheme;
// Used as: colorScheme.surface, colorScheme.surfaceContainerHighest,
//          colorScheme.onSurfaceVariant, colorScheme.error, colorScheme.primary
```

### Semantics Wrapping for Icon Buttons
**Source:** `lib/features/machines/screens/add_edit_machine_screen.dart` (lines 125–134), `lib/features/terminal/screens/terminal_screen.dart` (lines 119–124)
**Apply to:** All icon buttons in Component A (add, delete, reorder) and Component B (folder rows)
```dart
Semantics(
  label: 'Delete machine',
  child: IconButton(
    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
    onPressed: _deleteAndPop,
  ),
),
```

### Navigator.pop for Sheet Dismissal
**Source:** `lib/features/terminal/widgets/voice_bottom_sheet.dart` (line 77)
**Apply to:** `session_picker_sheet.dart` — both folder tap and "Start blank"
```dart
Navigator.of(context).pop()
// Always call pop() BEFORE any side-effect (sendText). Pop is synchronous.
```

### ref.listen for State Transitions
**Source:** `lib/features/terminal/screens/terminal_screen.dart` (lines 49–67)
**Apply to:** `terminal_screen.dart` — picker trigger is added inside the existing listener
```dart
ref.listen(sshSessionProvider(machineId), (prev, next) {
  final prevState = prev?.value;
  final nextState = next.value;
  // pattern-match on SshSessionState subtypes
});
```

### machineProvider lookup by id
**Source:** `lib/features/terminal/screens/terminal_screen.dart` (lines 40–45)
**Apply to:** `terminal_screen.dart` picker trigger — look up folderPaths from the machine list
```dart
final machines = ref.watch(machineProvider).value;
final machine = machines?.cast<dynamic>().firstWhere(
  (m) => m.id == machineId,
  orElse: () => null,
);
```

---

## No Analog Found

All Phase 6 files have close analogs in the codebase. No file requires falling back to RESEARCH.md patterns alone.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | — |

`ReorderableListView` (Component A) has no existing analog in the codebase — it is a new widget pattern. Use the SDK-documented pattern from RESEARCH.md § Pattern 2 with the index-based `ValueKey('folder_$index')` key (not path-based, to handle duplicate paths safely per Pitfall 4).

---

## Metadata

**Analog search scope:** `lib/` (all Dart files)
**Files scanned:** 27 Dart files
**Pattern extraction date:** 2026-06-20
