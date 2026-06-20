# Phase 6: Session Start Picker — Research

**Researched:** 2026-06-20
**Domain:** Flutter state management, model extension, bottom sheet UX, ReorderableListView
**Confidence:** HIGH

---

## Summary

Phase 6 adds two UI surfaces: a folder path editor embedded inside `AddEditMachineScreen` (Component A) and a non-dismissible picker bottom sheet shown once after SSH connects (Component B). The data model (`Machine`) needs a new `folderPaths: List<String>` field persisted via the existing `shared_preferences` path (non-sensitive metadata). No new packages are required — every widget used (`ReorderableListView`, `showModalBottomSheet`, `ListTile`, `ReorderableListView`, `TextFormField`, `TextButton`) is part of the Flutter SDK.

The critical execution risk in this phase is the picker sheet trigger. The `SshConnected` state is emitted once, but the existing `ref.listen` in `TerminalScreen` may fire multiple times (e.g., reconnect cycles eventually reaching `SshConnected` again). The sheet must be shown **only on the first transition into `SshConnected` per session** — not on every reconnect landing in `SshConnected`. A `_pickerShown` boolean flag on the screen state is the correct guard.

The `Machine.copyWith` method currently does not include `folderPaths`. The model extension, `copyWith`, JSON serialization, and `MachineRepository` storage must all be updated as a single atomic step to avoid state inconsistencies — this is Wave 1.

**Primary recommendation:** Three-wave plan: (1) Model + persistence layer, (2) Folder editor in AddEditMachineScreen, (3) Picker sheet in TerminalScreen.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Folder path data model | Core model (`machine.dart`) | Repository (`machine_repository.dart`) | `folderPaths` is per-machine metadata — same tier as name/host/port |
| Folder path persistence | `shared_preferences` via `MachineRepository` | — | Non-sensitive; same storage path as all other machine fields |
| Folder path CRUD UI | `AddEditMachineScreen` | `MachineNotifier` | Edit screen already owns all machine field management |
| Picker sheet trigger | `TerminalScreen` (`ref.listen`) | `SshSession` state machine | Terminal screen already listens for `SshConnected` for snackbar; same hook |
| Sending `cd <path>` | `SshSession.sendText()` | — | Already exists; picker calls it directly |
| Picker sheet UI | New `session_picker_sheet.dart` widget | `TerminalScreen` | Isolated widget keeps terminal_screen.dart readable |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PICK-01 | When starting a session with configured folders, user can choose between blank session or a project | Picker sheet (Component B) shown on `SshConnected` first transition; "Start blank" TextButton dismisses without command |
| PICK-02 | User can configure a list of working folder paths per machine in the edit screen | `ReorderableListView` + add/delete in `AddEditMachineScreen`; persisted on save via `MachineNotifier.save()` |
| PICK-03 | Selecting a project sends `cd <path>` automatically as first command | `Navigator.pop()` then `sshSessionProvider(machineId).notifier.sendText('cd $path\n')` |
| PICK-04 | If no folders configured, session starts blank directly — picker never appears | Guard in `ref.listen`: `if (machine.folderPaths.isEmpty) return;` before `showModalBottomSheet` |
</phase_requirements>

---

## Standard Stack

### Core (all existing — no new installs)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | 3.3.1 (in pubspec) | State management, `ref.listen` for transition | Already used for all SSH state; `ref.listen` is the correct hook for picker trigger |
| `shared_preferences` | 2.5.5 (in pubspec) | Persist `folderPaths` list via `MachineRepository` | Already stores all machine metadata; `folderPaths` is non-sensitive |
| Flutter SDK built-ins | SDK 3.38.0+ | `ReorderableListView`, `showModalBottomSheet`, `ListTile`, `TextButton`, `TextFormField` | No new packages required (confirmed by UI-SPEC § Registry Safety) |

### No New Packages Required

The UI-SPEC (§ Registry Safety) explicitly states: "No new pub.dev packages required for Phase 6 UI." All widgets are Flutter SDK built-ins. [VERIFIED: UI-SPEC.md § Registry Safety]

---

## Package Legitimacy Audit

No new packages are installed in Phase 6. The package legitimacy gate is not applicable.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| — | — | — | — | — | N/A | No new packages |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
AddEditMachineScreen
  └─ Form fields (Name, Host, Port, Username, Password)
  └─ [NEW] Folder Path Editor (Component A)
        └─ ReorderableListView (existing paths)
        └─ TextFormField + add button (new path input)
  └─ Save button
        └─ MachineNotifier.save(machine, password)
               └─ MachineRepository.save()
                     └─ shared_preferences (folderPaths as JSON in machines_v1 list)

TerminalScreen
  └─ ref.listen(sshSessionProvider)
        └─ on SshConnected (first time only, via _pickerShown flag)
              └─ machine.folderPaths.isNotEmpty?
                    YES → showModalBottomSheet → SessionPickerSheet (Component B)
                          └─ user taps folder → Navigator.pop() → sendText('cd $path\n')
                          └─ user taps "Start blank" → Navigator.pop() (no command)
                    NO  → session starts blank (PICK-04)
```

### Recommended Project Structure

```
lib/
├── core/
│   └── models/
│       └── machine.dart               # ADD folderPaths field + copyWith + JSON
├── core/
│   └── repositories/
│       └── machine_repository.dart    # No change needed (uses Machine.toJson/fromJson)
├── features/
│   ├── machines/
│   │   └── screens/
│   │       └── add_edit_machine_screen.dart   # ADD Component A (folder editor section)
│   └── terminal/
│       ├── screens/
│       │   └── terminal_screen.dart           # ADD picker trigger in ref.listen
│       └── widgets/
│           └── session_picker_sheet.dart      # NEW — Component B
```

### Pattern 1: Model Field Extension with JSON Backward Compatibility

**What:** Add `folderPaths: List<String>` to `Machine`, with `fromJson` defaulting to `[]` when the key is absent (existing stored machines have no `folderPaths` key).

**When to use:** Any time a persisted model gains a new optional field — existing serialized data must not break deserialization.

**Example:**
```dart
// Source: VERIFIED from existing machine.dart pattern + standard Dart null-coalescence
class Machine {
  final List<String> folderPaths;

  const Machine({
    // ... existing fields ...
    this.folderPaths = const [],
  });

  Machine copyWith({
    // ... existing params ...
    List<String>? folderPaths,
  }) => Machine(
    id: id,
    name: name ?? this.name,
    // ...
    folderPaths: folderPaths ?? this.folderPaths,
  );

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String,
    // Backward-compatible default: existing machines have no 'folderPaths' key
    folderPaths: (json['folderPaths'] as List<dynamic>?)
            ?.cast<String>() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'folderPaths': folderPaths,
  };
}
```
[VERIFIED: reviewed machine.dart directly; pattern matches existing JSON serialization style]

### Pattern 2: ReorderableListView for Folder Paths

**What:** Flutter's built-in `ReorderableListView` handles long-press drag reordering natively. Each item requires a `Key`.

**When to use:** Any list where users need to reorder items without third-party drag-and-drop libraries.

**Example:**
```dart
// Source: [ASSUMED] Flutter SDK documentation — ReorderableListView
ReorderableListView(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(), // parent SingleChildScrollView scrolls
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _folderPaths.removeAt(oldIndex);
      _folderPaths.insert(newIndex, item);
    });
  },
  children: [
    for (final path in _folderPaths)
      ListTile(
        key: ValueKey(path), // Required by ReorderableListView
        leading: const Icon(Icons.drag_handle),
        title: Text(path),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          color: colorScheme.error,
          onPressed: () => setState(() => _folderPaths.remove(path)),
        ),
      ),
  ],
);
```

**Critical note on `shrinkWrap: true`:** Inside `SingleChildScrollView`, `ReorderableListView` must have `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()` — otherwise Flutter throws an unbounded height error. [ASSUMED]

### Pattern 3: One-Shot Picker Trigger via ref.listen

**What:** `ref.listen` already fires in `TerminalScreen` for reconnect snackbars. The picker trigger hooks into the same listener but uses a per-widget-instance boolean to show the sheet only on the first `SshConnected` transition.

**When to use:** Any "show once" UI on a state transition where the same state can be re-entered (e.g., reconnect success lands back in `SshConnected`).

**Example:**
```dart
// Source: VERIFIED from terminal_screen.dart existing ref.listen pattern
// _pickerShown must be a field on _TerminalScreenState (ConsumerStatefulWidget required)
bool _pickerShown = false;

ref.listen(sshSessionProvider(machineId), (prev, next) {
  // ... existing snackbar logic ...

  // Picker: only on the FIRST SshConnected transition per session
  if (!_pickerShown && next.value is SshConnected) {
    _pickerShown = true;
    final machine = ref.read(machineProvider).value
        ?.firstWhere((m) => m.id == machineId, orElse: () => null);
    if (machine != null && machine.folderPaths.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => SessionPickerSheet(
            folderPaths: machine.folderPaths,
            onFolderSelected: (path) {
              ref.read(sshSessionProvider(machineId).notifier)
                 .sendText('cd $path\n');
            },
          ),
        );
      });
    }
  }
});
```

**Why `addPostFrameCallback`:** `showModalBottomSheet` called from inside `ref.listen` (which fires during build) can produce "setState called during build" errors. Deferring to the next frame is the safe pattern. [ASSUMED — standard Flutter practice for showing modals from listeners]

**Why `ConsumerStatefulWidget`:** `TerminalScreen` is currently a `ConsumerWidget`. The `_pickerShown` boolean must survive widget rebuilds — it cannot live in a local variable inside `build`. Converting to `ConsumerStatefulWidget` is required. [VERIFIED: reviewed terminal_screen.dart — currently `ConsumerWidget`]

### Pattern 4: Non-Dismissible Modal Bottom Sheet

**What:** `showModalBottomSheet` with `isDismissible: false` and `enableDrag: false` forces the user to make an explicit choice — no accidental dismissal.

**When to use:** Required when the UI must guarantee a decision is made before proceeding (UI-SPEC § Component B).

**Example:**
```dart
// Source: [ASSUMED] Flutter SDK showModalBottomSheet docs
showModalBottomSheet(
  context: context,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: colorScheme.surface,
  builder: (context) => SessionPickerSheet(
    folderPaths: machine.folderPaths,
    onFolderSelected: (path) { /* ... */ },
  ),
);
```

### Anti-Patterns to Avoid

- **Using `ref.invalidateSelf()` to trigger the picker:** This would destroy the `Terminal` instance and its scrollback buffer (breaking RECON-05). The picker fires on a state *transition*, not a provider invalidation.
- **Showing the picker sheet directly inside `ref.listen` without `addPostFrameCallback`:** Causes "setState called during build" Flutter assertion errors.
- **Storing `_pickerShown` inside `ConsumerWidget.build` as a local variable:** It resets on every rebuild. Must be a `State` field on `ConsumerStatefulWidget`.
- **Using `value` key on `ReorderableListView` items where paths are duplicates:** Duplicate keys cause assertion errors. The UI-SPEC allows duplicate paths (user responsibility); if duplicates can exist, use index-based keys (`ValueKey(index)`) instead of path-based keys.
- **Missing backward-compat default in `Machine.fromJson`:** Existing machines stored in `shared_preferences` have no `folderPaths` key. Without `?? const []`, loading them throws a null cast error on app launch.
- **Putting `ReorderableListView` inside `CustomScrollView` without `SliverReorderableList`:** Causes scroll controller conflicts. Use `shrinkWrap: true` + `NeverScrollableScrollPhysics` inside a `SingleChildScrollView` (which `AddEditMachineScreen` already uses).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-to-reorder list | Custom drag gesture + AnimatedList | `ReorderableListView` (Flutter SDK) | Built-in handles long-press detection, elevation shadow on drag, insertion-point indicator, touch target sizing |
| Modal that blocks all dismissal | Custom overlay with WillPopScope | `showModalBottomSheet(isDismissible: false, enableDrag: false)` | SDK handles barrier color, animation, back-gesture blocking, safe area |
| JSON list serialization | Custom loop | `List<dynamic>.cast<String>()` in `fromJson` / `folderPaths: folderPaths` in `toJson` | `shared_preferences` stores JSON strings via `jsonEncode`; `Machine.toJson` already handles this pattern |

---

## Common Pitfalls

### Pitfall 1: Picker Sheet Shows on Every Reconnect

**What goes wrong:** User reconnects (mid-session drop + recovery). The state transitions to `SshConnected` again. The picker sheet opens a second time with no context (user is already `cd`'d somewhere).

**Why it happens:** `ref.listen` fires on every state transition. `SshConnected` is reached both on initial connect and on successful reconnect.

**How to avoid:** Use a `_pickerShown` boolean on `ConsumerStatefulWidget` state. Set to `true` the first time picker fires. Reset it only if the `TerminalScreen` is fully reconstructed (i.e., user navigates back and opens a new session).

**Warning signs:** If `TerminalScreen` is still a `ConsumerWidget`, this guard cannot be implemented — convert first.

### Pitfall 2: `showModalBottomSheet` Called During Build

**What goes wrong:** Flutter assertion error: "setState() or markNeedsBuild() called during build."

**Why it happens:** `ref.listen` fires synchronously during the build phase. Calling `showModalBottomSheet` from inside it triggers widget tree mutations before the frame is committed.

**How to avoid:** Always wrap `showModalBottomSheet` calls in `WidgetsBinding.instance.addPostFrameCallback((_) { ... })` when called from `ref.listen`.

**Warning signs:** Red-screen assertion error on first SSH connect when folders are configured.

### Pitfall 3: `ReorderableListView` Unbounded Height Error

**What goes wrong:** Flutter layout error: "RenderBox was not laid out: RenderFlex#…"

**Why it happens:** `ReorderableListView` defaults to filling available height. Inside `SingleChildScrollView` (which `AddEditMachineScreen` uses), there is no bounded height constraint.

**How to avoid:** Set `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()` on `ReorderableListView`.

**Warning signs:** Debug console shows `RenderFlex overflowed` or unbounded height assertion on the form screen.

### Pitfall 4: Duplicate Path Keys Crash ReorderableListView

**What goes wrong:** Flutter assertion: `Duplicate keys found.`

**Why it happens:** UI-SPEC allows duplicate folder paths. If `ValueKey(path)` is used on list items and user adds `/home/user` twice, two items share the same key.

**How to avoid:** Key list items by index: `ValueKey('folder_$index')` where index comes from `enumerate` or an indexed `for` loop. This makes duplicate paths safe.

**Warning signs:** Crash when user types the same path twice and tries to reorder.

### Pitfall 5: Existing Machines Fail to Load After `Machine.fromJson` Update

**What goes wrong:** App crash on launch: `Null check operator used on a null value` inside `MachineRepository.loadAll()`.

**Why it happens:** Old machines stored in `shared_preferences` have no `folderPaths` key in their JSON. If `fromJson` does `json['folderPaths'] as List<String>` without null fallback, it throws.

**How to avoid:** Always use `(json['folderPaths'] as List<dynamic>?)?.cast<String>() ?? const []` in `fromJson`.

**Warning signs:** App crashes on launch for any user who had machines saved before this phase.

### Pitfall 6: `sendText` Called Before Sheet is Dismissed

**What goes wrong:** The `cd` command fires but the sheet is still visible, making the UX confusing.

**Why it happens:** Calling `sendText` before `Navigator.pop()` in the tap handler.

**How to avoid:** Call `Navigator.of(context).pop()` first, then call `sendText`. The sheet dismissal is synchronous; `sendText` fires after. [ASSUMED — standard Flutter modal dismiss ordering]

---

## Code Examples

Verified patterns from codebase inspection:

### Existing `sendText` call pattern (ssh_session_provider.dart:393)
```dart
void sendText(String text) => _sshSession?.write(utf8.encode(text));
```
The picker sends: `ref.read(sshSessionProvider(machineId).notifier).sendText('cd $path\n');`

Note: `sendText` does NOT append `\n` — caller must include it. [VERIFIED: ssh_session_provider.dart line 393]

### Existing `ref.listen` transition hook (terminal_screen.dart:49-67)
```dart
ref.listen(sshSessionProvider(machineId), (prev, next) {
  final prevState = prev?.value;
  final nextState = next.value;
  // ... picker trigger goes here alongside existing snackbar logic
});
```
[VERIFIED: terminal_screen.dart lines 49-67]

### Existing `MachineRepository` storage key (machine_repository.dart:12)
```dart
static const _machinesKey = 'machines_v1';
```
`folderPaths` flows through `Machine.toJson()` → `jsonEncode()` → stored in this key. No new storage key needed. [VERIFIED: machine_repository.dart]

### Existing `VoiceBottomSheet` drag handle pattern (reference for SessionPickerSheet)
```dart
Container(
  width: 32,
  height: 4,
  decoration: BoxDecoration(
    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    borderRadius: BorderRadius.circular(2),
  ),
),
```
[VERIFIED: voice_bottom_sheet.dart lines 35-43]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `StatefulWidget` + manual dispose for SSH state | `ConsumerStatefulWidget` / Riverpod AsyncNotifier | Phase 1 | `TerminalScreen` must convert from `ConsumerWidget` → `ConsumerStatefulWidget` to hold `_pickerShown` |
| Separate storage key per new model field | Field added to existing `toJson`/`fromJson` + backward-compat default | Phase 1 pattern | No migration script needed; old data deserializes safely with `?? const []` |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `showModalBottomSheet` requires `addPostFrameCallback` when called from `ref.listen` | Pattern 3, Pitfall 2 | If wrong: no crash, slightly earlier call; harmless if Flutter allows it in this context |
| A2 | `ReorderableListView` requires `shrinkWrap: true` inside `SingleChildScrollView` | Pattern 2, Pitfall 3 | If wrong: may work without it or need `SliverReorderableList` variant instead |
| A3 | Index-based `ValueKey('folder_$index')` is the safe approach for potentially-duplicate paths | Pattern 2, Pitfall 4 | If wrong: duplicate paths cause key assertion; cost of being wrong is a crash |
| A4 | `Navigator.of(context).pop()` before `sendText()` is the correct order in folder tap handler | Pitfall 6 | If wrong: sheet stays open briefly after command is sent — cosmetic issue, not functional |
| A5 | `ReorderableListView` `onReorder` requires `if (newIndex > oldIndex) newIndex--` index adjustment | Pattern 2 code example | If wrong: items insert one position off after drag; well-documented Flutter behavior but assumed from training |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.
(Table is not empty — A1 through A5 need validation during implementation.)

---

## Open Questions

1. **`TerminalScreen` ConsumerWidget → ConsumerStatefulWidget conversion scope**
   - What we know: The `_pickerShown` flag requires persistent state across rebuilds. `ConsumerWidget` has no `State` to hold it.
   - What's unclear: Whether the conversion touches anything else in the widget that is rebuild-sensitive (e.g., the `_ConnectingDot` animation is on a separate private `StatefulWidget`, so it is unaffected).
   - Recommendation: The conversion is mechanical — replace `ConsumerWidget` with `ConsumerStatefulWidget` + `ConsumerState`; move `ref.listen` and `_pickerShown` to `State`. No other structural changes needed.

2. **Picker sheet triggered on reconnect: desired behavior?**
   - What we know: The `_pickerShown = true` guard prevents the picker from reopening on mid-session reconnect. This matches intuitive UX (user already chose a folder; don't interrupt them again).
   - What's unclear: If the user *wants* to switch projects after a reconnect (edge case), there is no UI path.
   - Recommendation: Implement `_pickerShown = true` as specified. This is a v2.0 scope, not v3.

3. **`machineProvider` vs `machineNotifierProvider` naming**
   - What we know: `machines_provider.dart` line 13 shows `@riverpod class MachineNotifier`. Riverpod generator produces `machineProvider` (drops `Notifier` suffix, lowercases). Used as `machineProvider` and `machineProvider.notifier` throughout the codebase.
   - What's unclear: Nothing — consistent throughout codebase. Confirmed in terminal_screen.dart line 40.
   - Recommendation: Use `machineProvider` consistently. [VERIFIED: terminal_screen.dart line 40]

---

## Environment Availability

Step 2.6: SKIPPED — Phase 6 introduces no external CLI tools, services, or new runtimes. All dependencies are existing Flutter SDK built-ins and packages already in pubspec.yaml.

---

## Validation Architecture

`nyquist_validation` is explicitly `false` in `.planning/config.json`. This section is omitted per protocol.

---

## Security Domain

Phase 6 adds no authentication, credential handling, or network surface changes. `folderPaths` is folder path strings stored in `shared_preferences` alongside other non-sensitive machine metadata (name, host, port, username). No new ASVS categories apply beyond what is already covered by existing phases.

The `cd <path>` command sent to the SSH shell is controlled by the user's own configured paths — no injection vector from external input (paths come from a local list the user typed themselves).

---

## Sources

### Primary (HIGH confidence)
- `machine.dart` — read directly; verified current field set, `fromJson`/`toJson`, `copyWith` signature
- `machine_repository.dart` — read directly; verified storage key (`machines_v1`), `shared_preferences` path
- `machines_provider.dart` — read directly; verified `MachineNotifier` CRUD and provider name
- `ssh_session_provider.dart` — read directly; verified `sendText()` signature (no `\n` appended), `SshConnected` state
- `ssh_session_state.dart` — read directly; verified `SshConnected`, `SshReconnecting`, `SshFailed` sealed class contract
- `terminal_screen.dart` — read directly; verified `ConsumerWidget` (not Stateful), `ref.listen` hook, `machineProvider` usage
- `add_edit_machine_screen.dart` — read directly; verified form structure, `SingleChildScrollView` wrapper, `_save()` flow
- `voice_bottom_sheet.dart` — read directly; verified drag handle pattern (32×4dp, `withValues(alpha: 0.4)`)
- `06-UI-SPEC.md` — read directly; authoritative design contract for all Phase 6 UI surfaces
- `.planning/config.json` — read directly; `nyquist_validation: false`, `mode: yolo`, `granularity: coarse`

### Secondary (MEDIUM confidence)
- `REQUIREMENTS.md` — read directly; PICK-01 through PICK-04 requirements verified
- `ROADMAP.md` — read directly; Phase 6 success criteria and dependency on Phase 5
- `STATE.md` — read directly; v2.0 architecture decisions (picker ordering, `ref.keepAlive`, SFTP folder listing deferred)

### Tertiary (LOW confidence / ASSUMED)
- `addPostFrameCallback` requirement for `showModalBottomSheet` from `ref.listen` — training knowledge, not verified via official docs in this session
- `ReorderableListView` `shrinkWrap` requirement inside `SingleChildScrollView` — training knowledge
- `onReorder` index adjustment (`if (newIndex > oldIndex) newIndex--`) — training knowledge

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all existing deps verified
- Architecture: HIGH — read every relevant source file directly
- Data model extension: HIGH — existing `fromJson`/`toJson` pattern is clear; backward-compat risk is identified
- Picker trigger mechanism: HIGH — `ref.listen` hook verified in source; `_pickerShown` guard is a well-understood Flutter pattern
- Pitfalls: MEDIUM — 3 of 6 pitfalls are assumed (A1, A2, A5) from training; practical risk is low

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 (stable Flutter patterns; no fast-moving dependencies)
