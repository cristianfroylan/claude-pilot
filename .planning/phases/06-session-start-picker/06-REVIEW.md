---
phase: 06-session-start-picker
reviewed: 2026-06-20T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/core/models/machine.dart
  - lib/features/machines/screens/add_edit_machine_screen.dart
  - lib/features/terminal/widgets/session_picker_sheet.dart
  - lib/features/terminal/screens/terminal_screen.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-06-20T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This phase adds the session-start folder picker: a `folderPaths` field on `Machine`, an
add/edit UI in `AddEditMachineScreen`, a `SessionPickerSheet` bottom sheet widget, and the
one-shot trigger in `TerminalScreen` via `ref.listen` + `addPostFrameCallback`.

`flutter analyze` passes clean. The backward-compat null guard in `Machine.fromJson` is
correct. `Navigator.pop()` before the callback in `SessionPickerSheet` is intentional and
safe. The `addPostFrameCallback` approach to avoid "setState during build" is appropriate.
`widget.machineId` usage is correct throughout both `ConsumerStatefulWidget` subclasses.

Four warnings and three info items were found. None are blockers, but two warnings
represent real correctness defects that will surface in normal use.

---

## Warnings

### WR-01: Password required in edit mode prevents re-saving without knowing the stored password

**File:** `lib/features/machines/screens/add_edit_machine_screen.dart:229-230`

**Issue:** The password field validator unconditionally returns `'Required'` when the value
is empty, regardless of whether the screen is in add or edit mode. When editing an existing
machine, the password is loaded asynchronously from `flutter_secure_storage` via
`_loadExistingMachine()`. If the provider's `getPassword` call completes *after* the first
`build()` (which is essentially always, because it is async), the `_passwordCtrl` will be
empty at the moment the user taps "Save Machine" on a slow device or before the future
resolves. In addition, a user who intentionally clears the password field intending to
update it to empty string will be blocked — though that is a lesser concern.

More practically: if a user opens Edit Machine and immediately taps Save (before the
password async load has completed and populated `_passwordCtrl`), the form will reject the
save with "Required" even though the password is already stored correctly. The screen silently
ignores that the password hasn't finished loading yet.

**Fix:**
```dart
validator: (v) {
  // In edit mode the password is loaded asynchronously.
  // Only require a non-empty value when adding a new machine.
  if (widget.machineId == null && (v == null || v.isEmpty)) {
    return 'Required';
  }
  return null;
},
```
Or, alternatively, block the Save button until `_loaded` is true and the async password
load has settled.

---

### WR-02: `_pickerShown` is not reset when `reconnect()` produces a fresh `SshConnected` after `SshFailed`

**File:** `lib/features/terminal/screens/terminal_screen.dart:38, 81-82`

**Issue:** `_pickerShown` is set to `true` the first time the provider transitions to
`SshConnected`. It is never reset. The `reconnect()` public method on `SshSessionProvider`
(called from the "Retry" button in `ReconnectFailedOverlay`) produces a new `SshConnected`
state from `SshFailed`, without going through a fresh `ConsumerState` lifecycle. This is by
design (scrollback preservation) and is correct for mid-session reconnects.

However, the scenario where the picker should reasonably re-appear is a **manual reconnect
after `SshFailed` on the initial connection attempt** — i.e., the user never reached a
working session, the picker was shown, the user selected a folder or dismissed it, then all
5 retries exhausted. When they tap Retry the `ref.listen` fires `SshConnected` again, but
`_pickerShown == true` so the picker never shows a second time even though no `cd` was sent.

Separately, there is a subtle scenario where `SshFailed` occurs *before* `SshConnected` is
ever reached (the initial 5 retries exhaust without success). In that case `_pickerShown`
remains `false` and the picker *will* correctly appear after a successful `reconnect()`.
So the actual bug manifests only when: first connection succeeds → picker shown → user
dismisses → mid-session failure → all 3 mid-session retries fail → user taps Retry →
`reconnect()` returns `SshConnected`. The picker does not re-appear even though a new
session just started in whatever directory the shell defaulted to. The comment in the code
calls this "correct" but the scenario is ambiguous — the `cd` command sent during the first
picker selection is gone because the session dropped.

**Fix (option A — reset on SshFailed → SshConnected transition via reconnect):**
```dart
// Inside ref.listen callback, replace:
if (!_pickerShown && nextState is SshConnected) {
// with:
final isReconnectedAfterFailed = prevState is SshFailed && nextState is SshConnected;
if ((!_pickerShown || isReconnectedAfterFailed) && nextState is SshConnected) {
  _pickerShown = true;   // re-set so mid-session SshReconnecting→SshConnected stays guarded
```

**Fix (option B — document the decision explicitly):** If the design decision is that the
picker never re-appears regardless, add a comment in the `_pickerShown = true` block
explaining that `reconnect()` after `SshFailed` intentionally skips the picker because the
remote shell will resume in whatever directory it left off.

---

### WR-03: `cast<dynamic>().firstWhere(...)` with `orElse: () => null` produces `dynamic`, then unsafe cast

**File:** `lib/features/terminal/screens/terminal_screen.dart:52-56, 84-88`

**Issue:** `machines?.cast<dynamic>().firstWhere((m) => m.id == widget.machineId, orElse: () => null)`
returns `dynamic`. Accessing `machine?.name` and `pickerMachine?.folderPaths` later is
weakly typed — the Dart analyzer cannot check property access on `dynamic`, so a typo or
future refactor of the `Machine` class would produce a runtime exception instead of a
compile-time error. The `as List<String>?` cast on line 88 is particularly fragile: if
`pickerMachine` is not null but `.folderPaths` is somehow not `List<String>` (impossible
currently but unguarded) this throws a `CastError` at runtime rather than being a
compile-time type error.

`machines` is typed as `List<Machine>?` from the provider; the `cast<dynamic>()` call
appears to be a workaround for an older Riverpod version but is unnecessary and discards
static type information.

**Fix:**
```dart
// Replace the cast<dynamic> pattern with a direct typed lookup:
final machine = machines?.where((m) => m.id == widget.machineId).firstOrNull;
final machineName = machine?.name ?? 'Terminal';

// In the ref.listen block:
final allMachines = ref.read(machineProvider).value;
final pickerMachine = allMachines?.where((m) => m.id == widget.machineId).firstOrNull;
final paths = pickerMachine?.folderPaths;
if (paths != null && paths.isNotEmpty) { ... }
```
`firstOrNull` is available in `package:collection` (which Flutter bundles) or from the
`Iterable` extension in Dart 3.

---

### WR-04: ReorderableListView uses index-based `ValueKey` — keys become unstable after reorder

**File:** `lib/features/machines/screens/add_edit_machine_screen.dart:266-297`

**Issue:** Each folder row is keyed `ValueKey('folder_$i')` where `i` is the list index.
`ReorderableListView` uses keys to track items during drag. When an item is moved from
index 2 to index 0, the keys shift: the item that was `folder_0` is now `folder_1`, the
item that was `folder_2` is now `folder_0`. Flutter's widget reconciliation sees three
updated `ValueKey`s and cannot determine which widget is being dragged versus which is
staying in place. This can cause incorrect drag animation in some Flutter versions and
is explicitly discouraged in the `ReorderableListView` documentation, which requires
keys to be *stable identity* keys, not positional.

**Fix:** Use the path value itself as the key, which is stable and unique:
```dart
key: ValueKey(_folderPaths[i]),
// instead of:
key: ValueKey('folder_$i'),
```
Since duplicate paths are not prevented in the current UI, also consider deduplicating
entries in `_addFolderPath`.

---

## Info

### IN-01: `_loadExistingMachine()` called directly from `build()` — side-effectful build method

**File:** `lib/features/machines/screens/add_edit_machine_screen.dart:126`

**Issue:** `_loadExistingMachine()` is called inside `build()`. While the `_loaded` guard
makes this effectively idempotent after the first call, calling side-effectful code (state
mutation, provider reads) from `build()` is a Flutter anti-pattern. The preferred locations
are `initState()` or `didChangeDependencies()`. In particular, `ref.read(...)` inside
`build()` is flagged by the Riverpod linter as a potential misuse.

**Fix:** Move the call to `initState()` and use `ref` from `ConsumerState`:
```dart
@override
void initState() {
  super.initState();
  _loadExistingMachine();
}
```

---

### IN-02: `_addFolderPath()` allows adding duplicate paths silently

**File:** `lib/features/machines/screens/add_edit_machine_screen.dart:115-122`

**Issue:** There is no deduplication check in `_addFolderPath`. A user can add the same
path multiple times. When `SessionPickerSheet` renders, duplicate entries appear, and
tapping either sends the same `cd` command twice (one from `_pickerShown` check, one
from the duplicate). The second `cd` is harmless but the duplicate entries in the list
are a UX defect and could confuse users.

**Fix:**
```dart
void _addFolderPath() {
  final path = _folderPathCtrl.text.trim();
  if (path.isEmpty || _folderPaths.contains(path)) return;
  setState(() {
    _folderPaths.add(path);
    _folderPathCtrl.clear();
  });
}
```

---

### IN-03: `SessionPickerSheet` has no empty-state guard

**File:** `lib/features/terminal/widgets/session_picker_sheet.dart:68`

**Issue:** `SessionPickerSheet` is documented as shown "if the machine has at least one
configured folder path" (enforced by the `paths.isNotEmpty` check in `terminal_screen.dart`
line 89). However, the widget itself has no internal assertion or guard. If `folderPaths`
is accidentally passed as empty, `ListView.separated` renders an empty list with only the
"Start blank" button visible, and no title or explanation. The sheet would appear to be
broken.

**Fix:** Add an `assert` in the constructor to fail fast during development:
```dart
const SessionPickerSheet({
  super.key,
  required this.folderPaths,
  required this.onFolderSelected,
}) : assert(folderPaths.length > 0, 'SessionPickerSheet requires at least one folder path');
```
Or add an empty-state placeholder in `build()` if the caller contract cannot be enforced.

---

_Reviewed: 2026-06-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
