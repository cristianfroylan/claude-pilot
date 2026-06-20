# Phase 5: Autenticación Biométrica - Context

**Gathered:** 2026-06-20
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase adds device-level biometric/PIN authentication as a gate to the app. Two lock points: (1) cold launch — user must authenticate before reaching the machine list; (2) credential editing — user must re-authenticate before editing or deleting a saved machine. Background timeout: app re-locks after 10 minutes in background.

Out of scope: per-session SSH auth, custom PIN UI, notification-based lock, remote wipe.

</domain>

<decisions>
## Implementation Decisions

### Auth Library & Lock Trigger
- Package: `local_auth: ^2.3.0` (official Flutter team, handles Face ID / fingerprint / PIN fallback automatically via OS — BIO-04 is free)
- Auth state lives in `biometricAuthProvider` — `@Riverpod(keepAlive: true)` with `bool isAuthenticated` field; `keepAlive: true` prevents accidental reset during navigation transitions (locked decision from STATE.md research)
- Background timeout detection: `AppLifecycleListener` in `app.dart` — records `DateTime? _pausedAt` on `paused`, compares on `resumed`; if diff > `kLockTimeout` set `isAuthenticated = false`
- Timeout constant: `kLockTimeout = const Duration(minutes: 10)` — per BIO-03

### Lock Screen UI
- App root (`app.dart`) wraps router in a conditional: if `!isAuthenticated` → show `LockScreen` widget; if `isAuthenticated` → show the GoRouter `MaterialApp.router` normally
- `LockScreen` is minimal: app logo/name, button "Authenticate", subtitle with biometric/PIN hint
- `LockScreen.initState` auto-triggers `authenticate()` immediately on build (Face ID activates automatically like the native iOS pattern) — no tap required
- On auth failure: show `Text('Authentication required')` + "Retry" button — OS already provides error feedback, no custom error dialog needed

### Edit Gate
- `requireBiometric(BuildContext context, WidgetRef ref)` — async utility function called in `machine_list_screen.dart` on edit/delete tap, BEFORE navigating to `add_edit_machine_screen.dart`; if auth fails, navigation is cancelled
- Called at the callsite (list screen), not inside `add_edit_machine_screen.dart` — user never sees the edit form without auth
- Confirmation for delete also gated the same way

### Android minSdk
- Raise `minSdk` from 23 to 24 in `android/app/build.gradle` — `local_auth` requires API 24+ (Android 7.0); already a locked decision from STATE.md v2.0 research

### Claude's Discretion
- Exact lock screen layout/styling consistent with existing `AppTheme` — no new design tokens
- Whether `biometricAuthProvider` is an `AsyncNotifier` or a simple `Notifier<bool>` — prefer `Notifier<bool>` since auth is synchronous-result (no loading state needed)
- `local_auth` `authenticateOptions` strings (localizedReason) — use Spanish to match app language

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app.dart` (`lib/app.dart`) — current app root with GoRouter; wrap its `MaterialApp.router` in the auth conditional here
- `machine_list_screen.dart` — existing edit/delete taps are the callsites for `requireBiometric`
- `AppTheme` (`lib/core/theme/app_theme.dart`) — use existing tokens for LockScreen styling

### Established Patterns
- Riverpod `@Riverpod(keepAlive: true)` pattern for long-lived state — same as how `machinesProvider` persists across routes
- `ref.read(provider.notifier).methodName()` — mutation pattern used throughout
- No existing auth code — this is greenfield

### Integration Points
- `app.dart` — add `AppLifecycleListener` + auth conditional around router
- `machine_list_screen.dart` — gate edit/delete taps with `requireBiometric`
- `android/app/build.gradle` — raise minSdk to 24
- `pubspec.yaml` — add `local_auth: ^2.3.0`
- `ios/Runner/Info.plist` — add `NSFaceIDUsageDescription` (required by App Store)

</code_context>

<specifics>
## Specific Ideas

- From STATE.md: "biometricAuthProvider is keepAlive: true — autoDispose silently resets auth state during navigation transitions" — locked
- From STATE.md: "minSdk raised from 23 to 24 for local_auth biometric requirement" — locked
- BIO-04: "En dispositivos sin biométrico disponible, el PIN/contraseña del dispositivo funciona como fallback automático (manejado por el OS, sin código extra)" — this is automatic with `local_auth`, no extra code path needed
- From STATE.md research: "Confirm local_auth 3.0.1 uses `persistAcrossBackgrounding` (not legacy `stickyAuth`) before Phase 5 implementation" — researcher must verify this

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
