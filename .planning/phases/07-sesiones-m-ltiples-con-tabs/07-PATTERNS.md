# Phase 7: Sesiones Múltiples con Tabs — Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 8 (3 new, 5 modified)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/sessions/models/session_tab.dart` | model | — | `lib/core/models/machine.dart` | role-match |
| `lib/features/sessions/providers/sessions_provider.dart` | provider/notifier | event-driven | `lib/features/auth/providers/biometric_auth_provider.dart` | role-match |
| `lib/features/sessions/screens/sessions_screen.dart` | screen/component | request-response | `lib/features/terminal/screens/terminal_screen.dart` | role-match |
| `lib/features/sessions/widgets/machine_selection_sheet.dart` | widget | request-response | `lib/features/terminal/widgets/session_picker_sheet.dart` | exact |
| `lib/app.dart` | config/router | request-response | `lib/app.dart` (self, surgery) | exact |
| `lib/features/machines/screens/machine_list_screen.dart` | screen | request-response | `lib/features/machines/screens/machine_list_screen.dart` (self, surgery) | exact |
| `lib/features/terminal/screens/terminal_screen.dart` | screen/component | request-response | `lib/features/terminal/screens/terminal_screen.dart` (self, surgery) | exact |
| `lib/features/terminal/providers/ssh_session_provider.dart` | provider/notifier | streaming | `lib/features/terminal/providers/ssh_session_provider.dart` (self, surgery) | exact |

---

## Pattern Assignments

### `lib/features/sessions/models/session_tab.dart` (model)

**Analog:** `lib/core/models/machine.dart`

**Imports pattern** (machine.dart lines 1-0 — no imports, plain Dart class):
```dart
// No imports needed — plain Dart value types only.
```

**Core pattern** (machine.dart lines 1-71):
- Plain Dart class with `final` fields and `const` constructor
- `copyWith()` method for immutable state updates
- No `fromJson`/`toJson` needed — `SessionTab` and `SessionsState` are in-memory only (not persisted)
- ID generation uses `DateTime.now().millisecondsSinceEpoch.toString()` — same idiom as `Machine.generate()` (machine.dart line 29)

```dart
// Copy from machine.dart copyWith pattern (lines 38-52):
SessionsState copyWith({List<SessionTab>? tabs, int? activeIndex}) =>
    SessionsState(
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
```

**Key deviation:** Two classes in one file (`SessionTab` + `SessionsState`). No JSON serialization. No `riverpod_annotation` part directive — this is a pure model file.

---

### `lib/features/sessions/providers/sessions_provider.dart` (provider, event-driven)

**Analog:** `lib/features/auth/providers/biometric_auth_provider.dart`

**Imports pattern** (biometric_auth_provider.dart lines 1-3):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_auth_provider.g.dart';
```

Sessions provider needs one additional import for the SSH provider (to call `closeAndDispose()` in `closeTab()`):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../features/terminal/providers/ssh_session_provider.dart';
import '../models/session_tab.dart';

part 'sessions_provider.g.dart';
```

**keepAlive pattern** (biometric_auth_provider.dart lines 11-17):
```dart
// biometric_auth_provider.dart — the ONLY other keepAlive: true provider in the codebase.
// Use exactly this annotation form:
@Riverpod(keepAlive: true)
class BiometricAuth extends _$BiometricAuth {
  @override
  bool build() => false;

  void setAuthenticated(bool value) => state = value;
}
```

**Core pattern** — synchronous `Notifier<SessionsState>` (not `AsyncNotifier`):
- `build()` returns `SessionsState` directly (not a `Future`) — tab list starts empty, no async initialization
- Mutation methods (`openTab`, `setActiveTab`, `closeTab`) update `state =` directly, same as `setAuthenticated()`
- `openTab` generates IDs using `'${machineId}_${DateTime.now().microsecondsSinceEpoch}'` — mirrors `Machine.generate()` timestamp idiom

**Key deviation from analog:** `BiometricAuth` has one field (`bool`) and one method. `Sessions` has a structured state (`SessionsState`) and three mutation methods. The `closeTab()` method reads a sibling provider via `ref.read(sshSessionProvider(tab.machineId).notifier)` — same cross-provider read pattern used in `ssh_session_provider.dart` line 92 (`ref.read(machineProvider.notifier).get(machineId)`).

---

### `lib/features/sessions/screens/sessions_screen.dart` (screen, request-response)

**Analog:** `lib/features/terminal/screens/terminal_screen.dart`

**Widget type:** `ConsumerStatefulWidget` — required because:
- `initState()` opens the initial tab (one-time setup)
- `didUpdateWidget()` handles subsequent machine taps from the list (new `initialMachineId`)
- `ScrollController` for tab strip programmatic scroll requires `dispose()`

**Imports pattern** (terminal_screen.dart lines 1-13):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../machines/providers/machines_provider.dart';
import '../models/ssh_session_state.dart';
import '../providers/ssh_session_provider.dart';
// ... widget imports
```

Sessions screen equivalent:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../machines/providers/machines_provider.dart';
import '../../terminal/models/ssh_session_state.dart';
import '../../terminal/providers/ssh_session_provider.dart';
import '../../terminal/screens/terminal_screen.dart';
import '../providers/sessions_provider.dart';
import '../models/session_tab.dart';
import '../widgets/machine_selection_sheet.dart';
```

**addPostFrameCallback pattern** (terminal_screen.dart lines 91-108):
```dart
// Used for ScrollController.animateTo() when a new tab is added.
// Copy this guard exactly:
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  // scrollController.animateTo(...)
});
```

**ref.listen pattern** (terminal_screen.dart lines 58-110):
```dart
// Sessions screen uses ref.listen on sessionsProvider to react to tab list changes
// (scroll to new tab). Copy the guard structure:
ref.listen(sessionsProvider, (prev, next) {
  // compare prev.tabs.length to next.tabs.length
  // if new tab added: addPostFrameCallback -> scrollController.animateTo(max)
});
```

**PopScope pattern** — NEW in sessions screen, no existing analog. Copy from RESEARCH.md pattern:
```dart
PopScope(
  canPop: false,
  child: Scaffold(/* ... */),
)
```

**IndexedStack pattern** — NEW in sessions screen. Children use `Visibility` + `ExcludeSemantics` for inactive tabs per RESEARCH.md Pattern 3.

**`initState()` guard pattern** — mirror `_pickerShown` from terminal_screen.dart line 38:
```dart
// terminal_screen.dart line 38 — the per-instance bool guard:
bool _pickerShown = false;

// Sessions screen equivalent:
bool _initialTabOpened = false;
String? _lastInitialMachineId;
```

**Key deviations from analog:**
- `SessionsScreen` has NO `AppBar` of its own in the terminal area — the Scaffold AppBar is at the sessions wrapper level with a "+" trailing action
- No `ref.listen` for SnackBar — that moves to `TerminalScreen.isActive` gate
- Widget is a top-level screen (not embedded), but is designed to host embedded `TerminalScreen` children

---

### `lib/features/sessions/widgets/machine_selection_sheet.dart` (widget, request-response)

**Analog:** `lib/features/terminal/widgets/session_picker_sheet.dart`

**This is an exact structural copy with content changes.** Copy the full file and change:
1. Title from `'Choose a project'` to `'Open a session'`
2. `ListTile` items: machine list rows instead of folder paths (`machineProvider` data)
3. Needs `ConsumerWidget` (not `StatelessWidget`) to read `machineProvider`
4. No "Start blank" button — sheet is dismissible (barrier tap closes)
5. `onTap` calls `onMachineTap(machine.id)` callback (closes sheet via `Navigator.of(context).pop()` first, same pattern as session_picker_sheet.dart line 88)
6. Add "No machines" empty state (matches machine_list_screen.dart `_buildEmptyState` pattern)

**Drag handle pattern** (session_picker_sheet.dart lines 36-44):
```dart
// Copy exactly — matches UI-SPEC drag handle spec:
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

**ListTile pattern** (session_picker_sheet.dart lines 72-92):
```dart
// Copy structure; swap folder icon + path text for machine icon + name/host:
ListTile(
  leading: Icon(Icons.computer_outlined, color: colorScheme.onSurfaceVariant),
  title: Text(machine.name, style: const TextStyle(fontSize: 14)),
  subtitle: Text(machine.host, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
  onTap: () {
    Navigator.of(context).pop(); // pop FIRST (synchronous) — line 88 pattern
    onMachineTap(machine.id);
  },
)
```

**Bottom padding pattern** (session_picker_sheet.dart lines 105-109):
```dart
// Copy exactly — handles notch/home indicator:
padding: EdgeInsets.fromLTRB(
  16,
  0,
  16,
  32 + MediaQuery.of(context).padding.bottom,
),
```

**showModalBottomSheet caller pattern** — copy from terminal_screen.dart lines 92-108:
```dart
// Called from SessionsScreen AppBar "+" button:
showModalBottomSheet<void>(
  context: context,
  backgroundColor: Theme.of(context).colorScheme.surface,
  builder: (_) => MachineSelectionSheet(
    onMachineTap: (machineId) {
      ref.read(sessionsProvider.notifier).openTab(machineId);
    },
  ),
);
```

**Key deviation:** Sheet is dismissible (no `isDismissible: false`, no `enableDrag: false`) — user can tap barrier to cancel without opening a session.

---

### `lib/app.dart` (MODIFIED — surgical changes only)

**Self-analog.** Read lines 1-37 (already read — 89 lines total).

**Change 1: Remove `/machines/:id/terminal` route** (lines 29-33 deleted):
```dart
// DELETE these lines entirely:
GoRoute(
  path: ':id/terminal',
  builder: (context, state) => TerminalScreen(
    machineId: state.pathParameters['id']!,
  ),
),
```

**Change 2: Add `/sessions` as a top-level route** (after the `/machines` route block):
```dart
// New top-level GoRoute (sibling of /machines, not nested inside it):
GoRoute(
  path: '/sessions',
  builder: (context, state) {
    final newMachineId = state.uri.queryParameters['newMachineId'];
    return SessionsScreen(initialMachineId: newMachineId);
  },
),
```

**Change 3: Add import for SessionsScreen** (after terminal_screen.dart import, line 8):
```dart
import 'features/sessions/screens/sessions_screen.dart';
```

**Import ordering convention** (app.dart lines 1-9):
- `package:flutter/*` first
- `package:flutter_riverpod/*` second
- `package:go_router/*` third
- Local imports grouped by feature, alphabetical within group

**Key deviation:** `TerminalScreen` import (line 8) can be removed once the `/machines/:id/terminal` route is deleted, as it will no longer be referenced in app.dart.

---

### `lib/features/machines/screens/machine_list_screen.dart` (MODIFIED — one line change)

**Self-analog.** Read fully (83 lines).

**Only change: `onTap` navigation target** (line 34):
```dart
// BEFORE (line 34):
onTap: () => context.push('/machines/${machines[i].id}/terminal'),

// AFTER:
onTap: () {
  ref.read(sessionsProvider.notifier).openTab(machines[i].id);
  context.push('/sessions');
},
```

This uses the "alternative simpler approach" from RESEARCH.md Open Question 1 (machine list calls `sessionsProvider.notifier.openTab()` directly, then navigates to `/sessions` without query params) to avoid the go_router same-route push ambiguity.

**Import to add** (after line 5, `machines_provider.dart`):
```dart
import '../../sessions/providers/sessions_provider.dart';
```

**ConsumerWidget pattern is unchanged** — `machine_list_screen.dart` is already a `ConsumerWidget` (line 9). The new `ref.read(sessionsProvider.notifier)` call is consistent with existing `ref.read(machineProvider.notifier)` calls (line 44).

**Key deviation:** `MachineListScreen` becomes a `ConsumerWidget` reference to `sessionsProvider` — provider is globally accessible via Riverpod, no structural widget change needed.

---

### `lib/features/terminal/screens/terminal_screen.dart` (MODIFIED — three changes)

**Self-analog.** Read fully (330 lines).

**Change 1: Add `isActive` constructor parameter** (lines 25-31):
```dart
// BEFORE (lines 25-31):
class TerminalScreen extends ConsumerStatefulWidget {
  final String machineId;

  const TerminalScreen({super.key, required this.machineId});

// AFTER:
class TerminalScreen extends ConsumerStatefulWidget {
  final String machineId;
  final bool isActive; // NEW: controls SnackBar emission for background tabs (SESS-04)

  const TerminalScreen({super.key, required this.machineId, this.isActive = true});
```

Default `true` preserves backward compatibility if `TerminalScreen` is ever instantiated without `SessionsScreen`.

**Change 2: Gate SnackBar on `isActive`** (lines 70-79):
```dart
// BEFORE (lines 70-79):
if (nextState is SshFailed && prevState is! SshFailed) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not connect to $machineName.')),
  );
  _pickerShown = false;
}

// AFTER:
if (widget.isActive && nextState is SshFailed && prevState is! SshFailed) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not connect to $machineName.')),
  );
  _pickerShown = false;
}
```

**Change 3: Remove `AppBar`** (lines 135-170 deleted, `appBar:` parameter removed from `Scaffold`):
- The entire `appBar:` argument to `Scaffold` is removed
- `_ConnectingDot` private class (lines 284-329) is KEPT — the tab chip's status dot will reuse the same animation pattern
- `automaticallyImplyLeading: false` is removed (AppBar gone)
- The `statusLabel` and `isPulsing` computed values (lines 113-123) can be removed or kept for internal use — they are only used by the removed AppBar

**`go_router` import**: The `context.pop()` call in line 166 (`onPressed: () => context.pop()`) is removed with the AppBar. The `go_router` import (line 3) may become unused — remove it if no other `context.push/go/pop` calls remain in the file.

**Key deviation:** After removing the AppBar, `TerminalScreen` becomes a "pure terminal" widget designed exclusively for embedding inside `SessionsScreen`. The `_ConnectingDot` widget class at the bottom of the file is preserved because the tab chip status dot reuses the same 800ms opacity-pulse animation pattern.

---

### `lib/features/terminal/providers/ssh_session_provider.dart` (MODIFIED — surgical addition)

**Self-analog.** Read fully (405 lines).

**Change 1: Add `_keepAliveLink` field** (after `_connectionGeneration` field, line 57):
```dart
// ADD after line 57 (_connectionGeneration field):
KeepAliveLink? _keepAliveLink;
```

`KeepAliveLink` is from `package:flutter_riverpod/flutter_riverpod.dart` — already imported transitively via `riverpod_annotation`. Confirm import is available; if not, add:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

**Change 2: Call `ref.keepAlive()` at top of `build()`** (line 74, BEFORE `ref.onDispose()`):
```dart
// BEFORE (line 74-84):
@override
Future<SshSessionState> build(String machineId) async {
  // Register cleanup FIRST — before any awaits — so dispose always fires.
  ref.onDispose(() {
    ...
  });

// AFTER:
@override
Future<SshSessionState> build(String machineId) async {
  // Prevent autoDispose from firing during IndexedStack tab switches.
  // SessionsNotifier.closeTab() calls _keepAliveLink!.close() to allow disposal.
  _keepAliveLink = ref.keepAlive();

  // Register cleanup FIRST — before any awaits — so dispose always fires.
  ref.onDispose(() {
    ...
  });
```

`ref.keepAlive()` must be the very first line — before `ref.onDispose()` and before any `await` — to prevent the autoDispose race during provider initialization.

**Change 3: Add `closeAndDispose()` method** (after `reconnect()` method, before `sendText()`, around line 390):
```dart
// ADD new public method — called by SessionsNotifier.closeTab():
/// Disconnects SSH cleanly then releases the keepAlive link so Riverpod
/// can autoDispose this provider entry. Called by SessionsNotifier.closeTab().
void closeAndDispose() {
  cancel(); // stop any active retry countdown (_cancelRequested = true)
  _sshSession?.close();
  _client?.close();
  _keepAliveLink?.close(); // allows Riverpod autoDispose to fire
}
```

Pattern for `cancel()` (lines 334-338 — already exists):
```dart
void cancel() {
  _cancelRequested = true;
  _countdownTimer?.cancel();
  _countdownTimer = null;
}
```

`closeAndDispose()` calls `cancel()` first (sets `_cancelRequested`, stops timer), then closes SSH objects, then releases the keep-alive. This is the correct teardown order.

**Key deviation:** The `@Riverpod(retry: _noRetry)` annotation stays unchanged — `keepAlive` is NOT added to the annotation (that would prevent all family entries from ever disposing). The per-instance `ref.keepAlive()` in `build()` is the correct mechanism.

---

## Shared Patterns

### ConsumerStatefulWidget structure
**Source:** `lib/features/terminal/screens/terminal_screen.dart` lines 25-38
**Apply to:** `sessions_screen.dart`
```dart
class TerminalScreen extends ConsumerStatefulWidget {
  final String machineId;
  const TerminalScreen({super.key, required this.machineId});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  bool _pickerShown = false; // per-instance bool guard pattern
```

### ConsumerWidget structure
**Source:** `lib/features/machines/screens/machine_list_screen.dart` lines 9-13
**Apply to:** `machine_selection_sheet.dart` (needs `ref` to read `machineProvider`)
```dart
class MachineListScreen extends ConsumerWidget {
  const MachineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machinesAsync = ref.watch(machineProvider);
```

### keepAlive: true Riverpod annotation
**Source:** `lib/features/auth/providers/biometric_auth_provider.dart` lines 11-17
**Apply to:** `sessions_provider.dart`
```dart
@Riverpod(keepAlive: true)
class BiometricAuth extends _$BiometricAuth {
  @override
  bool build() => false;
```

### Cross-provider read pattern
**Source:** `lib/features/terminal/providers/ssh_session_provider.dart` line 92
**Apply to:** `sessions_provider.dart` `closeTab()` method
```dart
// Pattern: read sibling provider in notifier method
final machine = ref.read(machineProvider.notifier).get(machineId);
// Sessions equivalent:
final notifier = ref.read(sshSessionProvider(tab.machineId).notifier);
notifier.closeAndDispose();
```

### Theme color access
**Source:** `lib/features/terminal/widgets/session_picker_sheet.dart` lines 26-27 and `lib/features/machines/screens/machine_list_screen.dart` line 22
**Apply to:** `sessions_screen.dart`, `machine_selection_sheet.dart`, tab chip widgets
```dart
// In build():
final colorScheme = Theme.of(context).colorScheme;
// Then reference: colorScheme.surfaceContainerHigh, colorScheme.primary, etc.
```

### addPostFrameCallback guard
**Source:** `lib/features/terminal/screens/terminal_screen.dart` lines 91-108
**Apply to:** `sessions_screen.dart` — ScrollController.animateTo() after tab add
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  // scrollController.animateTo(...)
});
```

### pop-first, callback-after pattern
**Source:** `lib/features/terminal/widgets/session_picker_sheet.dart` lines 88-89
**Apply to:** `machine_selection_sheet.dart` ListTile onTap
```dart
onTap: () {
  Navigator.of(context).pop(); // pop FIRST (synchronous)
  onFolderSelected(folderPaths[index]); // callback AFTER pop
},
```

### Empty state widget
**Source:** `lib/features/machines/screens/machine_list_screen.dart` lines 58-81
**Apply to:** `machine_selection_sheet.dart` no-machines state; `sessions_screen.dart` no-tabs state
```dart
Widget _buildEmptyState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('No machines yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Tap + to add your first machine',
            style: TextStyle(fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    ),
  );
}
```

### go_router navigation pattern
**Source:** `lib/features/machines/screens/machine_list_screen.dart` lines 34, 37, 42
**Apply to:** `sessions_screen.dart` (closing last tab → `/machines`), `machine_list_screen.dart` modification
```dart
context.push('/machines/${machines[i].id}/terminal'); // existing push pattern
context.go('/machines'); // go() to replace stack when closing last tab
```

### Timestamp-based ID generation
**Source:** `lib/core/models/machine.dart` line 29
**Apply to:** `sessions_provider.dart` `openTab()` method
```dart
// machine.dart Machine.generate():
id: DateTime.now().millisecondsSinceEpoch.toString(),

// sessions_provider.dart openTab() — use microseconds for higher uniqueness:
final id = '${machineId}_${DateTime.now().microsecondsSinceEpoch}';
```

---

## No Analog Found

All files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `lib/` (entire source tree)
**Files read for pattern extraction:** 8 source files + 2 planning documents
**Pattern extraction date:** 2026-06-20
