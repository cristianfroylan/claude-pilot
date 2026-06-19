---
phase: 02-claude-code-remote
plan: "01"
subsystem: terminal/input-bar
tags: [flutter, input-bar, command-panel, quick-commands, ssh]
dependency_graph:
  requires: []
  provides: [sectioned-command-panel, text-chip-send]
  affects: [lib/features/terminal/widgets/input_bar.dart]
tech_stack:
  added: []
  patterns: [ActionChip-onPressed-isConnected-guard, local-sendText-closure, sectionHeader-helper, SingleChildScrollView-ConstrainedBox-panel]
key_files:
  modified:
    - lib/features/terminal/widgets/input_bar.dart
decisions:
  - "_TextCmd carries String command (not List<int> bytes) — mirrors _Cmd style but for text"
  - "sendText closure defined locally in build() — same scope pattern as existing send() closure"
  - "Panel stays open after text chip taps — no _commandsVisible = false in onPressed handlers"
  - "\\q stored as '\\\\q' Dart literal — renders as backslash-q in chip label"
  - "ConstrainedBox(maxHeight:240) + SingleChildScrollView wraps Container to prevent overflow"
metrics:
  duration: "1m 38s"
  completed: "2026-06-19"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
---

# Phase 2 Plan 01: Sectioned Command Panel Summary

Sectioned command panel with four labeled groups (Control/Claude/Shell/Session) where each text chip sends its command + newline to the PTY via the existing `sendText` method — zero new files, zero new packages.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add text-command model and section data constants | 01742d4 | input_bar.dart |
| 2 | Render sectioned scrollable command panel with one-tap text chips | 5c40075 | input_bar.dart |

## What Was Built

**Task 1** added the `_TextCmd` data class and three top-level `const` lists:
- `_claudeCommands` — `/clear`, `/compact`, `/help`, `/cost`, `/gsd` (CMD-01)
- `_shellCommands` — `cd ~`, `cd ..`, `ls`, `pwd` (CMD-02)
- `_sessionCommands` — `claude`, `claude .`, `exit`, `q`, `\q` (CMD-03 + CMD-04)

**Task 2** replaced the flat `Wrap` panel with a `ConstrainedBox(maxHeight: 240) → SingleChildScrollView → Container → Column` layout containing four labeled sections. Added local helpers `sectionHeader()` and `textChip()` inside `build()`. Added `sendText()` closure that appends `\n` and routes to `sshSessionProvider.notifier.sendText`.

Arrow keys remain in the main `Row` (CMD-05 intact). Panel stays open after taps (per CONTEXT.md Phase 1 decision).

## Requirements Delivered

| Requirement | Delivered |
|-------------|-----------|
| CMD-01 | /clear /compact /help /cost /gsd chips in Claude section |
| CMD-02 | cd ~ cd .. ls pwd chips in Shell section |
| CMD-03 | exit, q, \\q chips in Session section (both q and \\q per spec) |
| CMD-04 | claude, claude . chips in Session section |
| CMD-05 | Arrow keys unchanged in main InputBar row |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all chips wire directly to `sshSessionProvider.notifier.sendText`. No hardcoded empty values or placeholder text in the rendered output.

## Threat Flags

No new threat surface introduced. All command strings are compile-time constants (`_claudeCommands`, `_shellCommands`, `_sessionCommands`) — not user/network-derived. Consistent with T-02-01 and T-02-02 in the plan's threat register.

## Self-Check: PASSED

- [x] `lib/features/terminal/widgets/input_bar.dart` exists and modified
- [x] Commit 01742d4 exists (Task 1)
- [x] Commit 5c40075 exists (Task 2)
- [x] `flutter analyze lib/features/terminal/widgets/input_bar.dart` — No issues found
- [x] Four section headers (Control, Claude, Shell, Session) present
- [x] `sendText` closure with `\n` appended present
- [x] `SingleChildScrollView` + `maxHeight: 240` present
- [x] Arrow buttons in main row unchanged
- [x] `_commandsVisible` never set to false in text chip handlers
