---
phase: 07-sesiones-m-ltiples-con-tabs
reviewed: 2026-06-20T22:00:00Z
depth: deep
files_reviewed: 9
files_reviewed_list:
  - lib/features/sessions/models/session_tab.dart
  - lib/features/sessions/providers/sessions_provider.dart
  - lib/features/sessions/providers/sessions_provider.g.dart
  - lib/features/terminal/providers/ssh_session_provider.dart
  - lib/features/sessions/screens/sessions_screen.dart
  - lib/features/sessions/widgets/machine_selection_sheet.dart
  - lib/features/terminal/screens/terminal_screen.dart
  - lib/app.dart
  - lib/features/machines/screens/machine_list_screen.dart
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-06-20T22:00:00Z
**Depth:** deep
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 07 adds multi-tab SSH sessions: a `SessionsNotifier` (keepAlive:true) managing a list of `SessionTab` entries, a `SessionsScreen` hosting an `IndexedStack` of `TerminalScreen` widgets, and lifecycle glue (`ref.keepAlive` / `closeAndDispose`) to prevent autoDispose during tab switches.

The provider layer is structurally sound — `ref.keepAlive()` is called before any `await`, `onDispose` is registered immediately after, and `closeAndDispose()` tears down in the documented order. The generated file confirms `isAutoDispose: false` for `sessionsProvider`.

Two blocking bugs were found. First, the "Reconnected" SnackBar is missing its `isActive` gate, causing a spurious pop-up every time a background tab reconnects (directly contradicts the documented SESS-04 isolation contract). Second, opening two tabs for the same machine maps both to the same `sshSessionProvider(machineId)` family entry; closing either tab calls `closeAndDispose()` on the shared provider, silently terminating the other tab's SSH connection.

Three warnings cover: a double-close of `_client`/`_sshSession` in `closeAndDispose` vs. `onDispose`, `_closeTab` reading stale pre-mutation state when deciding to navigate, and `_ConnectingDot` being dead code after the AppBar was removed.

---

## Critical Issues

### CR-01: "Reconnected" SnackBar not gated by `isActive` — fires for background tabs

**File:** `lib/features/terminal/screens/terminal_screen.dart:65`

**Issue:** The `SshFailed` SnackBar is correctly gated by `widget.isActive` (line 74). The "Reconnected" SnackBar is not gated at all. When a background tab's SSH session completes its mid-session retry loop, the listener fires `ScaffoldMessenger.of(context).showSnackBar(...)` unconditionally, popping an intrusive notification while the user is watching a different tab. This directly violates the SESS-04 isolation contract documented in the phase plan: "Verify NO SnackBar appears while viewing machine A's tab."

```dart
// CURRENT — missing isActive gate
if (prevState is SshReconnecting && nextState is SshConnected) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Reconnected'),
      duration: Duration(seconds: 2),
    ),
  );
}

// FIX — add isActive guard
if (widget.isActive && prevState is SshReconnecting && nextState is SshConnected) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Reconnected'),
      duration: Duration(seconds: 2),
    ),
  );
}
```

---

### CR-02: Two tabs for the same machine share one `sshSessionProvider` entry — closing either tab kills the session for both

**File:** `lib/features/sessions/providers/sessions_provider.dart:27`

**Issue:** `sshSessionProvider` is a family provider keyed by `machineId` (a `String`). Two `SessionTab`s for the same machine produce distinct `tab.id` values but identical `machineId` values. Both the `_TabChip` (line 263 of `sessions_screen.dart`) and `TerminalScreen` watch `sshSessionProvider(tab.machineId)` — meaning they both watch the **same** provider instance. When the user closes either tab, `closeTab` calls:

```dart
ref.read(sshSessionProvider(tab.machineId).notifier).closeAndDispose();
```

This tears down the single shared SSH connection, leaving the sibling tab displaying a dead terminal with no error indication.

The problem is architectural: the provider family key must distinguish tabs, not just machines. The fix is to key `sshSessionProvider` by `tab.id` (the unique-per-open-event identifier) instead of `tab.machineId`.

**Fix (sketch):**
```dart
// 1. Change sshSessionProvider family arg from machineId to tabId.
//    In SshSession.build(), accept `tabId` and resolve machineId via
//    a separate lookup (e.g., pass both, or store machine data in SessionTab).

// 2. In SessionTab, retain both id and machineId.
// 3. Everywhere sshSessionProvider(tab.machineId) is called,
//    replace with sshSessionProvider(tab.id).
// 4. SshSession.build() uses the machineId sourced from SessionsState
//    (ref.read(sessionsProvider).tabs.firstWhere(t => t.id == tabId)).
```

Note: if the design intent is to intentionally allow only one SSH session per machine (i.e., opening the same machine twice is forbidden), then `openTab` must guard against duplicate `machineId` values. Currently there is no such guard, so the bug manifests silently.

---

## Warnings

### WR-01: Double-close of `_client` / `_sshSession` in `closeAndDispose` then `onDispose`

**File:** `lib/features/terminal/providers/ssh_session_provider.dart:411`

**Issue:** `closeAndDispose()` closes `_sshSession` and `_client` (lines 413–414), then calls `_releaseKeepAlive?.call()` which eventually triggers Riverpod's `onDispose` callback. That callback (lines 96–97) calls `_sshSession?.close()` and `_client?.close()` again. While dartssh2's `close()` is likely idempotent, the pattern relies on an undocumented implementation detail of the library. The fields are not nulled out before `_releaseKeepAlive` is called, so there is no sentinel preventing the second close.

**Fix:** Null the fields in `closeAndDispose()` before releasing keepAlive so `onDispose` finds them nil:
```dart
void closeAndDispose() {
  cancel();
  _sshSession?.close();
  _sshSession = null;
  _client?.close();
  _client = null;
  _releaseKeepAlive?.call();
  _releaseKeepAlive = null;
}
```

---

### WR-02: `_closeTab` reads stale `sessions` state — last-tab check may be wrong

**File:** `lib/features/sessions/screens/sessions_screen.dart:187`

**Issue:** `_closeTab` captures `sessions` with `ref.read(sessionsProvider)` (line 188), then immediately calls `closeTab(index)` (line 189) which mutates the state. The length check on line 191 (`sessions.tabs.length == 1`) uses the **pre-mutation** snapshot. If the state has changed between the read and the close (unlikely in practice but possible under fast UI interactions), the navigation decision could be wrong — specifically, it could fail to navigate when the last tab is closed, leaving the user on an empty sessions screen with no back gesture (because `PopScope(canPop: false)` prevents escape).

**Fix:** Read the count before calling `closeTab`, which is already done correctly; the read is synchronous and the mutation is also synchronous, so the snapshot is valid **in the current single-threaded Dart event loop execution**. The actual risk is subtle: `sessionsProvider` is `keepAlive: true` and `Notifier<>`, so mutations are synchronous and the snapshot is reliable here. The real issue is readability — using the post-mutation state from `ref.read` would be clearer:

```dart
void _closeTab(BuildContext context, int index) {
  final wasLastTab = ref.read(sessionsProvider).tabs.length == 1;
  ref.read(sessionsProvider.notifier).closeTab(index);
  if (wasLastTab) {
    context.go('/machines');
  }
}
```

This eliminates ambiguity about which snapshot is being interrogated.

---

### WR-03: `_ConnectingDot` is dead code in `terminal_screen.dart`

**File:** `lib/features/terminal/screens/terminal_screen.dart:239`

**Issue:** `_ConnectingDot` was the animated dot widget used in the terminal AppBar when the screen had its own AppBar. The AppBar was removed in Phase 07. The class comment on line 238 says "_ConnectingDot is retained for use by sessions_screen.dart's _PulsingDot" but `sessions_screen.dart` defines its own `_PulsingDot` independently and does not import or reference `_ConnectingDot`. `_ConnectingDot` is never instantiated anywhere in the codebase. It holds a live `AnimationController` in its state — dead widget classes with stateful animations are a minor resource concern if Flutter ever accidentally instantiates them, and they add maintenance burden.

**Fix:** Delete `_ConnectingDot` and `_ConnectingDotState` (lines 239–284). If a shared pulsing dot is desired, extract `_PulsingDot` from `sessions_screen.dart` to a shared `lib/core/widgets/` location.

---

## Info

### IN-01: `openTab` allows unlimited duplicate tabs for the same machine with no user feedback

**File:** `lib/features/sessions/providers/sessions_provider.dart:13`

**Issue:** Nothing prevents the user from opening five tabs to the same machine. Even if CR-02 is fixed by keying `sshSessionProvider` per `tab.id`, five simultaneous SSH sessions to one host is almost certainly unintentional and could exhaust SSH server connection limits. The SUMMARY notes "No hard cap on tabs" as an accepted threat (T-07-05), but per-machine duplicate protection is not mentioned.

**Fix (optional):** Add a guard in `openTab` or disable the machine row in `MachineSelectionSheet` when a session for that machine already exists. At minimum, document the per-machine duplicate behavior as an explicit design decision in the provider comment.

---

### IN-02: `newMachineId` query parameter route in `app.dart` is dead code (alternate navigation pattern was adopted)

**File:** `lib/app.dart:33`

**Issue:** The `/sessions` route reads `state.uri.queryParameters['newMachineId']` and passes it as `initialMachineId` to `SessionsScreen`. However, the SUMMARY for plan 07-02 documents that the "alternative navigation pattern" was chosen: `MachineListScreen` calls `openTab()` directly then `context.push('/sessions')` **without any query parameter**. As a result `newMachineId` is always `null` in production, `SessionsScreen.initialMachineId` is always `null`, and the `didUpdateWidget` + `_lastInitialMachineId` guard mechanism in `SessionsScreen` is similarly dead code. The tab is opened before navigation, so `SessionsScreen.initState` finds `sessionsProvider` already has the tab — the `initialMachineId`-triggered `openTab` call would create a duplicate.

This is currently harmless because `initialMachineId` is always null, but it is confusing: the query-param wiring in `app.dart` and the `initialMachineId` parameter and its guard logic in `sessions_screen.dart` appear functional but are never exercised. If a future developer passes `newMachineId` they will get a duplicate tab.

**Fix:** Either remove the `newMachineId` query-param support from `app.dart` and remove `initialMachineId` + its guard from `SessionsScreen` (keeping the code clean), or remove the direct `openTab()` call from `MachineListScreen` and use the query-param path exclusively. Do not maintain both wiring paths.

---

_Reviewed: 2026-06-20T22:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
