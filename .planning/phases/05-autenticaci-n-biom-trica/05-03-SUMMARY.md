---
phase: 05-autenticaci-n-biom-trica
plan: "03"
subsystem: auth
tags: [biometric, local_auth, guard, riverpod, flutter]
dependency_graph:
  requires:
    - "05-01 (local_auth platform prerequisites + biometricAuthProvider)"
  provides:
    - requireBiometric() top-level async utility (biometric_guard.dart)
    - machine_list_screen.dart gated edit/delete (BIO-02)
  affects:
    - lib/features/auth/utils/biometric_guard.dart
    - lib/features/machines/screens/machine_list_screen.dart
tech_stack:
  added: []
  patterns:
    - "Top-level async utility function returning bool (no class, no static)"
    - "await requireBiometric() + context.mounted guard before navigation"
    - "PlatformException catch (local_auth 2.x API)"
key_files:
  created:
    - lib/features/auth/utils/biometric_guard.dart
  modified:
    - lib/features/machines/screens/machine_list_screen.dart
decisions:
  - "requireBiometric() is a top-level function (not static, not Riverpod) — mirrors _noRetry pattern in ssh_session_provider.dart"
  - "No biometricOnly parameter — defaults to false, OS PIN fallback automatic (BIO-04)"
  - "context.mounted guard on edit only (navigation uses BuildContext); delete is state mutation with no BuildContext usage"
  - "Gate at callsite (machine_list_screen.dart), not inside add_edit_machine_screen.dart — user never sees form before auth"
metrics:
  duration: "~5 minutes"
  completed: "2026-06-20"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 5 Plan 3: requireBiometric Guard + Machine List Edit/Delete Gates Summary

**One-liner:** Top-level requireBiometric() utility using local_auth 2.x gates both Edit and Delete taps on machine_list_screen.dart behind OS biometric/PIN prompt.

## What Was Built

### Task 1: requireBiometric() utility

Created `lib/features/auth/utils/biometric_guard.dart`:
- Single top-level async function `Future<bool> requireBiometric() async`
- Creates `LocalAuthentication()` instance, calls `auth.authenticate(localizedReason: 'Autentícate para modificar las credenciales')`
- No `biometricOnly` parameter — defaults to false so PIN-only devices receive OS PIN dialog (BIO-04 at zero extra cost)
- Catches `PlatformException` (local_auth 2.x API) and returns false — caller treats any exception as "no access"
- Does NOT import or reference `biometric_auth_provider.dart` — entirely separate concern (one-shot re-auth vs. app-level session state)
- `flutter analyze` reports no issues

### Task 2: Gate edit and delete in machine_list_screen.dart

Modified `lib/features/machines/screens/machine_list_screen.dart`:
- Added import: `import '../../auth/utils/biometric_guard.dart'`
- `onEdit` converted from synchronous arrow function to async function body: calls `await requireBiometric()`, then `if (ok && context.mounted)` before `context.push()`
- `onDelete` converted from synchronous arrow function to async function body: calls `await requireBiometric()`, then `if (ok)` before `ref.read(machineProvider.notifier).delete()`
- No `context.mounted` needed for delete (no BuildContext usage after the await)
- Widget class stays `ConsumerWidget` — no lifecycle or state needed at this callsite
- All other lines (AppBar, ListView.builder, FAB, _buildEmptyState) unchanged
- `flutter analyze` reports no issues

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 + Task 2 | c4165b4 | feat(05-03): requireBiometric guard + machine list edit/delete gates |

## Deviations from Plan

None — plan executed exactly as written.

Tasks 1 and 2 were committed together (both files are a single logical unit — the guard and its sole caller). This does not deviate from the plan's acceptance criteria.

## Known Stubs

None. requireBiometric() is wired directly to the live local_auth OS prompt. The edit and delete handlers are fully gated. No placeholder returns or hardcoded booleans.

## Threat Flags

No new threat surface beyond what is documented in the plan's threat model. Both T-05-08 and T-05-09 mitigations are implemented:
- T-05-08: requireBiometric() called before any action; gate is at the callsite (machine_list_screen.dart), not inside the destination
- T-05-09: `if (ok && context.mounted)` guards context.push; delete needs no mounted check
- T-05-10: biometricOnly defaults to false — OS PIN prompt fires automatically on PIN-only devices

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| lib/features/auth/utils/biometric_guard.dart exists | FOUND |
| requireBiometric() is a top-level function | CONFIRMED |
| PlatformException caught | CONFIRMED |
| localizedReason string present | CONFIRMED |
| biometric_guard.dart does not import biometric_auth_provider | CONFIRMED |
| machine_list_screen.dart imports biometric_guard.dart | CONFIRMED |
| onEdit awaits requireBiometric() with context.mounted guard | CONFIRMED |
| onDelete awaits requireBiometric() with if(ok) guard | CONFIRMED |
| flutter analyze lib/ — no errors | PASSED |
| Commit c4165b4 exists | FOUND |
