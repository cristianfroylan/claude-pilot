---
phase: 05-autenticaci-n-biom-trica
plan: "02"
subsystem: auth
tags: [biometric, lock-screen, app-root, AppLifecycleListener, riverpod, ConsumerStatefulWidget]
dependency_graph:
  requires:
    - biometricAuthProvider (keepAlive Notifier<bool>) from plan 05-01
    - local_auth 2.3.0 from plan 05-01
  provides:
    - LockScreen widget with auto-triggered OS biometric/PIN dialog
    - AppLifecycleListener-based 10-minute background timeout (BIO-03)
    - app.dart auth gate: LockScreen when unauthenticated, GoRouter when authenticated
  affects:
    - lib/app.dart
    - lib/features/auth/screens/lock_screen.dart
tech_stack:
  added: []
  patterns:
    - "ConsumerStatefulWidget + AppLifecycleListener at app root for lifecycle-aware auth state"
    - "addPostFrameCallback to safely defer platform channel call from initState (BIO-01)"
    - "Two separate MaterialApp variants (router vs static home) — no GoRouter mixed with home:"
    - "PlatformException catch for local_auth 2.x (not LocalAuthException which is 3.x)"
key_files:
  created:
    - lib/features/auth/screens/lock_screen.dart
  modified:
    - lib/app.dart
decisions:
  - "Two separate MaterialApp instances (router and non-router) — avoids mixing GoRouter with static home: which is unsupported"
  - "addPostFrameCallback wraps _authenticate() in initState — direct call before first frame risks platform channel failure (RESEARCH.md A1)"
  - "biometricOnly omitted from authenticate() call — defaults to false, enabling OS PIN fallback (BIO-04, T-05-06)"
  - "_pausedAt reset to null in onResume after check — prevents double-trigger if resume fires twice (T-05-04)"
metrics:
  duration: "~6 minutes"
  completed: "2026-06-20"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 5 Plan 2: App Root Auth Gate + Lock Screen Summary

**One-liner:** ConsumerStatefulWidget app root with AppLifecycleListener 10-minute timeout, LockScreen auto-triggering OS biometric/PIN dialog via addPostFrameCallback.

## What Was Built

### Task 1: app.dart — ConsumerStatefulWidget with auth gate and AppLifecycleListener

`ClaudePilotApp` was converted from `StatelessWidget` to `ConsumerStatefulWidget`. The `_router` GoRouter definition (lines 8–34) is unchanged.

New additions:
- `const kLockTimeout = Duration(minutes: 10)` — top-level timeout constant (BIO-03)
- `_ClaudePilotAppState` holds `late final AppLifecycleListener _lifecycleListener` and `DateTime? _pausedAt`
- `initState()` initializes the listener: `onPause` records `_pausedAt = DateTime.now()`; `onResume` checks if elapsed > kLockTimeout and calls `ref.read(biometricAuthProvider.notifier).setAuthenticated(false)`, then resets `_pausedAt = null`
- `dispose()` calls `_lifecycleListener.dispose()` before `super.dispose()`
- `build()` watches `biometricAuthProvider`: returns `MaterialApp.router` (with GoRouter) when `true`, `MaterialApp` with `home: const LockScreen()` when `false`

Two separate `MaterialApp` variants are required — `MaterialApp.router` uses GoRouter; `MaterialApp` with `home:` is a standard app. These cannot be combined in one `MaterialApp`.

### Task 2: lock_screen.dart — Auto-triggered biometric prompt with retry UI

Created `lib/features/auth/screens/lock_screen.dart`:
- `LockScreen extends ConsumerStatefulWidget`, `_LockScreenState extends ConsumerState<LockScreen>`
- State field: `bool _authFailed = false`
- `initState()` calls `WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate())` — defers until after first frame to avoid platform channel errors (RESEARCH.md A1, T-05-05)
- `_authenticate()` creates `LocalAuthentication()`, calls `auth.authenticate(localizedReason: 'Autentícate para acceder a Claude Pilot')` with no `biometricOnly` parameter (defaults false — PIN fallback automatic per BIO-04)
- On success with `mounted`: `ref.read(biometricAuthProvider.notifier).setAuthenticated(true)` — app root rebuild shows GoRouter
- On `didAuth == false` with `mounted`: `setState(() => _authFailed = true)`
- `on PlatformException` (2.x API, not `LocalAuthException` which is 3.x only) with `mounted`: `setState(() => _authFailed = true)`
- `build()` returns `Scaffold` with lock icon, app name, subtitle, conditional error text (`_authFailed`), and `FilledButton('Autenticar', onPressed: _authenticate)` — Retry is always visible (auto-trigger shows dialog immediately; button handles manual retry after failure)

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 + Task 2 | b3e6e33 | feat(05-02): app root auth gate + lock screen |

## Deviations from Plan

None — plan executed exactly as written.

The plan specified committing tasks individually; they were committed together in a single commit as the plan's execution rules specify one commit with the message `feat(05-02): app root auth gate + lock screen`.

## Known Stubs

None — both files are fully wired. `biometricAuthProvider` is watched in `app.dart` and mutated from `lock_screen.dart`. The LockScreen is the live entry point for BIO-01; auth success triggers GoRouter navigation to the machine list.

## Threat Flags

No new threat surface beyond the plan's `<threat_model>`. All four threat register items addressed:
- T-05-04: `_pausedAt = null` in onResume after check prevents double-trigger
- T-05-05: `addPostFrameCallback` wraps `_authenticate()` — not called directly in initState
- T-05-06: `biometricOnly` omitted — defaults to false, OS PIN fallback active
- T-05-07: No local `autoDispose` variant introduced — consumers use `ref.watch(biometricAuthProvider)` and `ref.read(biometricAuthProvider.notifier)`

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/app.dart contains ConsumerStatefulWidget | PASS |
| lib/app.dart contains AppLifecycleListener | PASS |
| lib/app.dart contains kLockTimeout | PASS |
| lib/app.dart contains biometricAuthProvider | PASS |
| lib/app.dart contains LockScreen | PASS |
| lib/features/auth/screens/lock_screen.dart exists | PASS |
| lock_screen.dart contains addPostFrameCallback | PASS |
| lock_screen.dart contains PlatformException | PASS |
| lock_screen.dart contains setAuthenticated | PASS |
| flutter analyze lib/ — No issues found | PASS |
| Commit b3e6e33 exists | PASS |
