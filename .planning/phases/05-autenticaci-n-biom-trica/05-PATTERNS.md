# Phase 5: Autenticación Biométrica - Pattern Map

**Mapped:** 2026-06-20
**Files analyzed:** 9 (3 new, 6 modified)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/auth/providers/biometric_auth_provider.dart` | provider | request-response | `lib/features/machines/providers/machines_provider.dart` | role-match (keepAlive pattern from ssh_session_provider) |
| `lib/features/auth/providers/biometric_auth_provider.g.dart` | generated | — | `lib/features/machines/providers/machines_provider.g.dart` | exact (codegen artifact) |
| `lib/features/auth/screens/lock_screen.dart` | screen/component | request-response | `lib/features/terminal/screens/terminal_screen.dart` (ConsumerStatefulWidget pattern) + `lib/features/terminal/widgets/voice_bottom_sheet.dart` (minimal widget UI) | role-match |
| `lib/features/auth/utils/biometric_guard.dart` | utility | request-response | `lib/features/terminal/providers/permission_detector_provider.dart` (pattern guard logic) | partial-match |
| `lib/app.dart` | provider/root | event-driven | `lib/app.dart` itself (StatelessWidget → ConsumerStatefulWidget conversion) | self |
| `lib/features/machines/screens/machine_list_screen.dart` | screen | CRUD | itself (adding async guard to existing edit/delete handlers) | self |
| `android/app/src/main/kotlin/com/example/claude_pilot/MainActivity.kt` | config | — | itself (1-line class change) | self |
| `android/app/src/main/AndroidManifest.xml` | config | — | itself (adding permission alongside existing INTERNET + RECORD_AUDIO) | self |
| `ios/Runner/Info.plist` | config | — | itself (adding key alongside existing NSMicrophoneUsageDescription pattern from speech_to_text) | self |
| `pubspec.yaml` | config | — | itself (adding dependency alongside existing package entries) | self |

---

## Pattern Assignments

### `lib/features/auth/providers/biometric_auth_provider.dart` (provider, request-response)

**Analog:** `lib/features/machines/providers/machines_provider.dart` (annotation pattern) + `lib/features/terminal/providers/ssh_session_provider.dart` (keepAlive pattern)

**Key distinction:** `machines_provider.dart` uses `@riverpod` (autoDispose, the default). The biometric provider MUST use `@Riverpod(keepAlive: true)` — the only existing provider with `keepAlive` is `ssh_session_provider.dart` via `@Riverpod(retry: _noRetry)`. The biometric provider is simpler: `Notifier<bool>` not `AsyncNotifier`.

**Imports pattern** — copy from `lib/features/machines/providers/machines_provider.dart` lines 1–8, trim to only what is needed:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_auth_provider.g.dart';
```

**Annotation + class pattern** — the `@riverpod` form from `machines_provider.dart` line 13 becomes `@Riverpod(keepAlive: true)`:
```dart
// machines_provider.dart line 13 — the DEFAULT annotation (autoDispose):
@riverpod
class MachineNotifier extends _$MachineNotifier {

// biometric_auth_provider.dart — use keepAlive instead:
@Riverpod(keepAlive: true)
class BiometricAuth extends _$BiometricAuth {
  @override
  bool build() => false;   // locked on cold start

  void setAuthenticated(bool value) => state = value;
}
```

**Generated file name convention** — matches `machines_provider.g.dart`: file name is `biometric_auth_provider.g.dart`, `part` directive uses the same basename. Run `dart run build_runner build` after creating the provider.

**Mutation pattern** — copy from `machines_provider.dart` lines 25–32 (ref.invalidateSelf replacement with direct state assignment):
```dart
// machines_provider.dart lines 25-32 — invalidateSelf triggers async reload:
Future<void> save(Machine machine, String password) async {
  await _repo?.save(machine, password);
  ref.invalidateSelf();
}

// biometric_auth_provider.dart — synchronous bool, no async/invalidateSelf needed:
void setAuthenticated(bool value) => state = value;
```

**Callsite read pattern** — copy from `machines_provider.dart` usage in `machine_list_screen.dart` line 37:
```dart
// machine_list_screen.dart line 37:
ref.read(machineProvider.notifier).delete(machines[i].id)

// biometric_auth_provider.dart callsite:
ref.read(biometricAuthProvider.notifier).setAuthenticated(true)
ref.read(biometricAuthProvider.notifier).setAuthenticated(false)
```

---

### `lib/features/auth/screens/lock_screen.dart` (screen, request-response)

**Analog:** `lib/features/terminal/screens/terminal_screen.dart` (ConsumerStatefulWidget + initState lifecycle pattern) and `lib/features/terminal/widgets/voice_bottom_sheet.dart` (minimal widget styling)

**ConsumerStatefulWidget pattern** — copy from `terminal_screen.dart` lines 241–268 (`_ConnectingDotState extends State` as the `StatefulWidget` + `State` scaffold). LockScreen uses `ConsumerStatefulWidget` + `ConsumerState`:
```dart
// terminal_screen.dart lines 241-246 — StatefulWidget inner class:
class _ConnectingDot extends StatefulWidget {
  const _ConnectingDot();
  @override
  State<_ConnectingDot> createState() => _ConnectingDotState();
}

// lock_screen.dart — ConsumerStatefulWidget variant:
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}
```

**initState + addPostFrameCallback pattern** — copy from `terminal_screen.dart` lines 251–260 (AnimationController init in initState):
```dart
// terminal_screen.dart lines 251-260 — initState pattern:
@override
void initState() {
  super.initState();
  _controller = AnimationController(...)..repeat(reverse: true);
}

// lock_screen.dart — use addPostFrameCallback to defer platform channel call:
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
}
```

**Imports pattern** — combine `terminal_screen.dart` lines 1–13 (flutter_riverpod, platform imports) and trim:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';       // PlatformException
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/biometric_auth_provider.dart';
```

**Error handling pattern** — copy from `terminal_screen.dart` lines 48–67 (ref.listen + state-driven conditional rendering):
```dart
// terminal_screen.dart lines 62-66 — conditional rendering on failure state:
if (nextState is SshFailed && prevState is! SshFailed) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not connect to $machineName.')),
  );
}

// lock_screen.dart — auth failure drives setState, not SnackBar:
} on PlatformException {
  if (mounted) setState(() => _authFailed = true);
}
```

**Minimal widget styling pattern** — copy from `voice_bottom_sheet.dart` lines 19–94 (colorScheme tokens, FilledButton + TextButton pattern, spacing):
```dart
// voice_bottom_sheet.dart lines 19-20 — colorScheme access:
final colorScheme = Theme.of(context).colorScheme;

// voice_bottom_sheet.dart lines 73-85 — FilledButton primary action:
FilledButton(
  onPressed: onSend,
  child: const Text('Send message'),
),

// lock_screen.dart — use same pattern for "Authenticate" button:
FilledButton(
  onPressed: _authenticate,
  child: const Text('Autenticar'),
),
```

**mounted check before setState** — copy from `terminal_screen.dart` line 56 pattern (context.mounted check before navigation):
```dart
// terminal_screen.dart (context.mounted pattern):
if (ok && context.mounted) { context.push(...); }

// lock_screen.dart — widget.mounted before setState and ref.read:
if (didAuth && mounted) {
  ref.read(biometricAuthProvider.notifier).setAuthenticated(true);
} else if (mounted) {
  setState(() => _authFailed = true);
}
```

---

### `lib/features/auth/utils/biometric_guard.dart` (utility, request-response)

**Analog:** No exact utility analog exists. Closest structural analog is the async-returning pattern from `machine_list_screen.dart` edit/delete handlers (lines 34–38).

**Function pattern** — top-level async function returning bool; mirrors how `ssh_session_provider.dart` uses top-level functions (line 19: `_noRetry` is top-level, not static):
```dart
// ssh_session_provider.dart line 19 — top-level function pattern:
Duration? _noRetry(int retryCount, Object error) => null;

// biometric_guard.dart — top-level async utility:
Future<bool> requireBiometric() async {
  final auth = LocalAuthentication();
  try {
    return await auth.authenticate(
      localizedReason: 'Autentícate para modificar las credenciales',
    );
  } on PlatformException {
    return false;
  }
}
```

**Imports for utility**:
```dart
import 'package:flutter/services.dart';    // PlatformException
import 'package:local_auth/local_auth.dart';
```

---

### `lib/app.dart` (app root, event-driven — MODIFIED)

**Analog:** `lib/app.dart` itself — current file is 47 lines, a `StatelessWidget`. Must be converted to `ConsumerStatefulWidget` to hold `AppLifecycleListener` and access `ref`.

**Current structure** (lines 1–47 — read above, now fully in context):
- Line 36: `class ClaudePilotApp extends StatelessWidget`
- Line 40: `Widget build(BuildContext context)`
- Line 41: returns `MaterialApp.router` directly

**Target structure** — `ConsumerStatefulWidget` (analog: `terminal_screen.dart` `_ConnectingDotState` pattern for StatefulWidget lifecycle):
```dart
// lib/app.dart — converted structure:
const kLockTimeout = Duration(minutes: 10);

class ClaudePilotApp extends ConsumerStatefulWidget {
  const ClaudePilotApp({super.key});
  @override
  ConsumerState<ClaudePilotApp> createState() => _ClaudePilotAppState();
}

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

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(biometricAuthProvider);
    return isAuthenticated
        ? MaterialApp.router(
            title: 'Claude Pilot',
            theme: AppTheme.darkTheme,
            routerConfig: _router,
          )
        : MaterialApp(
            title: 'Claude Pilot',
            theme: AppTheme.darkTheme,
            home: const LockScreen(),
          );
  }
}
```

**dispose pattern** — copy from `terminal_screen.dart` lines 263–265:
```dart
// terminal_screen.dart lines 263-265:
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

**New imports to add** (beyond existing `app.dart` imports lines 1–6):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/providers/biometric_auth_provider.dart';
import 'features/auth/screens/lock_screen.dart';
```

---

### `lib/features/machines/screens/machine_list_screen.dart` (screen, CRUD — MODIFIED)

**Analog:** `machine_list_screen.dart` itself (lines 1–74, fully read above).

**Current edit/delete handlers** (lines 34–38):
```dart
// machine_list_screen.dart lines 34-38 — CURRENT (no auth gate):
onEdit: () =>
    context.push('/machines/${machines[i].id}/edit'),
onDelete: () => ref
    .read(machineProvider.notifier)
    .delete(machines[i].id),
```

**Target edit/delete handlers** — wrap with `requireBiometric()` before navigation/delete:
```dart
// machine_list_screen.dart — AFTER modification:
onEdit: () async {
  final ok = await requireBiometric();
  if (ok && context.mounted) {
    context.push('/machines/${machines[i].id}/edit');
  }
},
onDelete: () async {
  final ok = await requireBiometric();
  if (ok) {
    ref.read(machineProvider.notifier).delete(machines[i].id);
  }
},
```

**context.mounted check** — copy from `terminal_screen.dart` line pattern:
```dart
if (ok && context.mounted) { context.push(...); }
```

**New import to add** (alongside existing imports lines 1–5):
```dart
import '../../auth/utils/biometric_guard.dart';
```

**Widget type stays `ConsumerWidget`** — no lifecycle needed at this callsite, `requireBiometric()` is a standalone async function.

---

### `android/app/src/main/kotlin/com/example/claude_pilot/MainActivity.kt` (config — MODIFIED)

**Analog:** `MainActivity.kt` itself (lines 1–5, fully read above).

**Current content** (lines 1–5):
```kotlin
package com.example.claude_pilot

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

**Target content** — single import swap:
```kotlin
package com.example.claude_pilot

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

**Why:** `local_auth` uses Android `BiometricPrompt` which requires a `FragmentActivity`. `FlutterActivity` is not a `FragmentActivity`; `FlutterFragmentActivity` is. Source: pub.dev local_auth README (Android setup).

---

### `android/app/src/main/AndroidManifest.xml` (config — MODIFIED)

**Analog:** `AndroidManifest.xml` itself (lines 1–55, fully read above).

**Current permissions** (lines 3–4):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**Addition** — insert after line 4, following the established comment + permission pattern:
```xml
<!-- Required for biometric authentication (local_auth) -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

---

### `ios/Runner/Info.plist` (config — MODIFIED)

**Analog:** `Info.plist` itself (lines 1–70, fully read above). Existing pattern: `speech_to_text` in a prior phase added `NSMicrophoneUsageDescription` (not present in the current file, but the pattern for usage descriptions is established by the pub.dev plugin ecosystem).

**Addition** — insert inside `<dict>` before the closing `</dict>` tag (after line 68):
```xml
<key>NSFaceIDUsageDescription</key>
<string>Claude Pilot usa Face ID para proteger tus credenciales SSH.</string>
```

**Note:** Without this key, the iOS app crashes at runtime when `authenticate()` is called with Face ID, and the App Store rejects the build.

---

### `pubspec.yaml` (config — MODIFIED)

**Analog:** `pubspec.yaml` itself (lines 1–30, fully read above).

**Current dependencies block** (lines 10–19):
```yaml
dependencies:
  flutter:
    sdk: flutter
  dartssh2: ^2.18.0
  xterm: ^4.0.0
  flutter_riverpod: ^3.3.1
  riverpod_annotation: 4.0.2
  flutter_secure_storage: ^10.3.1
  shared_preferences: ^2.5.5
  go_router: ^17.3.0
  speech_to_text: ^7.4.0
```

**Addition** — insert `local_auth: ^2.3.0` in alphabetical order between `go_router` and `shared_preferences`:
```yaml
  go_router: ^17.3.0
  local_auth: ^2.3.0
  shared_preferences: ^2.5.5
```

**Version constraint:** `^2.3.0` (NOT `^3.0.0`). The `^` means >=2.3.0 <3.0.0. Use 2.x API: `AuthenticationOptions`, `stickyAuth`, catch `PlatformException`. Do NOT use 3.x API: `persistAcrossBackgrounding`, `LocalAuthException`, individual named params on `authenticate()`.

---

## Shared Patterns

### ConsumerStatefulWidget lifecycle (dispose)
**Source:** `lib/features/terminal/screens/terminal_screen.dart` lines 251–268 (`_ConnectingDotState`)
**Apply to:** `lock_screen.dart` (if it needs an AnimationController for pulse), `app.dart` (for `AppLifecycleListener.dispose()`)
```dart
@override
void dispose() {
  _controller.dispose();   // replace with _lifecycleListener.dispose()
  super.dispose();
}
```

### ref.read notifier mutation
**Source:** `lib/features/machines/screens/machine_list_screen.dart` line 37
**Apply to:** `lock_screen.dart`, `app.dart` (AppLifecycleListener resume callback)
```dart
ref.read(machineProvider.notifier).delete(machines[i].id)
// pattern becomes:
ref.read(biometricAuthProvider.notifier).setAuthenticated(true)
ref.read(biometricAuthProvider.notifier).setAuthenticated(false)
```

### context.mounted guard before navigation
**Source:** `lib/features/terminal/screens/terminal_screen.dart` (mounted pattern)
**Apply to:** `machine_list_screen.dart` (after requireBiometric() returns), `lock_screen.dart` (before ref.read after async authenticate())
```dart
if (ok && context.mounted) {
  context.push('/machines/${machines[i].id}/edit');
}
```

### AppBar + Scaffold token usage
**Source:** `lib/features/machines/screens/machine_list_screen.dart` lines 14–22
**Apply to:** `lock_screen.dart` (use same `AppTheme.darkTheme` tokens, same `colorScheme.surfaceContainerHigh` for any surface backgrounds)
```dart
backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
```

### Minimal action widget (FilledButton + TextButton pair)
**Source:** `lib/features/terminal/widgets/voice_bottom_sheet.dart` lines 73–86
**Apply to:** `lock_screen.dart` retry UI
```dart
FilledButton(
  onPressed: _authenticate,
  child: const Text('Autenticar'),
),
```

---

## No Analog Found

All files have analogs or are self-modifications. No file in this phase is entirely unprecedented — the closest gap is `biometric_guard.dart` as a standalone utility function, but the top-level function pattern is established by `ssh_session_provider.dart` line 19.

| File | Role | Data Flow | Notes |
|------|------|-----------|-------|
| `lib/features/auth/utils/biometric_guard.dart` | utility | request-response | Nearest analog is the top-level `_noRetry` function in `ssh_session_provider.dart` — same pattern (top-level, not static method), but content is entirely new (no existing auth utilities) |

---

## Critical Implementation Notes for Planner

1. **`app.dart` widget type change is a prerequisite** for everything else — `biometricAuthProvider` read in `build()` requires `ConsumerStatefulWidget`, not `StatelessWidget`. This change must be in Plan 1.

2. **Android MainActivity change is a prerequisite** for Android auth — without `FlutterFragmentActivity`, `authenticate()` silently fails or throws. Must be done before any testing on Android.

3. **`biometric_auth_provider.g.dart` requires codegen** — after creating `biometric_auth_provider.dart`, run `dart run build_runner build` (same step as after any other provider file). The generated file should not be hand-written.

4. **local_auth 2.x API** — use `AuthenticationOptions` class and catch `PlatformException`. Do not use `LocalAuthException`, `persistAcrossBackgrounding`, or individual named params (those are 3.x only).

5. **`minSdk` change is a no-op** — `minSdk = flutter.minSdkVersion` in `build.gradle.kts` line 27 already resolves to 24 per the installed Flutter SDK. The planner should include a verification step, not a change step.

---

## Metadata

**Analog search scope:** `lib/` (all 24 Dart files), `android/app/src/main/`, `ios/Runner/`, root config files
**Files scanned:** 14 source files read (app.dart, machines_provider.dart, machine_list_screen.dart, ssh_session_provider.dart, permission_detector_provider.dart, terminal_screen.dart, voice_bottom_sheet.dart, app_theme.dart, MainActivity.kt, AndroidManifest.xml, Info.plist, build.gradle.kts, pubspec.yaml, machines_provider.g.dart header)
**Pattern extraction date:** 2026-06-20
