---
phase: 04-reconexi-n-robusta
plan: "01"
subsystem: terminal/models
tags: [sealed-class, state-machine, dart3, xterm, riverpod]

dependency_graph:
  requires: []
  provides:
    - "SshSessionState sealed class with 4 exhaustive variants"
    - "Terminal carried in SshConnected, SshReconnecting, SshFailed"
  affects:
    - lib/features/terminal/providers/ssh_session_provider.dart  # Plan 02 consumes this type
    - lib/features/terminal/screens/terminal_screen.dart         # Plan 03 pattern-matches on this type

tech_stack:
  added: []
  patterns:
    - "Dart 3 sealed class for exhaustive pattern matching"
    - "Terminal instance carried in 3 of 4 variants to guarantee RECON-05 scrollback preservation"

key_files:
  created:
    - lib/features/terminal/models/ssh_session_state.dart
  modified: []

decisions:
  - "SshConnecting carries NO terminal field — pre-connection state has no xterm instance yet (avoids null carrying)"
  - "All three post-connection variants (SshConnected, SshReconnecting, SshFailed) expose terminal under exactly the field name `terminal` — enables `(:final terminal)` destructuring in Plan 03 Stack switch"
  - "No copyWith/==/toString generated — consumers read fields directly via pattern matching; not needed"
  - "Const constructors on all four variants — enables compile-time constant construction where applicable"

metrics:
  duration: "< 5 minutes"
  completed: "2026-06-20T21:31:37Z"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 04 Plan 01: SshSessionState Sealed Class Summary

**One-liner:** Dart 3 sealed class `SshSessionState` with four exhaustive variants — `SshConnecting` (no terminal, pre-connection), `SshConnected(terminal)`, `SshReconnecting(terminal, attempt, maxAttempts, secondsLeft)`, and `SshFailed(terminal)` — establishing the state contract all Phase 4 components implement against.

## What Was Built

Created `lib/features/terminal/models/ssh_session_state.dart` (80 lines), containing:

- `sealed class SshSessionState` with `const SshSessionState()` base constructor
- `SshConnecting` — 3 int fields (`attempt`, `maxAttempts`, `secondsLeft`), no terminal (RECON-01 overlay state)
- `SshConnected` — positional `const SshConnected(this.terminal)` (live session)
- `SshReconnecting` — 4 fields (`terminal`, `attempt`, `maxAttempts`, `secondsLeft`) (RECON-02 inline banner state)
- `SshFailed` — positional `const SshFailed(this.terminal)` (RECON-04 manual retry state)

All three variants carrying `Terminal` use the exact field name `terminal` so Plan 03's Stack switch can use `(:final terminal)` Dart 3 destructuring syntax uniformly.

## Verification

```
dart analyze lib/features/terminal/models/ssh_session_state.dart
No issues found!
```

Acceptance criteria:

| Check | Result |
|-------|--------|
| `grep -c "sealed class SshSessionState"` | 1 |
| `grep -cE "class SshConnecting\|class SshConnected\|class SshReconnecting\|class SshFailed"` | 4 |
| `grep -c "final Terminal terminal"` | 3 |
| `grep -c "import 'package:xterm/xterm.dart'"` | 1 |
| `dart analyze` errors | 0 |

## Commits

| Hash | Message |
|------|---------|
| a5b8990 | feat(04-01): add SshSessionState sealed class — 4 variants, terminal carried in 3 |

## Deviations from Plan

None — plan executed exactly as written. The sealed class matches RESEARCH.md Pattern 1 field-for-field.

## Known Stubs

None. This is a pure type definition file with no runtime behavior or data sources.

## Threat Flags

None. Pure in-process type definitions — no network endpoints, credential handling, storage access, or external trust boundaries introduced.

## Self-Check

- [x] `lib/features/terminal/models/ssh_session_state.dart` exists (80 lines, >40 min_lines requirement met)
- [x] Commit a5b8990 exists in git log
- [x] `dart analyze` reports no issues
- [x] All four acceptance criteria counts match

## Self-Check: PASSED
