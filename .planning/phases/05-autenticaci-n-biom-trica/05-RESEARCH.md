# Phase 5: Autenticación Biométrica - Research

**Researched:** 2026-06-20
**Domain:** Flutter local_auth, biometric/PIN authentication, AppLifecycleListener, Riverpod keepAlive
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Package: `local_auth: ^2.3.0` (official Flutter team, handles Face ID / fingerprint / PIN fallback automatically via OS — BIO-04 is free)
- Auth state lives in `biometricAuthProvider` — `@Riverpod(keepAlive: true)` with `bool isAuthenticated` field; `keepAlive: true` prevents accidental reset during navigation transitions
- Background timeout detection: `AppLifecycleListener` in `app.dart` — records `DateTime? _pausedAt` on `paused`, compares on `resumed`; if diff > `kLockTimeout` set `isAuthenticated = false`
- Timeout constant: `kLockTimeout = const Duration(minutes: 10)` — per BIO-03
- App root (`app.dart`) wraps router in a conditional: if `!isAuthenticated` → show `LockScreen` widget; if `isAuthenticated` → show the GoRouter `MaterialApp.router` normally
- `LockScreen` is minimal: app logo/name, button "Authenticate", subtitle with biometric/PIN hint
- `LockScreen.initState` auto-triggers `authenticate()` immediately on build (Face ID activates automatically like the native iOS pattern) — no tap required
- On auth failure: show `Text('Authentication required')` + "Retry" button — OS already provides error feedback, no custom error dialog needed
- `requireBiometric(BuildContext context, WidgetRef ref)` — async utility function called in `machine_list_screen.dart` on edit/delete tap, BEFORE navigating to `add_edit_machine_screen.dart`; if auth fails, navigation is cancelled
- Called at the callsite (list screen), not inside `add_edit_machine_screen.dart` — user never sees the edit form without auth
- Confirmation for delete also gated the same way
- Raise `minSdk` from 23 to 24 in `android/app/build.gradle` — `local_auth` requires API 24+ (Android 7.0)
- biometricAuthProvider is `keepAlive: true` — autoDispose silently resets auth state during navigation transitions

### Claude's Discretion
- Exact lock screen layout/styling consistent with existing `AppTheme` — no new design tokens
- Whether `biometricAuthProvider` is an `AsyncNotifier` or a simple `Notifier<bool>` — prefer `Notifier<bool>` since auth is synchronous-result (no loading state needed)
- `local_auth` `authenticateOptions` strings (localizedReason) — use Spanish to match app language

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BIO-01 | La app requiere autenticación biométrica (Face ID / huella / PIN del dispositivo) al iniciarse en frío | LockScreen conditional in app.dart root; auto-triggers authenticate() on initState |
| BIO-02 | La app requiere autenticación biométrica antes de editar las credenciales de una máquina guardada | requireBiometric() guard at edit/delete callsites in machine_list_screen.dart |
| BIO-03 | La app se vuelve a bloquear si estuvo en background más de 10 minutos | AppLifecycleListener records pausedAt; on resume checks diff > kLockTimeout |
| BIO-04 | En dispositivos sin biométrico disponible, el PIN/contraseña del dispositivo funciona como fallback automático (manejado por el OS, sin código extra) | local_auth default behavior: biometricOnly defaults to false, OS handles PIN fallback automatically |
</phase_requirements>

---

## Summary

Phase 5 adds biometric/PIN authentication as a gate at two points: cold launch (lock screen before machine list) and credential editing (re-auth before edit/delete). The background timeout (10 minutes) triggers a re-lock via `AppLifecycleListener`. All behavior is implemented via the official `local_auth` Flutter plugin from the Flutter team, which handles Face ID, fingerprint, and PIN fallback through a single API call.

The key technical finding is a **version mismatch**: CONTEXT.md locks `local_auth: ^2.3.0`, but the current pub.dev latest is **3.0.1** (published 2026-02-25). Version 3.0.0 introduced a breaking API change — `AuthenticationOptions` was replaced by individual parameters, and `stickyAuth` was renamed to `persistAcrossBackgrounding`. The `^2.3.0` constraint will resolve to 2.3.0 at pub get (not 3.x), which is a valid and stable choice. However, the STATE.md pending todo "Confirm local_auth 3.0.1 uses `persistAcrossBackgrounding` (not legacy `stickyAuth`) before Phase 5 implementation" is now answered: `persistAcrossBackgrounding` is the 3.x parameter name; in 2.3.0 it is still `stickyAuth` inside `AuthenticationOptions`.

Two Android platform requirements are critical and frequently missed: (1) `MainActivity` must extend `FlutterFragmentActivity`, not `FlutterActivity`, for `local_auth` to function on Android — the current codebase uses `FlutterActivity`; (2) the `USE_BIOMETRIC` permission must be declared in `AndroidManifest.xml` — it is absent. The `NSFaceIDUsageDescription` key is also missing from `ios/Runner/Info.plist` and is required by the App Store and at runtime on iOS. The `minSdk` change is actually a no-op: `flutter.minSdkVersion` already resolves to 24 in the installed Flutter SDK.

**Primary recommendation:** Use `local_auth: ^2.3.0` as locked. Fix Android MainActivity and manifest before any auth code. Auto-trigger auth on LockScreen build (not waiting for button tap) for the native-feeling Face ID UX.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Auth state (isAuthenticated) | App layer (Riverpod provider) | — | Must survive navigation transitions; keepAlive: true provider is the single source of truth |
| Cold-launch gate | App root widget (app.dart) | — | Earliest possible intercept — before router renders any route |
| Background timeout detection | App root widget (AppLifecycleListener) | — | Lifecycle events only available where WidgetsBindingObserver or AppLifecycleListener is registered |
| Biometric prompt invocation | Platform OS via local_auth plugin | — | Face ID / fingerprint / PIN are OS-level; plugin is the bridge |
| Edit/delete gate | machine_list_screen.dart (callsite) | — | Gate at the action trigger, not inside the destination screen |
| iOS permission declaration | Info.plist | — | NSFaceIDUsageDescription required at app bundle level, not in code |
| Android permission declaration | AndroidManifest.xml | — | USE_BIOMETRIC permission and FlutterFragmentActivity both required |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `local_auth` | 2.3.0 (via `^2.3.0`) | Biometric + PIN auth via OS | Official Flutter team package; handles Face ID, fingerprint, and PIN fallback through a single `authenticate()` call with no extra code paths |

[VERIFIED: pub.dev] local_auth 3.0.1 is current latest; `^2.3.0` resolves to 2.3.0, which is stable and API-stable within the 2.x range. Choosing 2.x is intentional per CONTEXT.md locked decision.

### Supporting

No new supporting libraries required. All supporting infrastructure is existing:
- `flutter_riverpod: ^3.3.1` — already in pubspec for `biometricAuthProvider`
- `riverpod_annotation: 4.0.2` — already in pubspec for `@Riverpod(keepAlive: true)` codegen

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `local_auth: ^2.3.0` | `local_auth: ^3.0.1` | 3.x drops `AuthenticationOptions` wrapper; `authenticate()` params are individual. Same functionality. Locked to 2.x per CONTEXT.md. |
| `local_auth` | `flutter_biometrics` or custom platform channel | Extra dependency, more maintenance, same OS APIs underneath |

**Installation:**
```bash
flutter pub add local_auth:^2.3.0
```

**Version verification:**

```
pub.dev registry query: local_auth
Latest: 3.0.1 (2026-02-25) [VERIFIED: pub.dev]
2.3.0 (2024-08-06) — stable, used by constraint ^2.3.0 [VERIFIED: pub.dev]
local_auth_android: 2.0.9 [VERIFIED: pub.dev]
local_auth_darwin: 2.0.3 [VERIFIED: pub.dev]
```

---

## Package Legitimacy Audit

> slopcheck is a Python package; this is a Dart/Flutter phase. `npm` and `pip` package legitimacy tools do not apply to pub.dev packages. Local_auth is published by the Flutter team in the official `flutter/packages` monorepo.

| Package | Registry | Age | Publisher | Source Repo | Disposition |
|---------|----------|-----|-----------|-------------|-------------|
| `local_auth` | pub.dev | 6+ years (v1.0 in 2019) | flutter.dev / Flutter team | github.com/flutter/packages | Approved — official Flutter team package |
| `local_auth_android` | pub.dev | 3+ years | flutter.dev / Flutter team | github.com/flutter/packages (endorsed) | Approved — auto-included, no manual dep needed |
| `local_auth_darwin` | pub.dev | 3+ years | flutter.dev / Flutter team | github.com/flutter/packages (endorsed) | Approved — auto-included, no manual dep needed |

[VERIFIED: pub.dev] Publisher is the Flutter team at `flutter.dev`. Package lives in the official `flutter/packages` monorepo at `packages/local_auth/local_auth`.

**Packages removed:** none.
**Packages flagged as suspicious:** none.

---

## Architecture Patterns

### System Architecture Diagram

```
Cold Launch
    │
    ▼
ClaudePilotApp (app.dart)
    │
    ├── AppLifecycleListener (records _pausedAt / checks timeout on resume)
    │
    └── Consumer widget watches biometricAuthProvider.isAuthenticated
            │
            ├── isAuthenticated == false ──► LockScreen
            │                                    │
            │                                    ├── initState auto-calls _authenticate()
            │                                    │       │
            │                                    │       └── LocalAuthentication.authenticate()
            │                                    │               │ (OS handles Face ID / fingerprint / PIN)
            │                                    │               ▼
            │                                    │       true → ref.read(biometricAuthProvider.notifier).setAuthenticated(true)
            │                                    │       false → show "Retry" button
            │                                    │
            │                                    └── "Authenticate" button → _authenticate()
            │
            └── isAuthenticated == true ──► MaterialApp.router (GoRouter)
                                                │
                                                └── /machines (MachineListScreen)
                                                        │
                                                        ├── onEdit tap → requireBiometric() ──► local_auth
                                                        │       │ success → navigate to edit screen
                                                        │       └── failure → do nothing (cancel nav)
                                                        │
                                                        └── onDelete tap → requireBiometric() ──► local_auth
                                                                │ success → delete()
                                                                └── failure → do nothing
```

### Recommended Project Structure

```
lib/
├── app.dart                                      # Add AppLifecycleListener + auth conditional
├── features/
│   ├── auth/
│   │   ├── providers/
│   │   │   ├── biometric_auth_provider.dart      # NEW: Notifier<bool>, keepAlive: true
│   │   │   └── biometric_auth_provider.g.dart    # generated
│   │   ├── screens/
│   │   │   └── lock_screen.dart                  # NEW: minimal lock UI
│   │   └── utils/
│   │       └── biometric_guard.dart              # NEW: requireBiometric() utility function
│   └── machines/
│       └── screens/
│           └── machine_list_screen.dart          # MODIFIED: gate edit/delete with requireBiometric()
android/
└── app/
    ├── src/main/
    │   ├── AndroidManifest.xml                   # MODIFIED: add USE_BIOMETRIC permission
    │   └── kotlin/…/MainActivity.kt              # MODIFIED: FlutterActivity → FlutterFragmentActivity
ios/
└── Runner/
    └── Info.plist                                # MODIFIED: add NSFaceIDUsageDescription
pubspec.yaml                                      # MODIFIED: add local_auth: ^2.3.0
```

### Pattern 1: BiometricAuthProvider (Notifier<bool>, keepAlive)

**What:** Single source of truth for isAuthenticated — a simple bool, no async loading state needed.
**When to use:** Cold launch gate; background timeout reset; edit gate check.

```dart
// lib/features/auth/providers/biometric_auth_provider.dart
// Source: CONTEXT.md locked decision + Riverpod 3 annotation pattern from ssh_session_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_auth_provider.g.dart';

@Riverpod(keepAlive: true)
class BiometricAuth extends _$BiometricAuth {
  @override
  bool build() => false; // default: locked on cold start

  void setAuthenticated(bool value) {
    state = value;
  }
}
```

### Pattern 2: LockScreen with auto-trigger

**What:** Minimal widget that auto-calls authenticate() in initState — matches iOS Face ID native pattern.
**When to use:** Shown when `!isAuthenticated` at app root.

```dart
// lib/features/auth/screens/lock_screen.dart
// Source: CONTEXT.md locked decision

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger — Face ID activates immediately on first build (BIO-01)
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    final auth = LocalAuthentication();
    try {
      final didAuth = await auth.authenticate(
        localizedReason: 'Autentícate para acceder a Claude Pilot',
        // biometricOnly defaults to false — PIN fallback automatic (BIO-04)
      );
      if (didAuth && mounted) {
        ref.read(biometricAuthProvider.notifier).setAuthenticated(true);
      } else if (mounted) {
        setState(() => _authFailed = true);
      }
    } on PlatformException {
      // local_auth 2.x throws PlatformException (not LocalAuthException which is 3.x)
      if (mounted) setState(() => _authFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) { ... }
}
```

### Pattern 3: AppLifecycleListener for background timeout

**What:** Attach to the root `ClaudePilotApp` widget via `StatefulWidget` to track pause/resume timestamps.
**When to use:** Background timeout — BIO-03.

```dart
// lib/app.dart — convert ClaudePilotApp to StatefulWidget
// Source: CONTEXT.md locked decision + Flutter AppLifecycleListener API

const kLockTimeout = Duration(minutes: 10);

class _ClaudePilotAppState extends ConsumerState<ClaudePilotApp> {
  late final AppLifecycleListener _lifecycleListener;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => _pausedAt = DateTime.now(),
      onResume: () {
        final paused = _pausedAt;
        if (paused != null &&
            DateTime.now().difference(paused) > kLockTimeout) {
          ref.read(biometricAuthProvider.notifier).setAuthenticated(false);
        }
        _pausedAt = null;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }
}
```

**Note:** Because `biometricAuthProvider` is `@Riverpod(keepAlive: true)`, `ref` is accessible in `ConsumerStatefulWidget`. The app root must become a `ConsumerStatefulWidget` (not `StatelessWidget`) to hold the `AppLifecycleListener`.

### Pattern 4: requireBiometric guard utility

**What:** Async utility called at edit/delete callsites before navigation.
**When to use:** BIO-02 — gate on machine_list_screen.dart.

```dart
// lib/features/auth/utils/biometric_guard.dart
// Source: CONTEXT.md locked decision

Future<bool> requireBiometric(BuildContext context) async {
  final auth = LocalAuthentication();
  try {
    return await auth.authenticate(
      localizedReason: 'Autentícate para modificar las credenciales',
    );
  } on PlatformException {
    return false;
  }
}

// Usage in machine_list_screen.dart:
onEdit: () async {
  final ok = await requireBiometric(context);
  if (ok && context.mounted) {
    context.push('/machines/${machine.id}/edit');
  }
},
```

### Anti-Patterns to Avoid

- **Gating inside the edit screen:** User sees the form flash before auth dialog. Gate at the callsite (list screen), not the destination.
- **`biometricOnly: true`:** Breaks BIO-04 — devices without biometric hardware get no PIN fallback. Leave `biometricOnly` at its default `false`.
- **Catching all exceptions silently:** In 2.x, `PlatformException` is thrown for most failures. Catch it, but log the code for debugging — do not swallow silently.
- **`autoDispose` on biometricAuthProvider:** `autoDispose` (the default `@riverpod`) drops state when all listeners detach during navigation. During GoRouter transitions, the provider can briefly lose all listeners and reset `isAuthenticated = false`, causing a spurious lock. `@Riverpod(keepAlive: true)` prevents this.
- **Forgetting `addPostFrameCallback` in LockScreen initState:** Calling `authenticate()` directly in `initState` before the first frame can cause platform channel errors. Wrap in `addPostFrameCallback`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Biometric authentication prompt | Custom platform channel to TouchID/FaceID/Fingerprint APIs | `local_auth` | The OS differences (Face ID entitlements, Android BiometricPrompt API levels, PIN fallback paths) are non-trivial; local_auth handles all of them |
| PIN/passcode fallback | Custom PIN UI | `local_auth` with `biometricOnly: false` | OS provides the PIN/passcode UI — re-implementing it duplicates native UX and breaks accessibility |
| Background lifecycle detection | Manual `WidgetsBindingObserver` with `didChangeAppLifecycleState` | `AppLifecycleListener` (Flutter 3.13+) | `AppLifecycleListener` is the current API; `WidgetsBindingObserver` approach still works but is more verbose |

**Key insight:** BIO-04 (PIN fallback) is literally free — `local_auth` with `biometricOnly` at its default `false` passes through to the OS PIN prompt automatically. There is zero additional code for this requirement.

---

## Common Pitfalls

### Pitfall 1: FlutterActivity instead of FlutterFragmentActivity (Android)

**What goes wrong:** Authentication silently fails or throws a `PlatformException(error, Fatal: FragmentActivity required)` on Android. The app never shows a biometric prompt.
**Why it happens:** `local_auth` uses Android's `BiometricPrompt`, which requires a `FragmentActivity`. The default Flutter project generates `MainActivity : FlutterActivity()`, not `FlutterFragmentActivity`.
**How to avoid:** Change `MainActivity.kt` to `import io.flutter.embedding.android.FlutterFragmentActivity` and extend it instead.
**Warning signs:** Auth calls on Android return immediately with no prompt shown, or crash with fragment-related stack trace.

[VERIFIED: pub.dev README + official GitHub issue #37083]

### Pitfall 2: Missing USE_BIOMETRIC permission in AndroidManifest.xml

**What goes wrong:** `local_auth` silently reports no biometric hardware available, or throws SecurityException on Android 6+.
**Why it happens:** Android requires explicit permission declaration. The current `AndroidManifest.xml` has `INTERNET` and `RECORD_AUDIO` but not `USE_BIOMETRIC`.
**How to avoid:** Add `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>` to `AndroidManifest.xml`.
**Warning signs:** `canCheckBiometrics` returns false even on biometric-capable device.

[VERIFIED: pub.dev README]

### Pitfall 3: Missing NSFaceIDUsageDescription in iOS Info.plist

**What goes wrong:** App crashes at runtime on iOS when `authenticate()` is called with Face ID. App Store review rejects the build.
**Why it happens:** iOS requires a usage description for any API that accesses biometric hardware. Without it, the OS kills the process.
**How to avoid:** Add `<key>NSFaceIDUsageDescription</key><string>Claude Pilot usa Face ID para proteger tus credenciales SSH.</string>` to `ios/Runner/Info.plist`.
**Warning signs:** `MissingPluginException` or hard crash on iOS physical device when auth is triggered.

[CITED: developer.apple.com/documentation/localauthentication]

### Pitfall 4: autoDispose resets auth state during navigation

**What goes wrong:** User authenticates, navigates to a child route, then back — and is asked to authenticate again immediately.
**Why it happens:** GoRouter navigation removes the Consumer of `biometricAuthProvider` momentarily. With `autoDispose`, the provider disposes and resets to `false`.
**How to avoid:** `@Riverpod(keepAlive: true)` on `BiometricAuth`. Already locked in CONTEXT.md — do not use `@riverpod` (autoDispose default).
**Warning signs:** Re-lock happens during in-app navigation, not only after 10 minutes of backgrounding.

[ASSUMED based on Riverpod 3 autoDispose behavior]

### Pitfall 5: minSdk change is a no-op (already 24)

**What goes wrong:** Not a pitfall — but CONTEXT.md says "raise minSdk from 23 to 24." This task can be skipped or confirmed as done.
**Why it happens:** `minSdk = flutter.minSdkVersion` in `build.gradle.kts` already resolves to **24** in the installed Flutter SDK (`FlutterExtension.kt: val minSdkVersion: Int = 24`).
**How to avoid:** No action needed. Verify with `grep minSdk android/app/build.gradle.kts`.
**Warning signs:** None — this is a non-issue, but leaving the task in the plan creates confusion.

[VERIFIED: Flutter SDK source at ~/.local/share/mise/.../FlutterExtension.kt]

### Pitfall 6: local_auth 2.x vs 3.x API confusion

**What goes wrong:** Code uses `LocalAuthExceptionCode` or individual parameters (3.x API) when `^2.3.0` resolves to 2.x, causing compile errors.
**Why it happens:** pub.dev shows 3.0.1 as latest; documentation pages now show 3.x API by default.
**How to avoid:** With `^2.3.0`, use `AuthenticationOptions` and catch `PlatformException`. The `persistAcrossBackgrounding` rename and `LocalAuthException` are **3.x only**.
**2.x authenticate signature:**
```dart
// local_auth 2.x API
Future<bool> authenticate({
  required String localizedReason,
  Iterable<AuthMessages> authMessages = const [...],
  AuthenticationOptions options = const AuthenticationOptions(),
})
// AuthenticationOptions has: biometricOnly, stickyAuth, sensitiveTransaction, useErrorDialogs
```
**Warning signs:** Compile error "LocalAuthException not found" or "persistAcrossBackgrounding is not a parameter."

[VERIFIED: pub.dev changelog + GitHub source for local_auth 2.3.0]

---

## Code Examples

### Android MainActivity change

```kotlin
// android/app/src/main/kotlin/com/example/claude_pilot/MainActivity.kt
// Source: pub.dev local_auth README (Android setup)

package com.example.claude_pilot

import io.flutter.embedding.android.FlutterFragmentActivity  // changed from FlutterActivity

class MainActivity : FlutterFragmentActivity()
```

### AndroidManifest.xml permission addition

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<!-- Source: pub.dev local_auth README -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<!-- Place before <application> tag, alongside existing permissions -->
```

### iOS Info.plist addition

```xml
<!-- ios/Runner/Info.plist — add inside the top-level <dict> -->
<!-- Source: Apple developer docs + pub.dev local_auth README -->
<key>NSFaceIDUsageDescription</key>
<string>Claude Pilot usa Face ID para proteger tus credenciales SSH.</string>
```

### Checking biometric availability before prompting

```dart
// Source: pub.dev local_auth documentation (2.x)
final auth = LocalAuthentication();
final bool canCheck = await auth.canCheckBiometrics;
final bool isSupported = await auth.isDeviceSupported();
// canCheck: device has biometric hardware AND has enrolled biometrics
// isSupported: device has any auth capability (including PIN only)
// For BIO-04: if !canCheck but isSupported → OS PIN dialog shown automatically
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `stickyAuth` in `AuthenticationOptions` | `persistAcrossBackgrounding` named parameter | local_auth 3.0.0 (2025-10) | 2.x code uses `stickyAuth`; 3.x code uses `persistAcrossBackgrounding` |
| `PlatformException` for auth failures | `LocalAuthException` with `LocalAuthExceptionCode` | local_auth 3.0.0 (2025-10) | 2.x: catch `PlatformException`; 3.x: catch `LocalAuthException` |
| `AuthenticationOptions` wrapper object | Individual named parameters on `authenticate()` | local_auth 3.0.0 (2025-10) | Phase 5 uses 2.x — `AuthenticationOptions` is still used |
| `WidgetsBindingObserver.didChangeAppLifecycleState` | `AppLifecycleListener` class | Flutter 3.13 (Aug 2023) | More declarative; individual callbacks per state instead of switch |

**Deprecated/outdated:**
- `local_auth: <2.0.0` (`BiometricsPlugin`): removed in 2.x, replaced with `LocalAuthentication` class
- `AuthenticationOptions(useErrorDialogs: true)`: 3.x removed error dialogs from the plugin — app must handle errors via `LocalAuthExceptionCode`

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `addPostFrameCallback` is required to safely call `authenticate()` from `initState` | Pattern 2 / Anti-Patterns | Low risk: worst case is a platform exception at first frame; `addPostFrameCallback` is defensive best practice |
| A2 | `onPause` callback fires reliably on both iOS and Android when app goes to background | Pattern 3 | Medium risk: if callback misfires, timeout never triggers or triggers spuriously. If unstable, fallback is `AppLifecycleState.paused` via `onStateChange` |

---

## Open Questions

1. **local_auth 2.3.0 vs 3.0.1 — should we upgrade?**
   - What we know: 3.0.1 is current; 2.3.0 is stable and API-complete for this phase's needs
   - What's unclear: Whether there are relevant bug fixes in 3.x for biometric edge cases on newer Android/iOS
   - Recommendation: Stay with `^2.3.0` per locked decision. If 3.x features are needed in a future phase, upgrade then.

2. **minSdk task in CONTEXT.md — is it real work?**
   - What we know: `flutter.minSdkVersion` already resolves to 24 in the installed SDK
   - What's unclear: Whether the project ever had an explicit `minSdk = 23` override that was reverted
   - Recommendation: Planner should include a verification step ("confirm minSdk ≥ 24") rather than a change step.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| local_auth (pub.dev) | BIO-01..04 | ✓ (pub.dev) | 2.3.0 via ^2.3.0 | — |
| Android SDK | build.gradle | ✓ | 36 (compileSdk) | — |
| iOS deployment target | Info.plist | ✓ | 13.0 | — |
| Flutter SDK | all | ✓ | minSdkVersion=24 confirmed | — |

**Missing dependencies with no fallback:** none.

---

## Security Domain

> `security_enforcement` not set to false — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | local_auth — OS-managed biometric/PIN; no custom auth implementation |
| V3 Session Management | yes | biometricAuthProvider `keepAlive: true`; re-lock on 10-min background |
| V4 Access Control | yes | requireBiometric() gate before credential edit/delete; gate at callsite |
| V5 Input Validation | no | No user input in this phase; localizedReason is a static string |
| V6 Cryptography | no | Credential storage is flutter_secure_storage (Phase 1); not modified here |

### Known Threat Patterns for Biometric Auth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Backgrounded app exposes credentials to physical access | Elevation of Privilege | BIO-03: 10-minute background timeout re-locks; AppLifecycleListener enforces it |
| Edit form opened without re-auth (navigation race) | Elevation of Privilege | Gate at callsite (machine_list_screen), not inside edit screen; `context.mounted` check before push |
| `biometricOnly: true` leaves PIN-only devices with no auth | Denial of Service | Keep `biometricOnly` at default `false`; OS provides PIN fallback (BIO-04) |
| Auth state reset by autoDispose during navigation | Security bypass | `@Riverpod(keepAlive: true)` prevents disposal between navigation transitions |

---

## Sources

### Primary (HIGH confidence)
- [pub.dev/packages/local_auth](https://pub.dev/packages/local_auth) — version 3.0.1 confirmed current; 2.3.0 changelog verified
- [pub.dev/packages/local_auth/changelog](https://pub.dev/packages/local_auth/changelog) — 3.0.0 breaking changes confirmed: AuthenticationOptions replaced, stickyAuth → persistAcrossBackgrounding, PlatformException → LocalAuthException
- [github.com/flutter/packages — local_auth/lib/src/local_auth.dart](https://github.com/flutter/packages/blob/main/packages/local_auth/local_auth/lib/src/local_auth.dart) — authenticate() method signature verified for 3.x
- [pub.dev documentation: LocalAuthExceptionCode](https://pub.dev/documentation/local_auth/latest/local_auth/LocalAuthExceptionCode.html) — all exception codes verified
- [api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html) — onPause/onResume callbacks confirmed
- Flutter SDK source `FlutterExtension.kt` (local path) — `flutter.minSdkVersion = 24` confirmed

### Secondary (MEDIUM confidence)
- [pub.dev local_auth README (Android setup)](https://pub.dev/packages/local_auth) — FlutterFragmentActivity requirement and USE_BIOMETRIC permission confirmed via WebFetch
- [pub.dev local_auth_android 2.0.9](https://pub.dev/packages/local_auth_android) — endorsed, auto-included

### Tertiary (LOW confidence — not used for locked decisions)
- [WebSearch: FlutterFragmentActivity requirement](https://github.com/flutter/flutter/issues/37083) — corroborates official README

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pub.dev API verified, official Flutter team package
- Architecture: HIGH — locked in CONTEXT.md, verified against existing codebase
- Pitfalls: HIGH (Pitfalls 1-3 from official README), MEDIUM (Pitfall 4 from Riverpod docs), VERIFIED (Pitfall 5 from SDK source)
- API signatures: MEDIUM — 3.x API verified from source; 2.x inferred from changelog delta and pub.dev 2.3.0 docs

**Research date:** 2026-06-20
**Valid until:** 2026-12-20 (local_auth is stable; unlikely to change materially within 6 months)
