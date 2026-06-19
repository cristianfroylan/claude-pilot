---
phase: 01-ssh-terminal
plan: 01
subsystem: ui
tags: [flutter, dart, riverpod, go_router, dartssh2, xterm, flutter_secure_storage, shared_preferences, android]

# Dependency graph
requires: []
provides:
  - Flutter project skeleton with all Phase 1 packages installed
  - Android hardened manifest (allowBackup=false, INTERNET permission, adjustResize)
  - Material 3 dark theme with Catppuccin-inspired terminal color palette
  - GoRouter with 4 routes: /machines, add, :id/edit, :id/terminal
  - ProviderScope entry point wiring Riverpod to ClaudePilotApp
  - Stub screens for MachineList, AddEditMachine, Terminal
affects: [01-02, 01-03, all Phase 1 plans]

# Tech tracking
tech-stack:
  added:
    - dartssh2 2.18.0 (SSH transport)
    - xterm 4.0.0 (terminal renderer)
    - flutter_riverpod 3.3.1 (state management)
    - riverpod_annotation 4.0.2 (code generation annotations)
    - riverpod_generator 4.0.3 (code generation)
    - flutter_secure_storage 10.3.1 (encrypted credential storage)
    - shared_preferences 2.5.5 (machine metadata storage)
    - go_router 17.3.0 (declarative routing)
    - build_runner (Riverpod code generation)
  patterns:
    - ProviderScope wraps runApp in main.dart
    - MaterialApp.router with GoRouter config in app.dart
    - AppTheme static class with darkTheme + terminalTheme
    - ConsumerWidget base class for all screens

key-files:
  created:
    - pubspec.yaml
    - lib/main.dart
    - lib/app.dart
    - lib/core/theme/app_theme.dart
    - lib/features/machines/screens/machine_list_screen.dart
    - lib/features/machines/screens/add_edit_machine_screen.dart
    - lib/features/terminal/screens/terminal_screen.dart
    - test/widget_test.dart
    - android/app/src/main/AndroidManifest.xml
    - android/app/build.gradle.kts
  modified:
    - analysis_options.yaml

key-decisions:
  - "Used flutter_riverpod 3.3.1 / riverpod_annotation 4.0.2 / riverpod_generator 4.0.3 (not 3.3.2/4.0.3/4.0.4 from RESEARCH.md) due to meta 1.17.0 pin in Flutter 3.41.9 SDK"
  - "compileSdk set to 36 (not 34) because flutter_secure_storage 10.3.1 and shared_preferences_android require SDK 36"
  - "flutter.minSdkVersion = 24 in Flutter 3.41.9 (exceeds required 23) — Gradle plugin auto-upgrades minSdk to flutter variable"
  - "Kotlin DSL (.gradle.kts) used instead of Groovy (.gradle) — Flutter 3.41.9 generates Kotlin DSL by default"

patterns-established:
  - "Stub screen pattern: ConsumerWidget with Scaffold + minimal body, plan reference in doc comment"
  - "AppTheme: static class with darkTheme getter + const terminalTheme TerminalTheme object"
  - "GoRouter nested routes: /machines as root with add, :id/edit, :id/terminal as children"

requirements-completed: []

# Metrics
duration: 9min
completed: 2026-06-19
---

# Phase 1 Plan 01: Project Skeleton Summary

**Flutter project bootstrapped with all Phase 1 packages installed, dark Material 3 theme with Catppuccin terminal palette, GoRouter routing, and Android hardened against credential-loss bugs**

## Performance

- **Duration:** 9 min
- **Started:** 2026-06-19T17:57:09Z
- **Completed:** 2026-06-19T18:06:29Z
- **Tasks:** 3
- **Files modified:** 11

## Accomplishments

- All Phase 1 packages installed and resolving (`flutter pub get` exits 0)
- Dark Material 3 theme with seed color `#1E8BC3` and Catppuccin-inspired terminal palette (`#0F1117` background)
- GoRouter with `initialLocation: '/machines'` and 4 routes defined
- Android hardened: `allowBackup="false"`, INTERNET permission, `minSdk` floor enforced, `compileSdk=36`
- `flutter analyze` reports zero errors; `flutter build apk --debug` succeeds

## Task Commits

1. **Task 1: Create Flutter project and install Phase 1 packages** - `ca7c4da` (chore)
2. **Task 2: Harden Android manifest and build.gradle** - `d478c85` (chore)
3. **Task 3: Wire entry point, routing, and dark theme** - `cb8ee3b` (feat)

**Plan metadata:** (pending — created in final commit)

## Files Created/Modified

- `pubspec.yaml` - All Phase 1 dependencies, versions adjusted for Flutter 3.41.9 compatibility
- `pubspec.lock` - Resolved dependency graph (committed)
- `lib/main.dart` - Entry point: `ProviderScope` wraps `ClaudePilotApp()`
- `lib/app.dart` - `MaterialApp.router` + GoRouter 4-route config + `AppTheme.darkTheme`
- `lib/core/theme/app_theme.dart` - `AppTheme.darkTheme` (Material 3 seed `#1E8BC3`) + `AppTheme.terminalTheme` (xterm TerminalTheme with full 16-color Catppuccin palette)
- `lib/features/machines/screens/machine_list_screen.dart` - Stub: `'No machines yet'` empty state (Plan 02 impl)
- `lib/features/machines/screens/add_edit_machine_screen.dart` - Stub (Plan 02 impl)
- `lib/features/terminal/screens/terminal_screen.dart` - Stub with `machineId` param (Plan 03 impl)
- `android/app/src/main/AndroidManifest.xml` - INTERNET permission + `allowBackup="false"` + `adjustResize`
- `android/app/build.gradle.kts` - `compileSdk=36`, `minSdk=flutter.minSdkVersion` (=24 in Flutter 3.41.9)
- `analysis_options.yaml` - Disabled flutter_lints include (package not in dependencies)
- `test/widget_test.dart` - Updated to use `ClaudePilotApp` with `ProviderScope`

## Decisions Made

- **Riverpod version downgrade:** `flutter_riverpod ^3.3.1` / `riverpod_annotation 4.0.2` / `riverpod_generator 4.0.3` instead of RESEARCH.md's `^3.3.2` / `^4.0.3` / `^4.0.4`. Root cause: `riverpod_generator >=4.0.4` requires `analyzer ^12.0.0` which requires `meta ^1.18.0`, conflicting with Flutter SDK's pinned `meta 1.17.0`. The resolved versions are functionally equivalent.

- **compileSdk 36:** RESEARCH.md specified `compileSdk 34` but `flutter_secure_storage 10.3.1` and `shared_preferences_android` require SDK 36. Upgraded to eliminate build warnings.

- **Kotlin DSL:** Flutter 3.41.9 generates Kotlin DSL (`.gradle.kts`) by default. RESEARCH.md showed Groovy (`.gradle`) syntax. Values are equivalent; syntax adapted.

- **minSdk via flutter.minSdkVersion:** Flutter 3.41.9 Gradle plugin auto-rewrites explicit `minSdk = 23` to `minSdk = flutter.minSdkVersion` during each build. `flutter.minSdkVersion = 24` exceeds the required 23.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adjusted Riverpod version trio for Flutter 3.41.9 meta pin**
- **Found during:** Task 1 (package installation)
- **Issue:** `riverpod_generator ^4.0.4` requires `meta ^1.18.0` but Flutter 3.41.9 SDK pins `meta 1.17.0`. `flutter pub get` failed with version solving error.
- **Fix:** Downgraded to `flutter_riverpod ^3.3.1`, `riverpod_annotation 4.0.2`, `riverpod_generator 4.0.3` — latest stable triple compatible with Flutter 3.41.9.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`
- **Verification:** `flutter pub get` exits 0; all 8 Phase 1 packages resolved
- **Committed in:** `ca7c4da`

**2. [Rule 1 - Bug] Upgraded compileSdk from 34 to 36**
- **Found during:** Task 3 (`flutter build apk --debug`)
- **Issue:** `flutter_secure_storage 10.3.1`, `jni`, and `shared_preferences_android` require `compileSdk >= 35/36`. Build succeeded but emitted plugin warnings.
- **Fix:** Set `compileSdk = 36` in `build.gradle.kts`.
- **Files modified:** `android/app/build.gradle.kts`
- **Verification:** `flutter build apk --debug` succeeds with no warnings
- **Committed in:** `cb8ee3b`

**3. [Rule 1 - Bug] Fixed test/widget_test.dart referencing removed MyApp class**
- **Found during:** Task 3 (`flutter analyze`)
- **Issue:** Generated test referenced `MyApp` which was replaced by `ClaudePilotApp`. Caused analyzer error.
- **Fix:** Updated test to `ProviderScope(child: ClaudePilotApp())`, tests 'No machines yet' empty state.
- **Files modified:** `test/widget_test.dart`
- **Verification:** `flutter analyze` reports zero errors
- **Committed in:** `cb8ee3b`

---

**Total deviations:** 3 auto-fixed (all Rule 1 — version/build incompatibilities with Flutter 3.41.9)
**Impact on plan:** All fixes necessary for correctness with the installed Flutter version. No scope creep. Functional outcomes identical to plan specification.

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `MachineListScreen` — shows 'No machines yet' only | `lib/features/machines/screens/machine_list_screen.dart` | Intentional — full implementation in Plan 02 |
| `AddEditMachineScreen` — shows 'Add Machine' only | `lib/features/machines/screens/add_edit_machine_screen.dart` | Intentional — full implementation in Plan 02 |
| `TerminalScreen` — shows machineId only | `lib/features/terminal/screens/terminal_screen.dart` | Intentional — full implementation in Plan 03 |

These stubs satisfy Plan 01's stated goal (app boots to Machine List with dark theme). The plan explicitly specifies creating stub screens for routing compilation.

## Issues Encountered

- Flutter 3.41.9 Gradle plugin rewrites `minSdk = 23` to `minSdk = flutter.minSdkVersion` on every build. Effective value is 24 (Flutter's default), which exceeds the `flutter_secure_storage` requirement. Comment in `build.gradle.kts` documents the requirement for maintainability.

## Next Phase Readiness

- Plan 02 (Machine CRUD UI) can build on this skeleton — routing is wired, stub screens are in place
- Plan 03 (SSH + Terminal) has stub `TerminalScreen` with correct `machineId` parameter
- All package imports available: `dartssh2`, `xterm`, `flutter_riverpod`, `flutter_secure_storage`, `go_router`
- `build_runner` available for Riverpod code generation when `@riverpod` annotations are added in Plans 02/03

---
*Phase: 01-ssh-terminal*
*Completed: 2026-06-19*

## Self-Check: PASSED

All files present and all commits verified:
- pubspec.yaml: FOUND
- lib/main.dart: FOUND
- lib/app.dart: FOUND
- lib/core/theme/app_theme.dart: FOUND
- AndroidManifest.xml: FOUND
- build.gradle.kts: FOUND
- 01-01-SUMMARY.md: FOUND
- Commit ca7c4da: FOUND
- Commit d478c85: FOUND
- Commit cb8ee3b: FOUND
