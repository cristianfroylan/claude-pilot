---
phase: 04-reconexi-n-robusta
plan: "03"
subsystem: terminal/reconnect-ui
tags: [reconnection, ui, overlay, banner, snackbar, flutter, riverpod]
dependency_graph:
  requires: [04-01, 04-02]
  provides: [reconnect-ui-widgets, terminal-screen-stack]
  affects: [lib/features/terminal/screens/terminal_screen.dart]
tech_stack:
  added: []
  patterns:
    - "Stack with always-mounted base layer for scrollback preservation (RECON-05)"
    - "Dart 3 if-case pattern matching for conditional Stack layers"
    - "ref.listen SnackBar on state transition (SshReconnecting→SshConnected)"
key_files:
  created:
    - lib/features/terminal/widgets/reconnect_overlay.dart
    - lib/features/terminal/widgets/reconnect_banner.dart
  modified:
    - lib/features/terminal/screens/terminal_screen.dart
decisions:
  - "ReconnectOverlay and ReconnectFailedOverlay share one file (both are overlays; file stays under 120 lines)"
  - "Banner uses Expanded(child: Text(...)) with overflow: ellipsis instead of Spacer to prevent overflow on narrow screens"
  - "Builder widget wraps the Stack to derive keyboardHeight once and keep switch expression clean"
  - "AlertDialog reference retained only as a comment ('No AlertDialog') — zero actual AlertDialog widgets"
metrics:
  duration: "2m48s"
  completed: "2026-06-20"
  tasks_completed: 2
  tasks_total: 3
  files_created: 2
  files_modified: 1
---

# Phase 04 Plan 03: Reconnection UI Summary

**One-liner:** Full reconnect UI — initial-connect overlay with spinner/countdown/Cancel, mid-session top-pinned banner, exhausted-retries Retry screen, and post-reconnect SnackBar, all via a Stack that keeps TerminalViewWrapper always mounted.

## What Was Built

### Task 1 — ReconnectOverlay and ReconnectBanner widgets (`22263ea`)

**`lib/features/terminal/widgets/reconnect_overlay.dart`** — two stateless widgets:

- `ReconnectOverlay`: full-screen scrim (`colorScheme.surface` at 0.85 opacity) with `CircularProgressIndicator`, locked copy `'Attempt $attempt/$maxAttempts — retrying in ${secondsLeft}s'` (em-dash, countdown collapses to `'…connecting…'` when `secondsLeft <= 0`), and an `OutlinedButton('Cancel')` calling `onCancel`.
- `ReconnectFailedOverlay`: same scrim with `Icons.cloud_off`, `'Connection lost'` title, `'All retry attempts failed.'` subtitle, and `FilledButton('Retry')` calling `onRetry` (RECON-04).

**`lib/features/terminal/widgets/reconnect_banner.dart`** — one stateless widget:

- `ReconnectBanner`: `AnimatedContainer(duration: 200ms)` at height 44, `colorScheme.errorContainer` background, compact `Row` with 14×14 `CircularProgressIndicator(strokeWidth: 2)`, locked copy `'Connection lost · Attempt $attempt/$maxAttempts · Retry in ${secondsLeft}s'` (middle-dot separators, `onErrorContainer` color, `TextOverflow.ellipsis`), and `TextButton('Cancel')` calling `onCancel`. Wrapped in `Material + SafeArea(top: true)` to avoid status bar collision.

Both files use only existing `colorScheme` tokens from `AppTheme`. `dart analyze` on both reports zero issues.

### Task 2 — Stack wired into TerminalScreen (`a57841a`)

Replaced the `Expanded(child: switch(...))` body with `Expanded(child: Builder(builder: (context) { ... Stack ... }))`:

**Stack layers (bottom to top):**
1. **Base layer** — `switch (sessionState)` selects `TerminalViewWrapper(key: ValueKey(keyboardHeight), ...)` for `SshConnected | SshReconnecting | SshFailed`; `CircularProgressIndicator` for `SshConnecting | null`. Key is `ValueKey(keyboardHeight)` only — no session state — so reconnection never forces a TerminalViewWrapper remount (RECON-05).
2. **Banner layer** — `if (sessionState case SshReconnecting(...))` → `Positioned(top:0, left:0, right:0, child: ReconnectBanner(..., onCancel: notifier.cancel()))`.
3. **Initial overlay layer** — `if (sessionState case SshConnecting(...))` → `ReconnectOverlay(..., onCancel: notifier.cancel())`.
4. **Failed overlay layer** — `if (sessionState is SshFailed)` → `ReconnectFailedOverlay(onRetry: notifier.reconnect())`.

**`ref.listen` updated:**
- `SshReconnecting → SshConnected` → `SnackBar('Reconnected', duration: Duration(seconds: 2))`
- `SshFailed` (first time) → existing `SnackBar('Could not connect to $machineName.')` kept.
- No `AlertDialog` anywhere.

`dart analyze lib` reports zero issues.

## Deviations from Plan

**None** — plan executed exactly as written. Minor implementation notes:

- Used `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))` instead of `Spacer` in `ReconnectBanner` to handle narrow-screen overflow gracefully. This is a presentational refinement within the plan's discretion scope.
- `Builder` widget wraps the Stack in `TerminalScreen` to derive `keyboardHeight` and `sessionState` once in a clean local scope — avoids repeated `MediaQuery.of(context)` calls and keeps the switch expression readable.

## Task 3 — DEFERRED (checkpoint:human-verify)

Task 3 is a `checkpoint:human-verify` gate requiring manual device testing on a real LAN device. This checkpoint was reached during autonomous execution and is **deferred for manual verification**.

**Manual testing required (RECON-01 through RECON-05):**
1. `flutter run` on a device/emulator on the same LAN as a configured machine.
2. **RECON-01** (initial failure): configure a machine with wrong port, tap it. Confirm overlay shows `'Attempt 1/5 — retrying in Xs'`, counter advances, Cancel visible.
3. **RECON-03** (cancel): tap Cancel during countdown. Confirm retries stop and Retry screen appears.
4. **RECON-04** (manual retry): tap Retry. Confirm one more attempt fires.
5. **RECON-02 + RECON-05** (mid-session drop): connect to real machine, run `claude`, drop connection (disable Wi-Fi or restart sshd). Confirm inline banner at top with `'Connection lost · Attempt N/3 · Retry in Xs'` and scrollback fully visible below.
6. Re-enable network. Confirm `'Reconnected'` SnackBar appears for ~2s and scrollback is unchanged.
7. Confirm no AlertDialog and no crash on any disconnect path.

**Signal to mark complete:** Type `"approved"` or describe any issue (wrong copy, scrollback cleared, banner not showing, crash).

## Known Stubs

None. All widget props are driven by live provider state (`sessionAsync.value` pattern-matched in TerminalScreen). No hardcoded empty values or placeholder text in the data path.

## Threat Flags

None. This plan is purely presentational — no new network endpoints, no credential handling, no storage access, no user input parsing. The Cancel/Retry buttons call existing notifier methods already present from Plans 04-01 and 04-02.

## Self-Check: PASSED

- `lib/features/terminal/widgets/reconnect_overlay.dart` — exists, contains `ReconnectOverlay` and `ReconnectFailedOverlay`
- `lib/features/terminal/widgets/reconnect_banner.dart` — exists, contains `ReconnectBanner`
- `lib/features/terminal/screens/terminal_screen.dart` — modified, contains `Stack`, all three widget usages, `Reconnected` SnackBar
- `dart analyze lib` — zero issues
- Commits: `22263ea` (Task 1), `a57841a` (Task 2)
