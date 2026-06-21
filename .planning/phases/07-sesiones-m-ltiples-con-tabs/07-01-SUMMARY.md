---
phase: 07-sesiones-m-ltiples-con-tabs
plan: "01"
subsystem: sessions-provider-layer
tags:
  - riverpod
  - keep-alive
  - ssh-sessions
  - multi-tab
dependency_graph:
  requires:
    - lib/features/terminal/providers/ssh_session_provider.dart
    - lib/core/models/machine.dart
  provides:
    - lib/features/sessions/models/session_tab.dart
    - lib/features/sessions/providers/sessions_provider.dart
    - lib/features/sessions/providers/sessions_provider.g.dart
  affects:
    - lib/features/terminal/providers/ssh_session_provider.dart
tech_stack:
  added: []
  patterns:
    - "ref.keepAlive() stored as void Function() closure — KeepAliveLink not in Riverpod 3 public API"
    - "SessionsNotifier (Notifier<SessionsState>, keepAlive:true) — tab list survives GoRouter transitions"
    - "closeAndDispose() teardown order: cancel() → SSH close → releaseKeepAlive()"
key_files:
  created:
    - lib/features/sessions/models/session_tab.dart
    - lib/features/sessions/providers/sessions_provider.dart
    - lib/features/sessions/providers/sessions_provider.g.dart
  modified:
    - lib/features/terminal/providers/ssh_session_provider.dart
decisions:
  - "KeepAliveLink stored as void Function() closure not as typed field — Riverpod 3 does not export KeepAliveLink in its public API (riverpod.dart / flutter_riverpod.dart show clause omits it); closure capture of _link.close achieves identical runtime behavior"
  - "flutter_riverpod import removed from sessions_provider.dart — riverpod_annotation re-exports all needed symbols; was flagged as unnecessary_import by analyzer"
metrics:
  duration: "325s (~5m 25s)"
  completed_date: "2026-06-21T00:00:32Z"
  tasks: 3
  files_created: 3
  files_modified: 1
---

# Phase 07 Plan 01: Provider Layer Foundation for Multi-Tab Sessions Summary

**One-liner:** Riverpod provider foundation for multi-tab SSH sessions — SessionTab/SessionsState models, keepAlive:true SessionsNotifier, and SshSession patched with explicit keepAlive lifecycle control via closure.

## Files Created/Modified

| File | Status | Lines | Description |
|------|--------|-------|-------------|
| `lib/features/sessions/models/session_tab.dart` | Created | 21 | SessionTab(id, machineId) + SessionsState(tabs, activeIndex, copyWith) — pure model, no imports |
| `lib/features/sessions/providers/sessions_provider.dart` | Created | 36 | Sessions Notifier<SessionsState> with @Riverpod(keepAlive:true); openTab/setActiveTab/closeTab |
| `lib/features/sessions/providers/sessions_provider.g.dart` | Generated | 62 | build_runner output; isAutoDispose:false confirms keepAlive:true applied correctly |
| `lib/features/terminal/providers/ssh_session_provider.dart` | Modified | 432 | Added _releaseKeepAlive field, ref.keepAlive() as first build() statement, closeAndDispose() method |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] KeepAliveLink is not exported in Riverpod 3's public API**

- **Found during:** Task 3 (flutter analyze after initial implementation)
- **Issue:** The plan specified `KeepAliveLink? _keepAliveLink` as the field type and `import 'package:flutter_riverpod/flutter_riverpod.dart'` to access it. However, `KeepAliveLink` is defined in `riverpod-3.2.1/lib/src/core/ref.dart` but NOT re-exported in `flutter_riverpod.dart` or `riverpod.dart` — it is absent from both packages' `show` clauses. flutter analyze reported `Undefined class 'KeepAliveLink'`.
- **Fix:** Changed field type from `KeepAliveLink? _keepAliveLink` to `void Function()? _releaseKeepAlive`. Stores `_link.close` (a `void Function()`) captured from the `KeepAliveLink` instance returned by `ref.keepAlive()`. The local variable `_link` has inferred type; `_link.close` is the teardown callback. Runtime behavior is identical — `_releaseKeepAlive?.call()` in `closeAndDispose()` releases the keepAlive.
- **Files modified:** `lib/features/terminal/providers/ssh_session_provider.dart`
- **Commit:** 7c3c3df

**2. [Rule 1 - Bug] Unnecessary flutter_riverpod import in sessions_provider.dart**

- **Found during:** Task 3 (flutter analyze)
- **Issue:** Plan specified `import 'package:flutter_riverpod/flutter_riverpod.dart'` in sessions_provider.dart for "KeepAliveLink type resolution." After discovering KeepAliveLink is not in the public API (deviation above), this import became unnecessary — `riverpod_annotation` re-exports all needed symbols. Analyzer flagged it as `unnecessary_import`.
- **Fix:** Removed the `flutter_riverpod` import from `sessions_provider.dart`.
- **Files modified:** `lib/features/sessions/providers/sessions_provider.dart`
- **Commit:** 7c3c3df (same commit as deviation 1)

## Flutter Analyze Output

```
Analyzing lib...
No issues found! (ran in 1.8s)
```

Full `lib/` directory clean. No warnings, no errors.

## build_runner Output

```
Built with build_runner/aot in 30s; wrote 10 outputs.
```

`sessions_provider.g.dart` produced successfully. Generated file contains `isAutoDispose: false` confirming `@Riverpod(keepAlive: true)` was applied.

## Threat Model Compliance

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-07-01 | `closeTab()` bounds check: `if (index < 0 \|\| index >= state.tabs.length) return;` | Applied |
| T-07-02 | All `_releaseKeepAlive` accesses via `?.call()` (null-safe); `ref.keepAlive()` called before any await | Applied |
| T-07-03 | `sessions_provider.g.dart` generated by build_runner — verified in Task 2 | Applied |
| T-07-SC | No new packages introduced | N/A |

## Known Stubs

None. This plan is a pure provider layer — no UI rendering, no data displayed to the user, no placeholder values.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

Files exist:
- FOUND: lib/features/sessions/models/session_tab.dart
- FOUND: lib/features/sessions/providers/sessions_provider.dart
- FOUND: lib/features/sessions/providers/sessions_provider.g.dart
- FOUND: lib/features/terminal/providers/ssh_session_provider.dart (modified)

Commits exist:
- FOUND: af33e31 — feat(07-01): add SessionTab and SessionsState value types
- FOUND: 1a6f3c6 — feat(07-01): add SessionsNotifier with keepAlive:true and openTab/setActiveTab/closeTab
- FOUND: 7c3c3df — feat(07-01): patch SshSession with keepAlive and closeAndDispose()
