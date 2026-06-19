---
phase: 03-polish-and-stability
plan: "01"
subsystem: terminal
tags: [ssh, keepalive, layout, safearea, pty-resize, voice, scroll]
dependency_graph:
  requires: []
  provides:
    - SSH keepalive at 30s interval via dartssh2 SSHClient.keepAliveInterval
    - SafeArea(top:true) on TerminalScreen Scaffold body
    - PTY resize forced on keyboard/rotation via ValueKey(keyboardHeight)
    - VoiceBottomSheet scroll wrapper for small-screen safety
  affects:
    - lib/features/terminal/providers/ssh_session_provider.dart
    - lib/features/terminal/screens/terminal_screen.dart
    - lib/features/terminal/widgets/terminal_view_wrapper.dart
    - lib/features/terminal/widgets/voice_bottom_sheet.dart
tech_stack:
  added: []
  patterns:
    - ValueKey(keyboardHeight) to force TerminalViewWrapper rebuild on keyboard/rotation change
    - SafeArea(top: true, bottom: false) below AppBar to cover iOS notch without double-padding
    - SingleChildScrollView(physics: ClampingScrollPhysics) as overflow guard in bottom sheets
key_files:
  modified:
    - lib/features/terminal/providers/ssh_session_provider.dart
    - lib/features/terminal/screens/terminal_screen.dart
    - lib/features/terminal/widgets/terminal_view_wrapper.dart
    - lib/features/terminal/widgets/voice_bottom_sheet.dart
decisions:
  - keepAliveInterval set to 30s (not dartssh2 default 10s) per SSH-03 and CONTEXT.md decision
  - SafeArea wraps Column child of Scaffold body, not Scaffold itself, to avoid double top-padding with AppBar
  - MediaQuery.viewInsets.bottom read inside data: branch (not at widget build top level) to scope the rebuild dependency correctly
metrics:
  duration: "2m 18s"
  completed: "2026-06-19"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 4
---

# Phase 03 Plan 01: SSH Keepalive + PTY Resize + VoiceBottomSheet Scroll Summary

**One-liner:** SSH keepalive at 30s via dartssh2, PTY reflow on keyboard/rotation via ValueKey(keyboardHeight) + SafeArea(top:true), VoiceBottomSheet scroll guard for small screens.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SSH keepalive — add keepAliveInterval to SSHClient | 645b592 | ssh_session_provider.dart |
| 2 | PTY resize — SafeArea + MediaQuery viewInsets + ValueKey | 3d40e3e | terminal_screen.dart |
| 3 | Stale comment fix + VoiceBottomSheet SingleChildScrollView | e304a50 | terminal_view_wrapper.dart, voice_bottom_sheet.dart |

## What Was Built

### Task 1: SSH Keepalive
Added `keepAliveInterval: const Duration(seconds: 30)` as the fourth named argument to the `SSHClient` constructor in `_connectOnce`. This overrides the dartssh2 default (10s) with an explicit 30s interval, sending RFC 4254 SSH Global Request keepalive packets to prevent iOS from silently dropping the TCP connection during brief app backgrounding.

### Task 2: PTY Resize Robustness
Two coordinated edits to `terminal_screen.dart`:
- Wrapped the Scaffold `body:` `Column` in `SafeArea(top: true, bottom: false, left: false, right: false)` to prevent content rendering under the iOS notch. The `bottom: false` leaves home-indicator handling to other widgets; `AppBar` already absorbs the status bar inset so wrapping the `Column` (not the `Scaffold`) avoids double top-padding.
- Changed the `data:` branch of `sessionAsync.when()` from arrow syntax to a block body that reads `MediaQuery.of(context).viewInsets.bottom` and passes `key: ValueKey(keyboardHeight)` to `TerminalViewWrapper`. Reading `viewInsets.bottom` in `build()` registers a reactive dependency: when the keyboard appears, disappears, or the device rotates, Flutter rebuilds the widget, `TerminalViewWrapper` receives a new `ValueKey`, and its internal `LayoutBuilder` fires with fresh constraints that trigger the PTY resize.

### Task 3: Stale Comment + VoiceBottomSheet Scroll
- Corrected the stale comment on line 41 of `terminal_view_wrapper.dart` from "autofocus: false — the InputBar TextField owns keyboard focus" to the accurate description: "autofocus: true — TerminalView takes focus on tap; the soft keyboard opens and xterm handles key input. InputBar has no TextField." The value `autofocus: true` was already correct and was not touched.
- Wrapped the `VoiceBottomSheet` `Column` in `SingleChildScrollView(physics: const ClampingScrollPhysics())` inserted between `Padding` and `Column`. This prevents layout overflow on small devices (iPhone SE, ~600dp height) without changing the `Padding` or its `EdgeInsets.fromLTRB` (which includes the `viewInsets.bottom` adjustment). `ClampingScrollPhysics` matches Material bottom sheet behavior and avoids bounce scroll on Android.
- Confirmed `permission_card.dart` already has `overflow: TextOverflow.ellipsis` at line 57 — no edit was needed.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no placeholder text, hardcoded empty values, or unwired data sources introduced.

## Threat Flags

No new threat surface introduced. All changes are UI widget wrapping and an SSH transport parameter. The keepalive packets use the existing authenticated SSH session (T-03-01 — accepted). No new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

Files exist:
- lib/features/terminal/providers/ssh_session_provider.dart — FOUND
- lib/features/terminal/screens/terminal_screen.dart — FOUND
- lib/features/terminal/widgets/terminal_view_wrapper.dart — FOUND
- lib/features/terminal/widgets/voice_bottom_sheet.dart — FOUND

Commits exist:
- 645b592 feat(03-01): add explicit keepAliveInterval to SSHClient — FOUND
- 3d40e3e feat(03-01): add SafeArea + ValueKey(keyboardHeight) to TerminalScreen — FOUND
- e304a50 fix(03-01): fix stale autofocus comment + add scroll wrapper to VoiceBottomSheet — FOUND

Build: `flutter build apk --debug` — SUCCESS
Static analysis: `flutter analyze lib/features/terminal/` — 0 issues
