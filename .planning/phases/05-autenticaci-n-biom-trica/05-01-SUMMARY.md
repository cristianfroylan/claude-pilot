---
phase: 05-autenticaci-n-biom-trica
plan: "01"
subsystem: auth
tags: [biometric, local_auth, android, ios, riverpod, codegen]
dependency_graph:
  requires: []
  provides:
    - biometricAuthProvider (keepAlive Notifier<bool>)
    - local_auth 2.3.0 platform integration
  affects:
    - pubspec.yaml
    - android/app/src/main/AndroidManifest.xml
    - android/app/src/main/kotlin/com/example/claude_pilot/MainActivity.kt
    - ios/Runner/Info.plist
    - lib/features/auth/providers/biometric_auth_provider.dart
    - lib/features/auth/providers/biometric_auth_provider.g.dart
tech_stack:
  added:
    - local_auth: "^2.3.0"
  patterns:
    - "@Riverpod(keepAlive: true) Notifier<bool> for auth state"
    - "FlutterFragmentActivity for Android BiometricPrompt compatibility"
key_files:
  created:
    - lib/features/auth/providers/biometric_auth_provider.dart
    - lib/features/auth/providers/biometric_auth_provider.g.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - android/app/src/main/AndroidManifest.xml
    - android/app/src/main/kotlin/com/example/claude_pilot/MainActivity.kt
    - ios/Runner/Info.plist
decisions:
  - "Use local_auth ^2.3.0 (not 3.x) — CONTEXT.md locked; AuthenticationOptions + PlatformException API"
  - "@Riverpod(keepAlive: true) prevents autoDispose reset during GoRouter navigation transitions"
  - "biometricAuthProvider is Notifier<bool> not AsyncNotifier — auth result is synchronous bool"
metrics:
  duration: "~8 minutes"
  completed: "2026-06-20"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 5
---

# Phase 5 Plan 1: Platform Prerequisites + Biometric Auth Provider Summary

**One-liner:** local_auth 2.3.0 integrated with FlutterFragmentActivity, USE_BIOMETRIC, NSFaceIDUsageDescription, and keepAlive Notifier<bool> provider ready for consumers.

## What Was Built

### Task 1: Platform Prerequisites

Four changes required for `local_auth` to function on both platforms:

1. **pubspec.yaml** — Added `local_auth: ^2.3.0` between `go_router` and `shared_preferences` (alphabetical order). `flutter pub get` resolved local_auth 2.3.0 with platform implementations `local_auth_android 1.0.56` and `local_auth_darwin 1.6.1`.

2. **AndroidManifest.xml** — Added `android.permission.USE_BIOMETRIC` permission after the existing RECORD_AUDIO permission. Without this, `canCheckBiometrics` returns false on biometric-capable hardware.

3. **MainActivity.kt** — Replaced `FlutterActivity` with `FlutterFragmentActivity` (both import and class extension). Required because `local_auth` uses Android's `BiometricPrompt` API which requires a `FragmentActivity`.

4. **ios/Runner/Info.plist** — Added `NSFaceIDUsageDescription` with Spanish string before the closing `</dict>`. Without this the app crashes at runtime when `authenticate()` is called on iOS, and the App Store rejects the binary.

### Task 2: BiometricAuth Provider + Codegen

Created `lib/features/auth/providers/biometric_auth_provider.dart`:
- `@Riverpod(keepAlive: true)` annotation — prevents autoDispose during GoRouter navigation transitions
- `class BiometricAuth extends _$BiometricAuth` — Riverpod codegen pattern
- `bool build() => false` — app starts locked
- `void setAuthenticated(bool value) => state = value` — synchronous state setter

Generated `lib/features/auth/providers/biometric_auth_provider.g.dart` via `dart run build_runner build`. The generated file confirms `isAutoDispose: false` meaning keepAlive is active. The symbol `biometricAuthProvider` is available for consumers.

`flutter build apk --debug` exits 0 — project compiles cleanly with the new provider.

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 | 8a1fcb5 | feat(05-01): platform prerequisites for biometric auth |
| Task 2 | 278bbc5 | feat(05-01): biometric auth provider with codegen |

## Deviations from Plan

None — plan executed exactly as written.

The minSdk check confirmed: `minSdk = flutter.minSdkVersion` already resolves to 24, no change needed (as stated in RESEARCH.md Pitfall 5).

## Known Stubs

None — this plan creates infrastructure only. `biometricAuthProvider` starts at `false` intentionally (app starts locked). The LockScreen and AppLifecycleListener that wire the actual authentication are in subsequent plans.

## Threat Flags

No new threat surface introduced beyond what is documented in the plan's `<threat_model>`. All four threat register items (T-05-01 through T-05-SC) have been addressed:
- T-05-01: FlutterFragmentActivity is now in place
- T-05-02: NSFaceIDUsageDescription is now in ios/Runner/Info.plist
- T-05-03: @Riverpod(keepAlive: true) is confirmed via generated isAutoDispose: false
- T-05-SC: local_auth is official Flutter team package, approved

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/features/auth/providers/biometric_auth_provider.dart exists | FOUND |
| lib/features/auth/providers/biometric_auth_provider.g.dart exists | FOUND |
| Commit 8a1fcb5 (platform prerequisites) exists | FOUND |
| Commit 278bbc5 (biometric auth provider) exists | FOUND |
