# Phase 7: Sesiones Múltiples con Tabs — Research

**Researched:** 2026-06-20
**Domain:** Flutter state management (Riverpod 3 family + keepAlive), IndexedStack tab lifecycle, go_router routing refactor
**Confidence:** HIGH

---

## Summary

Phase 7 introduces a `SessionsScreen` wrapper that hosts an `IndexedStack` of `TerminalScreen` widgets and a custom horizontal tab strip. The existing `sshSessionProvider(machineId)` family provider drives each tab's SSH lifecycle, but requires an explicit `ref.keepAlive()` call so the autoDispose provider is not torn down when no widget is briefly watching it during tab switches. Closing a tab triggers `keepAliveLink.close()` to allow the provider to dispose cleanly, disconnecting SSH.

The router change is surgical: the single route `/machines/:id/terminal` is replaced with `/sessions`. Machine taps navigate to `/sessions?newMachineId=:id`. If `SessionsScreen` is already active (user taps a machine from the machine list while sessions are open), the navigation must add a tab rather than push a duplicate screen — this requires the `SessionsNotifier` to be the authority, not the router, for tab creation after the first session.

The three hardest coordination problems are: (1) keeping `sshSessionProvider` alive across the `IndexedStack` visibility switches using `ref.keepAlive()` in the notifier's `build()`; (2) ensuring that the `_pickerShown` boolean inside `_TerminalScreenState` is per-tab (it already is, because each `TerminalScreen` is a separate `ConsumerStatefulWidget` instance in the `IndexedStack`); and (3) suppressing `SnackBar` noise on the currently-visible tab when a background tab fails (SESS-04).

**Primary recommendation:** Keep `sshSessionProvider` keyed on `machineId` (not sessionId). Two tabs to the same machine share one SSH session — this is documented in `07-UI-SPEC.md` as an intentional Phase 7 simplification. No provider key change is needed. Add `ref.keepAlive()` to `SshSession.build()` and expose a `keepAliveLink` field; `SessionsNotifier.closeTab()` calls `link.close()` then removes the tab from the list.

---

## Project Constraints (from CLAUDE.md)

- Flutter only — iOS + Android from one codebase
- LAN-only — no external servers or internet dependencies
- Credentials via `flutter_secure_storage` — no plaintext storage
- Terminal must render ANSI/cursor sequences (xterm.dart, not a custom renderer)
- Standard stack: `dartssh2`, `xterm`, `flutter_riverpod 3.3.x`, `flutter_secure_storage`, `go_router 17.3.0`, `speech_to_text`, `shared_preferences`
- No new packages for Phase 7 — all required widgets (`IndexedStack`, `SingleChildScrollView`, `PopScope`, `ScrollController`, `showModalBottomSheet`) are Flutter SDK built-ins [VERIFIED: 07-UI-SPEC.md Registry Safety section]

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESS-01 | User can open multiple simultaneous SSH sessions (same or different machine) and navigate between them via a tab strip | IndexedStack keeps all TerminalScreen widgets mounted; SessionsNotifier manages tab list; sshSessionProvider family provides independent sessions per machineId |
| SESS-02 | Each tab shows machine name + scrollable horizontal tab strip + independent close button | Custom SingleChildScrollView row per UI-SPEC; sessionsProvider drives tab list rendering |
| SESS-03 | Closing a tab disconnects that SSH session cleanly without affecting others | keepAliveLink.close() releases the autoDispose provider; cancel() call closes SSH client; ref.onDispose() in SshSession already handles cleanup |
| SESS-04 | Failed tab stays open with last output visible and error indicator; other tabs unaffected | SshFailed state already carries Terminal (RECON-05); status dot on tab chip reads sshSessionProvider(machineId) state; SnackBar suppressed for background tab failures |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tab list state (order, active index) | App state (Riverpod SessionsNotifier) | — | Tab list is a UI concern that outlives any single screen; must survive navigation |
| SSH session lifecycle per tab | Provider (SshSession Notifier) | App state | Each session has its own reconnection state machine; Riverpod family + keepAlive manages lifetime |
| Terminal rendering per tab | Widget (TerminalScreen in IndexedStack) | — | Each TerminalScreen owns one xterm Terminal via sshSessionProvider |
| Tab strip UI | Widget (SessionsScreen) | — | Pure presentation; reads sessionsProvider and sshSessionProvider states |
| Router / navigation | go_router (GoRouter) | SessionsNotifier | Router owns the `/sessions` route; SessionsNotifier owns which tabs exist |
| Session start picker (per tab) | Widget (TerminalScreen._pickerShown) | — | _pickerShown is already per-ConsumerStatefulWidget-instance; no change needed |
| Biometric auth gate | app.dart (ClaudePilotApp.build) | — | SessionsScreen is inside the authenticated branch; no additional gate needed |

---

## Standard Stack

### Core (no new packages)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | 3.3.1 | SessionsNotifier + sshSessionProvider keepAlive | Already in project; Notifier<T> with keepAlive: true for tab list |
| `riverpod_annotation` | 4.0.2 | Code generation for SessionsNotifier | Already in project; consistent with all other providers |
| `go_router` | 17.3.0 | `/sessions` route + query parameter `newMachineId` | Already in project; state.uri.queryParameters['newMachineId'] |
| `xterm` | 4.0.0 | Terminal rendering in each tab | Already in project; Terminal instance lives in SshSession notifier |
| `dartssh2` | 2.18.0 | SSH transport per session | Already in project; one SSHClient per sshSessionProvider entry |

### Supporting (Flutter SDK built-ins)

| Widget/API | Purpose | Notes |
|------------|---------|-------|
| `IndexedStack` | Mount all TerminalScreen widgets simultaneously; show only active | Hidden children remain mounted, state preserved [VERIFIED: Flutter SDK docs] |
| `SingleChildScrollView(scrollDirection: Axis.horizontal)` | Tab strip overflow scroll | Built-in; ScrollController.animateTo() to reveal new tab |
| `PopScope(canPop: false)` | Prevent Android back gesture from popping SessionsScreen | Required per UI-SPEC interaction contract |
| `showModalBottomSheet` | Machine selection sheet when adding a new session | Already used in Phase 6 SessionPickerSheet — same pattern |
| `Visibility(visible: false, maintainState: true, child: ExcludeSemantics(...))` | Hide inactive TerminalScreen from semantics tree without unmounting | [VERIFIED: Flutter SDK docs — maintainState preserves State object] |
| `ScrollController` | Programmatic scroll to new tab on creation | Standard Flutter; attach to SingleChildScrollView |

**No new packages required.** [VERIFIED: 07-UI-SPEC.md § Registry Safety]

---

## Package Legitimacy Audit

No new packages are introduced in Phase 7. All functionality uses existing project dependencies and Flutter SDK built-ins.

| Package | Status |
|---------|--------|
| All Phase 7 code | Flutter SDK + existing pubspec.yaml dependencies only |

**Packages removed due to slopcheck:** none (no new packages)
**Packages flagged as suspicious:** none

*UUID generation for SessionTab.id uses `'${machineId}_${DateTime.now().microsecondsSinceEpoch}'` — same pattern as `Machine.generate()` — to avoid adding the `uuid` package. This produces a unique-enough key for tab identity within a single app session. [VERIFIED: Machine.generate() in lib/core/models/machine.dart]*

---

## Architecture Patterns

### System Architecture Diagram

```
MachineListScreen
  onTap(machine)
       |
       | context.push('/sessions?newMachineId=${machine.id}')
       v
  GoRouter /sessions route
       |
       | builder reads state.uri.queryParameters['newMachineId']
       | passes to SessionsScreen constructor
       v
  SessionsScreen (ConsumerStatefulWidget, keepAlive via sessionsProvider)
    |  |
    |  |-- AppBar [+ button] --> MachineSelectionSheet
    |  |                              |
    |  |                              | onMachineTap(machineId)
    |  |                              v
    |  |                         ref.read(sessionsProvider.notifier).openTab(machineId)
    |  |
    |  |-- TabStrip (SingleChildScrollView > Row of TabChip widgets)
    |       each TabChip watches: sshSessionProvider(tab.machineId) for status dot color
    |       onTap: sessionsProvider.notifier.setActiveTab(index)
    |       onClose: sessionsProvider.notifier.closeTab(index)
    |
    +-- IndexedStack(index: activeIndex)
          child[0]: TerminalScreen(machineId: tabs[0].machineId)
          child[1]: TerminalScreen(machineId: tabs[1].machineId)
          child[N]: TerminalScreen(machineId: tabs[N].machineId)
               |
               each watches: sshSessionProvider(machineId)
               SSH lifecycle owned by SshSession Notifier (per machineId)
               ref.keepAlive() in SshSession.build() prevents autoDispose
               during IndexedStack visibility switches
```

### Recommended Project Structure

```
lib/
├── app.dart                              # GoRouter: add /sessions route
├── features/
│   ├── sessions/                         # NEW feature directory
│   │   ├── models/
│   │   │   └── session_tab.dart          # SessionTab {id, machineId}, SessionsState {tabs, activeIndex}
│   │   ├── providers/
│   │   │   └── sessions_provider.dart    # SessionsNotifier Notifier<SessionsState> keepAlive:true
│   │   │   └── sessions_provider.g.dart  # generated
│   │   ├── screens/
│   │   │   └── sessions_screen.dart      # SessionsScreen (ConsumerStatefulWidget)
│   │   └── widgets/
│   │       ├── tab_strip.dart            # Row of TabChip + add button
│   │       ├── tab_chip.dart             # Single tab chip (inactive/active states)
│   │       └── machine_selection_sheet.dart # Bottom sheet for picking machine
│   ├── terminal/                         # MODIFIED files only
│   │   ├── providers/
│   │   │   └── ssh_session_provider.dart # Add ref.keepAlive() + keepAliveLink field
│   │   └── screens/
│   │       └── terminal_screen.dart      # Remove AppBar (moved to SessionsScreen); remove close button
│   └── machines/
│       └── screens/
│           └── machine_list_screen.dart  # Change onTap target to /sessions?newMachineId=:id
```

### Pattern 1: ref.keepAlive() in SshSession.build()

**What:** Call `ref.keepAlive()` at the start of `SshSession.build()` to prevent the autoDispose provider from tearing down when the IndexedStack hides the watching TerminalScreen. Store the returned `KeepAliveLink` as an instance field. `SessionsNotifier.closeTab()` calls `link.close()` to allow disposal.

**When to use:** Any autoDispose provider that must outlive the widget watching it (tab switches, etc.)

```dart
// Source: pub.dev/documentation/riverpod/latest/riverpod/Ref/keepAlive.html
// Inside SshSession class:

KeepAliveLink? _keepAliveLink;

@override
Future<SshSessionState> build(String machineId) async {
  // Prevent autoDispose from firing during IndexedStack tab switches.
  // SessionsNotifier.closeTab() calls _keepAliveLink!.close() to allow disposal.
  _keepAliveLink = ref.keepAlive();

  // ... rest of existing build() unchanged ...
}

/// Called by SessionsNotifier when closing this tab.
/// Disconnects SSH then allows provider autoDispose to fire.
void closeAndDispose() {
  cancel(); // stop any retry loops
  _client?.close();
  _sshSession?.close();
  _keepAliveLink?.close(); // allows Riverpod to dispose this provider entry
}
```

**Critical:** `ref.keepAlive()` must be called before any `await` in `build()` — the `ref.onDispose()` call already satisfies this (it is first in build), but `ref.keepAlive()` should be the very first line to ensure no await gap. [VERIFIED: ref.dart implementation — keepAlive() adds to _keepAliveLinks list immediately]

### Pattern 2: SessionsNotifier (Notifier<SessionsState>, keepAlive: true)

**What:** A `keepAlive: true` Notifier (not AsyncNotifier — the tab list is synchronous) that owns the ordered list of tabs and the active index.

```dart
// Source: riverpod_annotation 4.0.2 patterns used throughout this codebase
@Riverpod(keepAlive: true)
class Sessions extends _$Sessions {
  @override
  SessionsState build() => const SessionsState(tabs: [], activeIndex: 0);

  void openTab(String machineId) {
    final id = '${machineId}_${DateTime.now().microsecondsSinceEpoch}';
    final newTab = SessionTab(id: id, machineId: machineId);
    final tabs = [...state.tabs, newTab];
    state = SessionsState(tabs: tabs, activeIndex: tabs.length - 1);
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeIndex: index);
  }

  void closeTab(int index) {
    final tab = state.tabs[index];
    // Tell the SSH provider to disconnect and release keepAlive.
    final notifier = ref.read(sshSessionProvider(tab.machineId).notifier);
    notifier.closeAndDispose();

    final tabs = [...state.tabs]..removeAt(index);
    if (tabs.isEmpty) {
      state = const SessionsState(tabs: [], activeIndex: 0);
      return;
    }
    final newActive = (index > 0 ? index - 1 : 0).clamp(0, tabs.length - 1);
    state = SessionsState(tabs: tabs, activeIndex: newActive);
  }
}
```

**keepAlive: true** is required on `sessionsProvider` for the same reason as `biometricAuthProvider` — autoDispose would reset the tab list during GoRouter navigation transitions. [VERIFIED: biometric_auth_provider.dart comment in codebase]

### Pattern 3: IndexedStack with Visibility + ExcludeSemantics for inactive terminals

**What:** Wrap each inactive TerminalScreen in `Visibility(visible: false, maintainState: true)` inside the IndexedStack so accessibility tools don't expose multiple terminal outputs simultaneously.

```dart
// Source: Flutter SDK docs — Visibility.maintainState preserves State object
IndexedStack(
  index: activeIndex,
  children: List.generate(tabs.length, (i) {
    final isActive = i == activeIndex;
    return isActive
        ? TerminalScreen(machineId: tabs[i].machineId)
        : Visibility(
            visible: false,
            maintainState: true,
            child: ExcludeSemantics(
              child: TerminalScreen(machineId: tabs[i].machineId),
            ),
          );
  }),
)
```

**Note:** `IndexedStack` itself already keeps all children mounted. The `Visibility` wrapping is for accessibility (ExcludeSemantics) only — not for lifecycle management. [VERIFIED: Flutter SDK IndexedStack docs — "each keeping their respective states"]

### Pattern 4: go_router /sessions route with newMachineId query param

**What:** `/sessions` replaces `/machines/:id/terminal`. Query parameter `newMachineId` tells the route builder which machine to open a tab for.

```dart
// Source: go_router 17.3.0 — state.uri.queryParameters pattern
GoRoute(
  path: '/sessions',
  builder: (context, state) {
    final newMachineId = state.uri.queryParameters['newMachineId'];
    return SessionsScreen(initialMachineId: newMachineId);
  },
),
```

`SessionsScreen.initState()` calls `sessionsProvider.notifier.openTab(initialMachineId)` if `initialMachineId != null` AND the tab is not already open. If `/sessions` is already on screen (user taps machine from list while tabs exist), go_router will rebuild the widget with the new query parameter — `SessionsScreen` must handle this via `didUpdateWidget`.

**Machine list navigation change:**
```dart
// Before Phase 7:
onTap: () => context.push('/machines/${machines[i].id}/terminal'),

// After Phase 7:
onTap: () => context.push('/sessions?newMachineId=${machines[i].id}'),
```

### Pattern 5: TerminalScreen modifications

**What:** `TerminalScreen` loses its own `AppBar` (the `SessionsScreen` AppBar is above the IndexedStack). The disconnect close button moves to the tab chip close button. The `ref.listen` SnackBar for `SshFailed` must be suppressed for background tabs.

**Background tab failure (SESS-04):** The status dot on the tab chip reads `sshSessionProvider(machineId)` state — it changes to `colorScheme.error` automatically when the provider is in `SshFailed`. No SnackBar is emitted from background tabs. The SnackBar in `TerminalScreen` fires only if the TerminalScreen's owning tab is currently active.

To know if a tab is active, `TerminalScreen` must receive an `isActive` boolean from `SessionsScreen`:

```dart
class TerminalScreen extends ConsumerStatefulWidget {
  final String machineId;
  final bool isActive; // new: controls SnackBar emission

  const TerminalScreen({super.key, required this.machineId, this.isActive = true});
  // ...
  // In ref.listen callback:
  if (widget.isActive && nextState is SshFailed && prevState is! SshFailed) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
}
```

### Anti-Patterns to Avoid

- **Using `TabBar` + `TabBarView`:** `TabBarView` creates/destroys tab children on scroll, destroying the xterm Terminal state. Must use IndexedStack. [VERIFIED: 07-UI-SPEC.md § Architecture Decision]
- **Using `StatefulShellRoute` from go_router:** Static branch count is incompatible with runtime-created SSH sessions. [VERIFIED: STATE.md decisions section]
- **Calling `ref.invalidateSelf()` on tab close:** This would recreate the provider and lose scrollback. Use `cancel()` + `keepAliveLink.close()` instead.
- **Calling `context.go('/sessions?...')` from machine list:** `go()` replaces the entire navigation stack. Use `context.push('/sessions?...')` to keep the machine list on the back stack.
- **Placing `sshSessionProvider` keepAlive at annotation level (`@Riverpod(keepAlive: true)`):** This would prevent ALL provider family entries from ever being disposed — including closed tabs. Use per-instance `ref.keepAlive()` in `build()` + `link.close()` on tab close instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSH lifecycle per tab | Custom session manager class | `sshSessionProvider(machineId)` family + `ref.keepAlive()` | Provider already handles reconnect loops, scrollback preservation, countdown — don't duplicate |
| Tab persistence across navigation | Custom Navigator/RouteObserver | `sessionsProvider` (Riverpod Notifier, keepAlive: true) | Riverpod state survives go_router transitions when keepAlive; no custom route observer needed |
| Tab overflow scroll | Custom gesture detector | `SingleChildScrollView(scrollDirection: Axis.horizontal)` | Built-in; ScrollController handles programmatic scroll-to-new-tab |
| Terminal state preservation | Copy/restore xterm buffer | IndexedStack (keeps all children mounted) | IndexedStack is the exact tool for this; copying xterm state is lossy |
| UUID for tab IDs | Add `uuid` package | `'${machineId}_${DateTime.now().microsecondsSinceEpoch}'` | Machine.generate() already uses this pattern; good enough for runtime tab identity |
| Screen reader exclusion for inactive tabs | Custom semantics override | `Visibility(maintainState: true) + ExcludeSemantics` | Two SDK widgets compose the exact behavior needed |

**Key insight:** The hardest part of this phase is provider lifetime management, not UI construction. Riverpod's `ref.keepAlive()` / `KeepAliveLink` API is exactly the right tool for "keep this provider alive even when no widget is watching it, until I explicitly say to dispose it."

---

## Common Pitfalls

### Pitfall 1: sshSessionProvider disposes during tab switch (autoDispose race)

**What goes wrong:** IndexedStack switches the visible child. The newly-hidden `TerminalScreen` stops watching `sshSessionProvider(machineId)`. Because the provider is `isAutoDispose: true` (its annotation has no `keepAlive: true`), Riverpod sees zero listeners and disposes it — killing the SSH session mid-operation.

**Why it happens:** Riverpod 3 autoDispose fires as soon as the listener count hits zero. The IndexedStack hides the widget (stopping its `ref.watch()`) without unmounting it, but the provider still sees zero active watch calls.

**How to avoid:** Call `ref.keepAlive()` at the top of `SshSession.build()` (before any awaits). Store the returned `KeepAliveLink` as `_keepAliveLink`. Only `_keepAliveLink.close()` will allow disposal to proceed. Call this in the new `closeAndDispose()` method, triggered by `SessionsNotifier.closeTab()`. [VERIFIED: pub.dev/documentation/riverpod/latest/riverpod/Ref/keepAlive.html]

**Warning signs:** SSH session drops immediately after switching to another tab; reconnect banner appears briefly on switching back.

### Pitfall 2: SessionsScreen rebuilds open a duplicate tab

**What goes wrong:** User taps a machine in `MachineListScreen` while `/sessions` is already showing. `context.push('/sessions?newMachineId=X')` navigates again to `/sessions`. Go_router may rebuild `SessionsScreen` with the new query parameter, and `initState()` calls `openTab()` again — creating a second tab for the same machine.

**Why it happens:** If `initState()` unconditionally calls `openTab(initialMachineId)`, every rebuild/reinitialize of the screen opens a new tab.

**How to avoid:** `SessionsScreen.initState()` calls `openTab()` only on first build (`_initialTabOpened` guard, analogous to `_pickerShown` in TerminalScreen). Tab opening from the machine list after first open must go through `SessionsNotifier` directly — the machine list calls `context.push('/sessions?newMachineId=X')`, go_router calls the builder with the new query param, and `SessionsScreen` handles this via `didUpdateWidget` to call `sessionsProvider.notifier.openTab()` for the new machine ID.

**Alternative simpler approach:** Have the machine list navigate to `/sessions` without a query param AND call `sessionsProvider.notifier.openTab(machineId)` directly before navigating. Then `SessionsScreen` just reads the existing tab list. This avoids query-param coordination entirely.

**Warning signs:** Duplicate tabs for the same machine after tapping machine list from the sessions screen.

### Pitfall 3: _pickerShown triggers on every IndexedStack child mount

**What goes wrong:** When `SessionsScreen` builds its IndexedStack, all TerminalScreen instances are mounted simultaneously (IndexedStack mounts all children). Each `TerminalScreen.initState()` runs — and `_pickerShown = false` — so all tabs could show the picker on their first `SshConnected` transition.

**Why it doesn't happen:** Each `TerminalScreen` has its own `_TerminalScreenState` instance with its own `_pickerShown` field. The picker logic is inside `ref.listen()` which fires independently per state, and the guard is per-widget-instance. No cross-tab contamination. [VERIFIED: terminal_screen.dart — _pickerShown is an instance field of _TerminalScreenState]

**Action:** No code change needed. Document this as "working correctly by design."

### Pitfall 4: SnackBar from background tab failure appears over active terminal

**What goes wrong:** `TerminalScreen._TerminalScreenState.build()` has a `ref.listen()` that emits a SnackBar on `SshFailed`. When a background tab's session fails, its TerminalScreen (still mounted in IndexedStack) fires the SnackBar — which appears over the active tab's terminal, confusing the user.

**Why it happens:** All `TerminalScreen` widgets are mounted. All their `ref.listen()` callbacks fire regardless of visibility.

**How to avoid:** Pass `isActive` boolean from `SessionsScreen` to `TerminalScreen`. Gate the SnackBar emission: `if (widget.isActive && ...)`. The SESS-04 requirement explicitly says: "No SnackBar is shown on the active tab for a background tab failure." [VERIFIED: 07-UI-SPEC.md § SESS-04 interaction contract]

**Warning signs:** SnackBar saying "Could not connect to MachineX" appears while the user is interacting with a different tab.

### Pitfall 5: Same machine in two tabs — shared sshSessionProvider entry

**What goes wrong:** User opens two tabs for the same machine. `sshSessionProvider(machineId)` is keyed on `machineId`. Both tabs reference the same provider entry — they show identical output and share one SSH connection. Closing one tab's "close button" calls `closeAndDispose()`, ending the session for both tabs.

**Why it is acceptable in Phase 7:** The UI-SPEC documents this explicitly: "two tabs to the same machine show the same session... This decision avoids provider key collisions without introducing composite keys in Phase 7." [VERIFIED: 07-UI-SPEC.md § State Management Contract]

**How to avoid user confusion:** The tab chip shows machine name; having two tabs with the same name visually signals they share a session. No additional mitigation needed in Phase 7.

**Warning signs:** None — this is expected behavior. The planner task notes must document it.

### Pitfall 6: ScrollController not attached when animateTo() is called for new tab

**What goes wrong:** New tab is added to `sessionsProvider`. `SessionsScreen` rebuilds. `ScrollController.animateTo()` is called to scroll the strip to the new tab — but the controller is not yet attached to the `SingleChildScrollView` (the build hasn't completed yet).

**How to avoid:** Call `scrollController.animateTo()` inside `WidgetsBinding.instance.addPostFrameCallback()`, same pattern used in `terminal_view_wrapper.dart` and `terminal_screen.dart` for PTY resize and picker sheet. [VERIFIED: terminal_screen.dart line 91-108 — addPostFrameCallback pattern]

**Warning signs:** `ScrollController not attached` assertion error when opening 3+ tabs.

### Pitfall 7: app.dart biometric gate and SessionsScreen ordering

**What goes wrong:** The biometric gate in `app.dart` wraps the entire `MaterialApp.router`. If `sessionsProvider` is `keepAlive: true`, it persists across authentication state changes. When the app re-locks (background > 10 min), `sessionsProvider` still holds the tab list — the sessions are preserved in the provider state even though the lock screen is shown. On re-authentication, the sessions reopen in the same state.

**Why this is correct behavior:** The SSH sessions are already alive (keepAlive in `sshSessionProvider`). The lock screen is a UI gate, not a session termination event. This is the intended behavior — the user re-authenticates and continues where they left off.

**Warning signs:** None — this is correct. Document it as a design note.

---

## Code Examples

### SessionTab model

```dart
// Source: 07-UI-SPEC.md § State Management Contract
class SessionTab {
  final String id;       // unique per tab-open event
  final String machineId; // references Machine.id

  const SessionTab({required this.id, required this.machineId});
}

class SessionsState {
  final List<SessionTab> tabs;
  final int activeIndex;

  const SessionsState({required this.tabs, required this.activeIndex});

  SessionsState copyWith({List<SessionTab>? tabs, int? activeIndex}) =>
      SessionsState(
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
      );
}
```

### Status dot color derivation in TabChip

```dart
// Source: 07-UI-SPEC.md § Color section + Interaction Contract SESS-04
Color _dotColor(SshSessionState? state, ColorScheme cs) {
  return switch (state) {
    SshConnected() => Colors.green.shade400,
    SshConnecting() || SshReconnecting() => cs.secondary,
    SshFailed() => cs.error,
    null => cs.secondary, // loading = connecting
  };
}
```

### PopScope for back gesture suppression

```dart
// Source: Flutter SDK — PopScope(canPop: false) per 07-UI-SPEC.md interaction contract
PopScope(
  canPop: false,
  child: Scaffold(
    // ...
  ),
)
```

### Tab chip active vs inactive visual state

```dart
// Source: 07-UI-SPEC.md § Screen Inventory — tab chip spec
Container(
  decoration: BoxDecoration(
    color: isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(8),
    border: isActive
        ? Border(bottom: BorderSide(color: colorScheme.primary, width: 2))
        : null,
  ),
  // label color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single TerminalScreen route (`/machines/:id/terminal`) | SessionsScreen with IndexedStack at `/sessions` | Phase 7 | Router loses one route; all terminal access via sessions screen |
| No keepAlive on sshSessionProvider | `ref.keepAlive()` in build() + `KeepAliveLink.close()` on tab close | Phase 7 | Provider lifetime is explicitly controlled, not driven by widget mount/unmount |
| TerminalScreen owns its AppBar (machine name, disconnect) | SessionsScreen owns the AppBar area; tab chip owns disconnect | Phase 7 | TerminalScreen becomes a "pure terminal" widget embedded in the sessions container |

**Deprecated/outdated:**
- `/machines/:id/terminal` route: removed entirely in Phase 7. All callers (MachineListScreen onTap) must be updated.
- `context.push('/machines/${machine.id}/terminal')` in machine_list_screen.dart: replaced with sessions navigation pattern.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `sshSessionProvider` with `machineId` key — same machine in two tabs shares one SSH session. This is the Phase 7 simplification documented in UI-SPEC. | Pitfall 5, Pattern 2 | Low — UI-SPEC explicitly documents this; if two independent sessions to same machine are required, composite key (sessionId) would be needed in a future phase |
| A2 | IndexedStack keeps all children mounted even when `visible: false` via Visibility wrapper | Pattern 3 | Low — confirmed by Flutter SDK docs "each keeping their respective states" |
| A3 | go_router 17.3.0 `context.push('/sessions?...')` will rebuild `SessionsScreen` with new query params if already on stack | Pitfall 2 | Medium — go_router push behavior on same-path push may vary; the simpler alternative (call sessionsProvider.notifier.openTab() directly and then context.push('/sessions') without query param, using context.canPop guard) avoids this entirely |
| A4 | Phase 5 biometric auth is complete (all 3 SUMMARY files exist) — `biometricAuthProvider` and auth gate in `app.dart` are already implemented | Architectural responsibility map | Low — verified by reading Phase 5 SUMMARY files and app.dart source |

---

## Open Questions (RESOLVED)

1. **go_router same-route push behavior** — RESOLVED
   - Resolution: Use alternative pattern — machine list calls `ref.read(sessionsProvider.notifier).openTab(machineId)` directly, then `context.push('/sessions')` (no query param). The notifier is the authority for tab creation. Implemented in 07-02 Task 3 Change C2.

2. **TerminalScreen AppBar removal scope** — RESOLVED
   - Resolution: Remove AppBar from TerminalScreen entirely. SessionsScreen AppBar handles context. Implemented in 07-02 Task 3 Change A3.

3. **Pending Phase 5 plans in ROADMAP (05-02, 05-03 shown as unchecked)** — RESOLVED (informational)
   - Resolution: Phase 5 is complete based on SUMMARY files and presence of `requireBiometric()` in `machine_list_screen.dart` and `biometricAuthProvider` in `app.dart`. ROADMAP checkboxes are stale. No action needed.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 7 is a code/UI change only. No new external tools, services, runtimes, or CLI utilities are required beyond the existing Flutter SDK and project dependencies.

---

## Validation Architecture

No automated test infrastructure exists in this project (no `test/` directory, no `*_test.dart` files, no `flutter_test` test runner configuration beyond the default `flutter_test` dev dependency).

Manual validation checkpoints per requirement:

| Req ID | Behavior | Test Type | How to Verify |
|--------|----------|-----------|---------------|
| SESS-01 | Open second SSH session while first is active | Manual smoke | Connect to machine A, tap machine B in list, verify both tabs show independently with SSH active |
| SESS-01 | Tab switch does not trigger reconnect | Manual smoke | Switch between tabs; verify no reconnect banner appears on either tab |
| SESS-02 | Tab strip scrolls when 4+ tabs open | Manual smoke | Open 4+ sessions; verify horizontal scroll works and all tabs accessible |
| SESS-02 | Each tab shows machine name + status dot | Manual smoke | Verify tab chip content matches machine name and dot color matches connection state |
| SESS-03 | Closing a tab disconnects SSH cleanly | Manual smoke | Close one tab; verify other tab's SSH session continues; verify closed machine no longer appears in `ssh` process list on server |
| SESS-03 | Closing last tab navigates to /machines | Manual smoke | With one tab, tap close; verify machine list screen appears |
| SESS-04 | Background tab failure shows error dot, no SnackBar | Manual smoke | Kill SSH daemon for machine B while on machine A tab; verify machine B dot turns red, no SnackBar appears on machine A view |
| SESS-04 | Switching to failed tab shows ReconnectFailedOverlay | Manual smoke | Tap the failed tab; verify existing Phase 4 overlay appears |

**Wave 0 Gaps:** None — no test files to create. All validation is manual.

---

## Security Domain

No new security surface in Phase 7. The phase:
- Adds no new network connections beyond what SSH already does
- Adds no new credential storage
- Adds no new authentication flows (auth gate in app.dart covers SessionsScreen by being in the authenticated branch)
- The `sessionsProvider` state (tab list with machineId references) is in-memory only — not persisted to disk

The biometric auth gate in `app.dart` wraps the entire `MaterialApp.router` (including the new `/sessions` route). SessionsScreen is inside the authenticated branch by construction. [VERIFIED: app.dart — isAuthenticated gates MaterialApp.router vs MaterialApp(home: LockScreen())]

---

## Sources

### Primary (HIGH confidence)
- `lib/features/terminal/providers/ssh_session_provider.dart` — existing SshSession provider; verified autoDispose: true, @Riverpod(retry: _noRetry), no keepAlive annotation
- `lib/app.dart` — existing GoRouter; verified `/machines/:id/terminal` route structure
- `lib/features/terminal/screens/terminal_screen.dart` — verified _pickerShown per-instance, ref.listen SnackBar pattern
- `lib/features/terminal/models/ssh_session_state.dart` — verified SshFailed carries Terminal (RECON-05)
- `.planning/phases/07-sesiones-m-ltiples-con-tabs/07-UI-SPEC.md` — canonical UI contract for Phase 7
- `pub.dev/documentation/riverpod/latest/riverpod/Ref/keepAlive.html` — verified KeepAliveLink.close() behavior
- Flutter SDK docs — verified IndexedStack keeps all children mounted; Visibility.maintainState preserves State

### Secondary (MEDIUM confidence)
- `github.com/rrousselGit/riverpod` ref.dart source — verified keepAlive() implementation adds to _keepAliveLinks before any await
- `pub.dev/documentation/go_router/latest/go_router/GoRouter/push.html` — verified push() adds to stack; same-path push behavior inferred (A3)

### Tertiary (LOW confidence / ASSUMED)
- go_router same-route push rebuilding SessionsScreen: behavior on push to current route with new query params (see Open Question 1 — planner should use alternative pattern to avoid this)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all tools verified in codebase
- Provider keepAlive pattern: HIGH — verified via pub.dev official API docs and GitHub source
- Architecture (IndexedStack + SessionsNotifier): HIGH — mirrors documented decisions in STATE.md and UI-SPEC
- Pitfalls: HIGH — derived directly from reading existing code (ref.listen SnackBar, _pickerShown, autoDispose annotation)
- go_router same-route push behavior: MEDIUM — Open Question 1 recommends alternative to avoid the uncertainty

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 (stable packages — go_router, riverpod_annotation 4.x)
