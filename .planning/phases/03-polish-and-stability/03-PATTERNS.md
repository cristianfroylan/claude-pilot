# Phase 3: Polish and Stability - Pattern Map

**Mapped:** 2026-06-19
**Files analyzed:** 5 (modified only — no new files this phase)
**Analogs found:** 5 / 5 (all are self-analogs — each file is its own closest match)

---

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/terminal/providers/ssh_session_provider.dart` | provider | request-response | self (`_connectOnce` method) | exact — single constructor param addition |
| `lib/features/terminal/screens/terminal_screen.dart` | screen/widget | request-response | self (Scaffold body Column) + `add_edit_machine_screen.dart` (SingleChildScrollView in body) | exact |
| `lib/features/terminal/widgets/terminal_view_wrapper.dart` | widget | event-driven | self (LayoutBuilder + addPostFrameCallback) | exact — stale comment fix only |
| `lib/features/terminal/widgets/permission_card.dart` | widget | request-response | self (line 57 already has `overflow: TextOverflow.ellipsis`) | exact — verify-only, no edit needed |
| `lib/features/terminal/widgets/voice_bottom_sheet.dart` | widget | request-response | `lib/features/machines/screens/add_edit_machine_screen.dart` (SingleChildScrollView wrapping body Column) | role-match |

---

## Pattern Assignments

### `lib/features/terminal/providers/ssh_session_provider.dart` (provider, request-response)

**Change:** Add `keepAliveInterval: const Duration(seconds: 30)` to `SSHClient` constructor in `_connectOnce`.

**Analog:** Self — `_connectOnce` method.

**Current constructor** (lines 81–85):
```dart
_client = SSHClient(
  await SSHSocket.connect(host, port),
  username: username,
  onPasswordRequest: () => password ?? '',
);
```

**Target constructor** (add one named parameter after `onPasswordRequest`):
```dart
_client = SSHClient(
  await SSHSocket.connect(host, port),
  username: username,
  onPasswordRequest: () => password ?? '',
  keepAliveInterval: const Duration(seconds: 30),
);
```

**Critical notes:**
- dartssh2 2.18.0 already defaults `keepAliveInterval` to `Duration(seconds: 10)`. This change makes it explicit at 30s (less frequent, per user decision in CONTEXT.md).
- The parameter is `Duration?` — do NOT pass `null` (that disables keepalive entirely).
- No other changes to `ssh_session_provider.dart` are needed this phase.
- The `.done.catchError` guard (line 90–92), retry loop (lines 59–75), and `resizeTerminal` method (lines 141–142) are all correct as-is — copy nothing from these sections.

---

### `lib/features/terminal/screens/terminal_screen.dart` (screen, request-response)

**Changes:** (1) Add `SafeArea` wrapping the Scaffold `body:` Column. (2) Add `MediaQuery.of(context).viewInsets.bottom` read in the `data:` branch to create a reactive rebuild dependency, plus a `ValueKey(keyboardHeight)` on `TerminalViewWrapper`.

**Analog:** Self — existing Scaffold body structure (lines 133–163).

**Current body** (lines 133–163):
```dart
body: Column(
  children: [
    Expanded(
      child: sessionAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (terminal) => TerminalViewWrapper(
          machineId: machineId,
          terminal: terminal,
        ),
      ),
    ),
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: permissionLine != null
          ? PermissionCard(
              key: const ValueKey('permission-card'),
              machineId: machineId,
              line: permissionLine,
            )
          : const SizedBox.shrink(key: ValueKey('no-card')),
    ),
    InputBar(machineId: machineId),
  ],
),
```

**Target body** (add `SafeArea` + `keyboardHeight` read + `ValueKey`):
```dart
body: SafeArea(
  child: Column(
    children: [
      Expanded(
        child: sessionAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (terminal) {
            // Reading viewInsets.bottom registers a MediaQuery dependency.
            // When keyboard shows/hides, this build() re-runs, TerminalViewWrapper
            // gets a new key, and LayoutBuilder fires with updated constraints.
            final keyboardHeight =
                MediaQuery.of(context).viewInsets.bottom;
            return TerminalViewWrapper(
              key: ValueKey(keyboardHeight),
              machineId: machineId,
              terminal: terminal,
            );
          },
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: permissionLine != null
            ? PermissionCard(
                key: const ValueKey('permission-card'),
                machineId: machineId,
                line: permissionLine,
              )
            : const SizedBox.shrink(key: ValueKey('no-card')),
      ),
      InputBar(machineId: machineId),
    ],
  ),
),
```

**SafeArea placement rule** (from `add_edit_machine_screen.dart` and Flutter docs):
- Wrap `body:` content — NOT the `Scaffold` itself. The `AppBar` already handles its own top safe area; wrapping the Scaffold would create a double gap between the status bar and the AppBar.
- `TerminalScreen` already uses `MediaQuery` at line 89 to clamp `textScaler` — the new `viewInsets.bottom` read sits inside the `data:` branch of `sessionAsync.when`, which is at a deeper point in the tree but still within the same `ConsumerWidget.build` method, so the reactive dependency is correctly registered.

**No-analog context — `ValueKey` on `TerminalViewWrapper`:**
The existing `AnimatedSwitcher` children (lines 152–158) already demonstrate the `ValueKey` pattern for forcing widget identity changes. Copy that pattern: `key: ValueKey(keyboardHeight)` forces a full subtree rebuild when keyboard height changes, guaranteeing `LayoutBuilder` fires with fresh constraints.

---

### `lib/features/terminal/widgets/terminal_view_wrapper.dart` (widget, event-driven)

**Change:** Fix stale comment on line 41. No behavioral change — the `LayoutBuilder` + `addPostFrameCallback` pattern is correct and must not be altered.

**Analog:** Self — full file (53 lines, already read above).

**Stale comment** (line 41):
```dart
// autofocus: false — the InputBar TextField owns keyboard focus.
```

**Correct comment** (replace line 41):
```dart
// autofocus: true — TerminalView takes focus on tap; soft keyboard opens for xterm input.
```

**Preserve unchanged:**
- `LayoutBuilder` wrapper (lines 24–49) — correct pattern, do not alter.
- `addPostFrameCallback` (lines 34–38) — MUST stay; calling `resizeTerminal` directly during build causes setState-during-build errors.
- PTY dimension formula (lines 29–30): `cols = (maxWidth / 8).floor().clamp(40, 220)`, `rows = (maxHeight / 16).floor().clamp(10, 60)`.
- `ExcludeSemantics` wrapper (lines 42–48) — correct accessibility pattern.

**Note on `ValueKey` from `terminal_screen.dart`:** The `key:` is passed from `TerminalScreen` into `TerminalViewWrapper`'s `super.key` — `TerminalViewWrapper` itself requires no changes beyond the comment fix.

---

### `lib/features/terminal/widgets/permission_card.dart` (widget, request-response)

**Change:** None. Verify-only task.

**Finding:** `overflow: TextOverflow.ellipsis` is already present on line 57:
```dart
child: Text(
  line,
  style: const TextStyle(fontSize: 12),
  overflow: TextOverflow.ellipsis,  // line 57 — already correct
),
```

The `Expanded` wrapper on lines 53–59 constrains the `Text` width, so `ellipsis` is effective. No edit needed.

---

### `lib/features/terminal/widgets/voice_bottom_sheet.dart` (widget, request-response)

**Change:** Wrap the existing `Column` in a `SingleChildScrollView` to prevent overflow on small screens or with long transcripts.

**Analog:** `lib/features/machines/screens/add_edit_machine_screen.dart` lines 138–229 — `SingleChildScrollView` wrapping a `Column` inside a `Scaffold` body. The pattern is: `SingleChildScrollView` as the direct parent of `Column`, with `Column` retaining `mainAxisSize: MainAxisSize.min` (or `crossAxisAlignment`).

**SingleChildScrollView pattern from `add_edit_machine_screen.dart`** (lines 138–141):
```dart
body: SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
```

**Current `voice_bottom_sheet.dart` structure** (lines 21–90):
```dart
return Padding(
  padding: EdgeInsets.fromLTRB(
    16,
    8,
    16,
    16 + MediaQuery.of(context).viewInsets.bottom,
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // drag handle, heading, transcript container, action row...
    ],
  ),
);
```

**Target structure** (insert `SingleChildScrollView` between `Padding` and `Column`):
```dart
return Padding(
  padding: EdgeInsets.fromLTRB(
    16,
    8,
    16,
    16 + MediaQuery.of(context).viewInsets.bottom,
  ),
  child: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // drag handle, heading, transcript container, action row — unchanged
      ],
    ),
  ),
);
```

**Safety note:** `showModalBottomSheet` is called with `isScrollControlled: true` (confirmed in `input_bar.dart` line 113). This constrains the bottom sheet's available height, making `SingleChildScrollView` + `Column(mainAxisSize: min)` safe — the sheet framework provides the upper bound that prevents the unbounded-height pitfall.

**Preserve unchanged:** The `viewInsets.bottom` padding (line 26) must remain on the outer `Padding`, not moved inside the scroll view — it ensures the sheet lifts above the keyboard regardless of scroll position.

---

## Shared Patterns

### MediaQuery usage (two patterns in this codebase)

**Pattern A — clamping textScaler** (already in `terminal_screen.dart` lines 89–94):
```dart
return MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(
      MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.3),
    ),
  ),
  child: Scaffold( ... ),
);
```
Apply to: existing pattern, do not alter.

**Pattern B — viewInsets.bottom for keyboard height** (already in `voice_bottom_sheet.dart` line 26, and NEW in `terminal_screen.dart`):
```dart
16 + MediaQuery.of(context).viewInsets.bottom
// and
final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
```
Apply to: `terminal_screen.dart` `data:` branch (new), `voice_bottom_sheet.dart` outer Padding (existing, preserve).

### ValueKey for widget identity forcing

**Source:** `terminal_screen.dart` lines 153–158 (existing `AnimatedSwitcher` children):
```dart
PermissionCard(
  key: const ValueKey('permission-card'),
  ...
)
// and
const SizedBox.shrink(key: ValueKey('no-card'))
```

**Apply to:** `TerminalViewWrapper` in the `data:` branch — `key: ValueKey(keyboardHeight)` forces full subtree rebuild when keyboard height changes, ensuring `LayoutBuilder` receives updated constraints.

### Theme access pattern

**Source:** All existing widget files (`permission_card.dart` line 40, `voice_bottom_sheet.dart` line 19, `input_bar.dart` line 131):
```dart
final colorScheme = Theme.of(context).colorScheme;
```
Apply to: all widget build methods — already present everywhere, do not change.

### Riverpod provider read/watch pattern

**Source:** `terminal_screen.dart` lines 23–28 and all provider files:
```dart
final sessionAsync = ref.watch(sshSessionProvider(machineId));
// ...
ref.read(sshSessionProvider(machineId).notifier).someMethod();
```
No changes needed to any provider access patterns this phase.

---

## No Analog Found

No files fall into this category. All five modified files have clear analogs — either themselves (self-modification) or another screen in the codebase (`add_edit_machine_screen.dart` for `SingleChildScrollView`).

---

## Metadata

**Analog search scope:** `lib/` (all 23 Dart files under `lib/`)
**Files scanned:** 8 source files fully read (all 5 target files + `input_bar.dart`, `add_edit_machine_screen.dart`, `machine_list_screen.dart`)
**Codebase observation:** No `SafeArea` exists anywhere in the current codebase — neither `terminal_screen.dart` nor either machine screen uses it. `terminal_screen.dart` is the first screen that needs it because it is the only full-screen view where content extends to all edges.
**Pattern extraction date:** 2026-06-19
