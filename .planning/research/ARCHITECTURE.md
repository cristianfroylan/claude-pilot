# Architecture Patterns — claude-pilot v2.0

**Domain:** Flutter SSH remote control (milestone extension)
**Researched:** 2026-06-20
**Confidence:** HIGH — based on direct codebase inspection of all relevant files

---

## Existing Architecture (v1.0 Baseline)

### Widget / Navigation Tree

```
main.dart
  ProviderScope
    ClaudePilotApp (MaterialApp.router)
      GoRouter (_router, module-level var in app.dart)
        /machines              → MachineListScreen
        /machines/add          → AddEditMachineScreen
        /machines/:id/edit     → AddEditMachineScreen(machineId)
        /machines/:id/terminal → TerminalScreen(machineId)
```

### Provider Graph

```
SharedPreferences + FlutterSecureStorage
  └─ MachineNotifier (AsyncNotifier, global, generated name: machineProvider)
       └─ SshSession.family(machineId) (AsyncNotifier.autoDispose.family)
            ├─ SSHClient (dartssh2 transport)
            ├─ SSHSession (dartssh2 PTY shell, stored as _sshSession)
            ├─ Terminal (xterm model, maxLines: 2000)
            └─ _permissionController (broadcast StreamController)
                 └─ PermissionDetector.family(machineId) (StreamNotifier.autoDispose.family)
                      └─ maps permissionStream → String?
```

### Key Constraints Observed in Code

- `MachineNotifier` generated name is `machineProvider`. TerminalScreen does `ref.watch(machineProvider)` and `ref.read(machineProvider.notifier)`.
- `SshSession.maxAttempts = 3` is a public static const, referenced in TerminalScreen's error dialog string directly.
- TerminalScreen's error listener distinguishes `prev?.hasValue` (was connected = mid-session drop → SnackBar) from never-connected (AlertDialog with edit link). This logic will break if intermediate states are introduced.
- `_router` is a module-level `final` in `app.dart`, not inside the widget class. GoRouter is not subclassed or wrapped.
- `autoDispose` on `SshSession.family` means popping TerminalScreen disposes and kills the SSH connection. Tabs require overriding this.
- `PermissionDetector` calls `ref.read(sshSessionProvider(machineId).notifier)` to get the stream — it accesses the notifier directly, not the state value. This pattern is fine but will need to be guarded when the state type changes.

---

## Feature 1: Multi-Session Tabs

### Core Problem

Navigation currently pushes `/machines/:id/terminal`. Popping disposes `SshSession` via `autoDispose`. Tabs require sessions to survive independently of whether their screen is currently visible.

### Tab Bar Placement: Inside the Router via ShellRoute

The tab bar must live inside GoRouter's widget tree as a `ShellRoute` shell, not above `MaterialApp.router`. Placing it above the router would break GoRouter's navigation stack (back button, deep links, route guards). A `ShellRoute` provides a persistent shell widget rendered around child routes — exactly what a tab container needs.

```
GoRouter
  ShellRoute (shell: TabShell)         ← new
    /terminal/:id  → TerminalScreen    ← new route path
  GoRoute /machines → MachineListScreen
  GoRoute /machines/add → AddEditMachineScreen
  GoRoute /machines/:id/edit → AddEditMachineScreen
```

`TabShell` renders an `IndexedStack` of `TerminalScreen` widgets for each open tab. Switching tabs changes `TabsNotifier.activeIndex` and the `IndexedStack` shows the correct child without pushing or popping a route.

The old `/machines/:id/terminal` route is removed or redirected to `/terminal/:id`.

### Session Lifetime: ref.keepAlive()

With `autoDispose`, a `sshSessionProvider(machineId)` that is not currently watched by any live widget gets garbage-collected. In an `IndexedStack`, only the active tab's `TerminalScreen` is in the build tree (the others are kept alive by the stack but not rebuilt). The issue: Riverpod considers a provider "unlistened" when no widget is currently watching it during a rebuild cycle.

Fix: when `TabsNotifier.openTab(machineId)` is called, immediately call `ref.keepAlive()` on `sshSessionProvider(machineId)` and store the returned `KeepAliveLink`. When `TabsNotifier.closeTab(machineId)` is called, call `keepAliveLink.close()` to allow `autoDispose` to run again.

`TabsNotifier` must hold the `Map<String, KeepAliveLink>` as private state so links are released exactly once.

### New Files

| File | Purpose |
|------|---------|
| `lib/features/tabs/providers/tabs_notifier.dart` | `Notifier<TabsState>`. Methods: `openTab(machineId)`, `closeTab(machineId)`, `setActive(index)`. Holds `Map<String, KeepAliveLink>` to manage session lifetimes. |
| `lib/features/tabs/models/tabs_state.dart` | Value class: `List<String> openMachineIds`, `int activeIndex` |
| `lib/features/tabs/widgets/tab_shell.dart` | `ConsumerWidget`, the `ShellRoute` shell. Renders tab bar at top + `IndexedStack` of `TerminalScreen` for each open tab. |
| `lib/features/tabs/widgets/tab_bar_strip.dart` | Scrollable horizontal row of tab chips. Each chip shows machine name and a close button. |

### Modified Files

| File | Change |
|------|--------|
| `lib/app.dart` | (1) Add `ShellRoute` wrapping `/terminal/:id` as a child route. (2) Change `TabShell` as the shell builder. (3) Remove or redirect `/machines/:id/terminal`. (4) Pass `ref` into router config via closure (needed for `TabsNotifier.openTab` from within `redirect` callbacks if used). |
| `lib/features/machines/screens/machine_list_screen.dart` | `onTap` changes from `context.push('/machines/${machine.id}/terminal')` to `ref.read(tabsNotifierProvider.notifier).openTab(machine.id)` followed by `context.go('/terminal/${machine.id}')`. |

### Data Flow Change

```
Before:
  MachineListScreen.onTap
    → context.push('/machines/:id/terminal')
    → TerminalScreen created → sshSessionProvider(id) starts
    → context.pop() → autoDispose kills session

After:
  MachineListScreen.onTap
    → tabsNotifier.openTab(id)         [stores KeepAliveLink, prevents autoDispose]
    → context.go('/terminal/:id')      [ShellRoute shows TabShell with TerminalScreen at idx N]
    → tab close button
    → tabsNotifier.closeTab(id)        [releases KeepAliveLink, autoDispose runs]
    → TerminalScreen removed from IndexedStack
```

### Integration Risks

- `keepAlive` + `autoDispose` interaction: if `KeepAliveLink.close()` is called before the last widget watching the provider unmounts (e.g., tab closes while the IndexedStack is still rendering that child), a double-dispose edge case can occur. Mitigation: call `closeTab` after removing the session from `openMachineIds` (so `IndexedStack` removes the child) on the same frame, before Riverpod's post-frame cleanup runs.
- `IndexedStack` keeps all tab widgets in memory even when not visible. With `maxLines: 2000` per Terminal, each tab holds ~2000 lines of text. For 5 tabs this is acceptable; monitor memory usage in testing.
- `TabShell` uses a `ShellRoute` — GoRouter's back-button behavior changes. Test back-button from within a terminal does not pop the tab (it should go back to `/machines`).

---

## Feature 2: Session Start Picker (Working Folder)

### Core Problem

Machine model has no folder data. Need: (a) storage for bookmarked working folders per machine, (b) a picker screen that shows those folders and optionally runs `ls` via SSH before the terminal is shown.

### Machine Model: Add workingFolders Directly

Add `List<String> workingFolders` to the `Machine` model. Do not create a separate `MachineConfig` model. Reasons: the data is machine-scoped and sparse (0–5 entries); a second model means two storage keys per machine, two deserializations, and two null-check paths. Adding to `Machine` is additive, backward-compatible (the `fromJson` handles missing key with a default), and keeps all machine data in one JSON blob under `machines_v1`.

### Session Start Picker Flow

A new modal screen between machine tap and terminal open. The picker watches `sshSessionProvider(machineId)` exactly like `TerminalScreen` does. Because it starts watching first, the session begins connecting while the picker is displayed. When the user picks a folder, `sendText('cd <path>\n')` is called on the notifier, and then `tabsNotifier.openTab(id)` + `context.go('/terminal/:id')` navigate to the terminal. The `TerminalScreen` inherits the same already-connected session and `Terminal` object — no double-connect.

Navigation:
```
MachineListScreen.onTap → /machines/:id/start-picker
SessionStartScreen watches sshSessionProvider(id) → session starts connecting
User picks folder → sendText('cd path\n') → tabsNotifier.openTab + go('/terminal/:id')
TerminalScreen → same sshSessionProvider(id) already running
```

If the user cancels the picker (back button), `autoDispose` runs when the picker leaves the tree (no keepAlive was registered yet), correctly cleaning up.

### New Files

| File | Purpose |
|------|---------|
| `lib/features/session_start/screens/session_start_screen.dart` | Watches `sshSessionProvider(id)`. While connecting: shows spinner. When connected: shows bookmarked folders from `machine.workingFolders` + runs `ls ~` via `sendText('ls\n')` and parses stdout to populate a live folder list. User taps a folder → `sendText('cd path\n')` → navigate to terminal. |
| `lib/features/session_start/widgets/folder_list_tile.dart` | ListTile for a single folder entry (bookmarked or discovered via ls). |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/models/machine.dart` | Add `final List<String> workingFolders`. Update `fromJson`: `(json['workingFolders'] as List<dynamic>?)?.cast<String>() ?? const []`. Update `toJson`: add `'workingFolders': workingFolders`. Update `copyWith`: add `List<String>? workingFolders` param. Update `Machine.generate` constructor: add `workingFolders = const []` default. |
| `lib/core/repositories/machine_repository.dart` | No change needed — `Machine.toJson()` automatically includes the new field. `fromJson` handles missing key. |
| `lib/features/machines/screens/add_edit_machine_screen.dart` | Add a "Working Folders" section: a list of current bookmarks with add/remove controls. Saved alongside other machine fields. |
| `lib/app.dart` | Add `/machines/:id/start-picker` route → `SessionStartScreen(machineId)`. |
| `lib/features/machines/screens/machine_list_screen.dart` | `onTap` navigates to `/machines/:id/start-picker` instead of directly to terminal. |

### Data Flow Change

```
Before:
  tap → sshSessionProvider(id).build() runs (inside TerminalScreen)
       → terminal ready → TerminalScreen shows TerminalView

After:
  tap → /machines/:id/start-picker
       → SessionStartScreen watches sshSessionProvider(id) → connecting
       → connected: shows machine.workingFolders + ls results
       → user taps folder → sendText('cd path\n')
       → tabsNotifier.openTab(id) + go('/terminal/:id')
       → TerminalScreen watches same sshSessionProvider(id) — already connected, cd already sent
```

### Integration Risks

- The picker sends `ls\n` to the PTY and reads stdout to populate the folder list. This is a fire-and-forget command on the live terminal — it will appear in the `Terminal` xterm model's scrollback buffer that `TerminalScreen` will later show. The user will see `ls ~` output in the terminal history. This is acceptable UX but should be documented.
- If `workingFolders = []` and the user skips the picker (future: add a "skip" option), the flow degrades gracefully — just navigate to `/terminal/:id` directly.

---

## Feature 3: Biometric Lock

### Core Problem

Two distinct gate points: (a) app cold start — block all content until authenticated; (b) `AddEditMachineScreen` for an existing machine — block credential exposure.

### Recommended Pattern: Widget-Layer Gates (Not GoRouter Redirect)

GoRouter's `redirect` callback is synchronous. Async biometric authentication cannot be initiated from a `redirect` without a complex `GoRouterRefreshStream` setup. The widget-layer approach is simpler, fully tested in production apps, and easier to unit-test.

**Gate A — App Cold Start:**
Wrap the router output in a `Consumer` widget inside `ClaudePilotApp.build`. When `biometricAuthProvider` state is `unauthenticated`, render `LockScreen` instead of (or overlaid on) `Router`. When `authenticated` or `unavailable` (device has no biometrics), render `Router` normally.

```
ClaudePilotApp.build
  Consumer (watches biometricAuthProvider)
    state == authenticated || unavailable → MaterialApp.router (existing)
    state == unauthenticated             → LockScreen (full-screen overlay)
    state == checking                    → SplashScreen / loading
```

**Gate B — AddEditMachineScreen (existing machine):**
Inside `AddEditMachineScreen.build`, when `machineId != null` (edit mode), check `ref.watch(biometricAuthProvider)`. If not `authenticated`, render a blocking overlay with an "Unlock to edit" button that calls `biometricAuthProvider.notifier.authenticate()`. No route change — the screen stays at the same URL, only the content is obscured.

**Rejected: GoRouter redirect for Gate B.** Would require: storing `returnTo` in redirect, using `GoRouterRefreshStream` to re-trigger redirect after async auth, handling the case where redirect fires before `ProviderScope` has initialized. Not worth the complexity.

### New Files

| File | Purpose |
|------|---------|
| `lib/core/services/biometric_service.dart` | Thin wrapper around `local_auth`. `Future<bool> authenticate(String reason)`. Handles `NotAvailable`, `PermanentlyDenied`, `NotEnrolled`. Exposes `Future<bool> isAvailable()`. |
| `lib/features/auth/providers/biometric_auth_provider.dart` | `AsyncNotifier<BiometricAuthState>`. `build()`: calls `biometricService.isAvailable()` → if false, emit `unavailable`. Otherwise emit `unauthenticated`. `authenticate()`: calls service, sets state to `authenticated` on success or keeps `unauthenticated` on failure with error message. |
| `lib/features/auth/models/biometric_auth_state.dart` | Sealed class or enum: `checking / authenticated / unauthenticated / unavailable`. If error message is needed: sealed class with `unauthenticated({String? error})`. |
| `lib/features/auth/screens/lock_screen.dart` | Full-screen widget. "Unlock" button triggers `biometricAuthProvider.notifier.authenticate()`. Shows error text on failure. No navigation — shown/hidden by parent Consumer. |

### Modified Files

| File | Change |
|------|--------|
| `lib/app.dart` | Wrap `MaterialApp.router` in `Consumer` watching `biometricAuthProvider`. Return `LockScreen` when `unauthenticated`, `CircularProgressIndicator` when `checking`, existing router when `authenticated` or `unavailable`. |
| `lib/features/machines/screens/add_edit_machine_screen.dart` | When `machineId != null`: watch `biometricAuthProvider`. If not `authenticated`: render a `Stack` with the form widgets (hidden or visible) and an overlay `LockScreen`-style widget on top. |

### Data Flow Change

```
Cold start:
  main() → ProviderScope → ClaudePilotApp
    biometricAuthProvider.build() → isAvailable() check
    unavailable → show router immediately
    unauthenticated → show LockScreen
    LockScreen.onUnlock → authenticate() → state = authenticated → Consumer rebuilds → router shown

Edit existing machine:
  /machines/:id/edit → AddEditMachineScreen(machineId: id)
    machineId != null → watch biometricAuthProvider
    not authenticated → show unlock overlay
    unlock success → state = authenticated → overlay hidden → form visible
```

### Integration Risks

- `biometricAuthProvider` state persists for the app session. Once authenticated at cold start, Gate B (edit screen) will not re-prompt unless the notifier is reset (e.g., on app background → foreground). This is correct default behavior but must be stated explicitly in requirements.
- `local_auth` requires `NSFaceIDUsageDescription` in iOS `Info.plist` and `USE_BIOMETRIC` permission in `AndroidManifest.xml`. These must be added before any `authenticate()` call or the OS will crash the app.
- On devices with no enrolled biometrics but biometric hardware present: `local_auth` returns `BiometricType` list as empty. The `isAvailable()` check should call `canCheckBiometrics` AND `getAvailableBiometrics()` — if the list is empty, treat as `unavailable` to avoid showing an unusable lock screen.

---

## Feature 4: Robust Reconnection

### Core Problem

Current `SshSession.build()` emits only `AsyncLoading` during all retry attempts and `AsyncError` after all fail. TerminalScreen shows only "Connecting…" for the entire retry window with no progress. Exponential backoff, more attempts, and visible retry progress require a richer state machine.

### State Machine: Sealed Class SshSessionState

Replace the return type `Future<Terminal>` with `Future<SshSessionState>`. This exposes intermediate states as `AsyncData(SshConnecting(...))` rather than keeping everything inside `AsyncLoading`.

```dart
// lib/features/terminal/models/ssh_session_state.dart  [NEW]
sealed class SshSessionState {
  const SshSessionState();
}

class SshConnecting extends SshSessionState {
  final int attempt;       // 1-indexed for display
  final int maxAttempts;
  const SshConnecting({required this.attempt, required this.maxAttempts});
}

class SshConnected extends SshSessionState {
  final Terminal terminal;
  const SshConnected(this.terminal);
}

class SshReconnecting extends SshSessionState {
  final int attempt;
  final int maxAttempts;
  final Duration nextRetryIn;
  const SshReconnecting({required this.attempt, required this.maxAttempts, required this.nextRetryIn});
}

class SshFailed extends SshSessionState {
  final Object error;
  const SshFailed(this.error);
}
```

`SshSession.build()` emits intermediate states via `state = AsyncData(SshConnecting(...))` before the async `return`. This is legal in Riverpod: setting `state` during `build()` replaces the `AsyncLoading` with a data value while the future is still running.

Exponential backoff: `Duration(seconds: (2 << attempt).clamp(1, 30))` — 2s, 4s, 8s, 16s, 30s, 30s... Increase `maxAttempts` from 3 to 8 (approximately 2 minutes total retry window).

Mid-session reconnect: when `_client.done.catchError` fires (network drop while connected), instead of immediately setting `state = AsyncError(...)`, call an internal `_reconnect()` method that runs the same retry loop and emits `SshReconnecting` states.

### New Files

| File | Purpose |
|------|---------|
| `lib/features/terminal/models/ssh_session_state.dart` | Sealed class `SshSessionState` with `SshConnecting`, `SshConnected`, `SshReconnecting`, `SshFailed` subtypes |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/terminal/providers/ssh_session_provider.dart` | (1) Change return type `Future<Terminal>` → `Future<SshSessionState>`. (2) Emit `state = AsyncData(SshConnecting(attempt: attempt+1, maxAttempts: maxAttempts))` at each loop iteration. (3) `_connectOnce` returns `SshConnected(terminal)` instead of `terminal`. (4) Implement exponential backoff delay. (5) Update `maxAttempts` to 8. (6) `_client.done.catchError`: emit `SshReconnecting(...)` and kick off `_reconnect()` loop instead of going directly to `AsyncError`. |
| `lib/features/terminal/screens/terminal_screen.dart` | (1) `sessionAsync.when(data: (terminal) => ...)` becomes `sessionAsync.when(data: (sshState) => switch(sshState) { SshConnected(:final terminal) => TerminalViewWrapper(...), SshConnecting s => _buildConnecting(s), SshReconnecting s => _buildReconnecting(s), SshFailed s => _buildFailed(s) })`. (2) The `isLoading` check for `_ConnectingDot` must also check `sessionAsync.value is SshConnecting || sessionAsync.value is SshReconnecting`. (3) Error dialog logic moves into `_buildFailed` or the `ref.listen` branch for `SshFailed`. (4) `SshSession.maxAttempts` string reference in dialog text updates to new value (or reads the const directly). |
| `lib/features/terminal/providers/permission_detector_provider.dart` | Change `data: (_) => ...` to `data: (sshState) => sshState is SshConnected ? notifier.permissionStream.map(_detect) : const Stream.empty()`. |

### Data Flow Change

```
Before:
  build() → [AsyncLoading for all attempts] → AsyncError OR AsyncData(terminal)

After:
  build()
    emit AsyncData(SshConnecting(attempt: 1, maxAttempts: 8))
    try _connectOnce → success → emit nothing, return AsyncData(SshConnected(terminal))
    fail → delay 2s
    emit AsyncData(SshConnecting(attempt: 2, maxAttempts: 8))
    try _connectOnce → ... (up to 8)
    all fail → return AsyncData(SshFailed(error))   OR AsyncError (either works)

  mid-session drop:
    _client.done.catchError fires
    emit AsyncData(SshReconnecting(attempt: 1, maxAttempts: 8, nextRetryIn: 2s))
    _reconnect() loop runs (same as above)
    success → emit AsyncData(SshConnected(terminal))  [terminal object reused or new]
```

### Integration Risks

This is the highest-risk change. It is a **breaking type change** on `sshSessionProvider`. Every consumer must be updated:

| Consumer | Change Required |
|----------|----------------|
| `terminal_screen.dart` | `.when(data: (terminal))` → switch on `SshSessionState` |
| `permission_detector_provider.dart` | Guard `data:` branch on `is SshConnected` |
| `input_bar.dart` | Calls `sshSessionProvider(id).hasValue` for `isConnected` — this returns true even during `SshConnecting/SshReconnecting` (because state is `AsyncData`). Fix: `isConnected = sessionAsync.value is SshConnected`. |
| Any future tab UI watching session state | Must pattern-match union |

The `_ConnectingDot` widget uses `sessionAsync.isLoading` which will now be false during `SshConnecting`/`SshReconnecting` (state is `AsyncData`). This must be fixed or the connecting animation disappears during retries. See modified `terminal_screen.dart` notes above.

`PermissionCard` and `InputBar` access `sshSessionProvider(id).notifier` directly to call `.sendText()` / `.sendBytes()` — these do not depend on the state type and require no change.

---

## Build Order and Dependencies

### Dependency Graph

```
Feature 4 (Reconnection)
  modifies SshSession return type Terminal → SshSessionState
  breaks: terminal_screen.dart, permission_detector_provider.dart, input_bar.dart
  must be done before Feature 1 (TabShell also consumes sshSessionProvider)

Feature 2 (Session Start Picker)
  adds workingFolders to Machine model (pure model extension)
  adds a new screen + route
  independent of Features 3 and 4

Feature 3 (Biometric)
  adds BiometricAuthNotifier + LockScreen
  touches app.dart (wrapper) and add_edit_machine_screen.dart
  independent of Features 2 and 4
  touches app.dart — must be sequenced with Feature 1 (both touch app.dart)

Feature 1 (Tabs)
  depends on Feature 4 (stable SshSessionState type before building tab consumer)
  rewrites app.dart navigation (ShellRoute)
  should be last to incorporate app.dart changes from Feature 2 (new route) and Feature 3 (wrapper)
```

### Recommended Build Order

**Phase A — Foundation (must be sequential, done first):**
1. **Feature 4: Robust Reconnection** — changes the core session type. All three downstream consumers (TerminalScreen, PermissionDetector, InputBar) are updated in this same phase. After Phase A, the codebase is stable on `SshSessionState`.

**Phase B — Independent extensions (can be done in either order, do not block each other):**
2. **Feature 2: Session Start Picker** — Machine model extension + new screen + route in app.dart. No session type involvement.
3. **Feature 3: Biometric Lock** — New providers + LockScreen + app.dart wrapper + AddEditMachineScreen gate. No session type involvement.

**Phase C — Integration (must come after A and B):**
4. **Feature 1: Multi-Session Tabs** — Adds ShellRoute to app.dart (which already has Feature 2's route and Feature 3's wrapper from Phase B). Adds `TabsNotifier` with `keepAlive` management against the `SshSessionState` type from Phase A.

**Rationale:** Feature 4 is the riskiest because it changes a type consumed by three providers/widgets. Doing it first means all subsequent features build against the stable union type. Doing it last would require a second migration pass across everything already built.

Features 2 and 3 both touch `app.dart` but non-overlappingly: Feature 2 adds one route, Feature 3 adds a widget wrapper. These compose without conflict but must be merged carefully when Feature 1 restructures app.dart for ShellRoute.

---

## Summary: New vs Modified Files Per Feature

### Feature 4 (Reconnection) — Do First

New:
- `lib/features/terminal/models/ssh_session_state.dart`

Modified:
- `lib/features/terminal/providers/ssh_session_provider.dart` (return type, retry loop, backoff, mid-session reconnect)
- `lib/features/terminal/screens/terminal_screen.dart` (switch on SshSessionState, dot animation fix, error dialog)
- `lib/features/terminal/providers/permission_detector_provider.dart` (guard data branch on SshConnected)
- `lib/features/terminal/widgets/input_bar.dart` (fix `isConnected` check from `hasValue` to `value is SshConnected`)

### Feature 2 (Session Start Picker)

New:
- `lib/features/session_start/screens/session_start_screen.dart`
- `lib/features/session_start/widgets/folder_list_tile.dart`

Modified:
- `lib/core/models/machine.dart` (add workingFolders field, update fromJson/toJson/copyWith/generate)
- `lib/features/machines/screens/add_edit_machine_screen.dart` (add folder bookmarks UI section)
- `lib/app.dart` (add `/machines/:id/start-picker` route)
- `lib/features/machines/screens/machine_list_screen.dart` (onTap navigates to start-picker)

### Feature 3 (Biometric Lock)

New:
- `lib/core/services/biometric_service.dart`
- `lib/features/auth/providers/biometric_auth_provider.dart`
- `lib/features/auth/models/biometric_auth_state.dart`
- `lib/features/auth/screens/lock_screen.dart`

Modified:
- `lib/app.dart` (Consumer wrapper around MaterialApp.router)
- `lib/features/machines/screens/add_edit_machine_screen.dart` (overlay gate in edit mode)

### Feature 1 (Tabs) — Do Last

New:
- `lib/features/tabs/providers/tabs_notifier.dart`
- `lib/features/tabs/models/tabs_state.dart`
- `lib/features/tabs/widgets/tab_shell.dart`
- `lib/features/tabs/widgets/tab_bar_strip.dart`

Modified:
- `lib/app.dart` (ShellRoute restructure, new `/terminal/:id` route, remove old `/machines/:id/terminal`)
- `lib/features/machines/screens/machine_list_screen.dart` (onTap calls tabsNotifier.openTab + go)
- `lib/features/terminal/providers/ssh_session_provider.dart` (TabsNotifier calls keepAlive on the provider — may require exposing a method or using provider internals)

---

## Sources

- Direct codebase inspection: `app.dart`, `machine.dart`, `machine_repository.dart`, `ssh_session_provider.dart`, `machines_provider.dart`, `terminal_screen.dart`, `permission_detector_provider.dart`, `input_bar.dart`, `machine_list_screen.dart`, `main.dart` — HIGH confidence
- Riverpod `ref.keepAlive()` / `KeepAliveLink` pattern: HIGH confidence (Riverpod 3.x docs, autoDispose + keepAlive is a first-class API)
- GoRouter `ShellRoute` for persistent shell widget: HIGH confidence (go_router official docs)
- Dart 3 sealed classes for state machines: HIGH confidence (Dart language spec, no library required)
- `local_auth` biometric gate pattern: MEDIUM confidence (verify API surface for current local_auth 2.x before implementation — specifically `canCheckBiometrics` vs `isDeviceSupported` distinction)
- Setting `state` during `build()` in Riverpod AsyncNotifier for intermediate states: MEDIUM confidence (pattern is documented but verify with Riverpod 3.x that AsyncData intermediate state during a pending build future behaves as expected)
