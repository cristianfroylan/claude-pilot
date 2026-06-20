---
phase: 04-reconexi-n-robusta
verified: 2026-06-20T23:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "The app compiles with zero dart analyze errors — permission_detector_provider.dart:33 .select() call replaced with direct .value type-check pattern; dart analyze lib now reports 0 errors (only warnings from generated code and 1 info-level deprecation notice, both acceptable)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "RECON-01 — Initial connection failure overlay"
    expected: "Connect to a machine with a wrong port. The overlay shows 'Attempt 1/5 — retrying in Xs', the counter advances to 2/5, 3/5…, the seconds count down to zero between attempts, and a Cancel button is always visible."
    why_human: "Requires running the app on a device/emulator connected to a LAN. Countdown timing and visual overlay rendering cannot be verified by grep or dart analyze."
  - test: "RECON-03 — Cancel stops retry loop immediately"
    expected: "During any countdown, tap Cancel. Retries stop, the ReconnectFailedOverlay appears with a Retry button. No further connection attempts fire."
    why_human: "Interactive user action — requires physical or emulated tap event."
  - test: "RECON-04 — Manual Retry after exhaustion"
    expected: "On the ReconnectFailedOverlay, tap Retry. Exactly one connection attempt fires (no loop), then either SshConnected or SshFailed results."
    why_human: "Requires observing exactly one reconnect attempt — timing and count are not verifiable statically."
  - test: "RECON-02 — Mid-session inline banner with scrollback visible"
    expected: "Connect to a real machine, run claude or another command so terminal has scrollback. Drop the connection (disable Wi-Fi or restart sshd). The inline ReconnectBanner appears pinned to the top; the prior terminal scrollback output is fully visible below it. No full-screen overlay replaces the terminal."
    why_human: "Requires LAN device, live SSH session, and network disruption. Scrollback preservation is a visual/runtime property."
  - test: "RECON-05 — Scrollback unchanged after successful reconnect"
    expected: "After reconnection succeeds, the 'Reconnected' SnackBar appears for ~2s and the terminal scrollback is exactly as before — no prior output is cleared or replaced."
    why_human: "Visual and runtime property — requires inspecting the xterm buffer content after a reconnect cycle on a real device."
  - test: "No AlertDialog or crash on any disconnect path"
    expected: "Under all tested scenarios (initial failure, mid-session drop, cancel, manual retry, exhausted retries) no AlertDialog appears and the app does not crash."
    why_human: "Cross-scenario stability check requires exercise of all reconnect paths on device."
---

# Phase 4: Reconexión Robusta — Verification Report

**Phase Goal:** Users never lose work to a dropped connection — the app retries automatically with visible progress and preserves the terminal scrollback buffer throughout.
**Verified:** 2026-06-20T23:00:00Z
**Status:** HUMAN_NEEDED — all automated checks pass; 6 device-level scenarios require human testing
**Re-verification:** Yes — after gap closure (compile error in permission_detector_provider.dart fixed)

---

## Re-verification Summary

| Item | Previous | Now |
|------|----------|-----|
| Compile error (`permission_detector_provider.dart:33`) | BLOCKER — `.select()` undefined_method | CLOSED — replaced with `.value is SshConnected \|\| ...` pattern |
| `dart analyze lib` errors | 1 error | 0 errors |
| Overall status | `gaps_found` | `human_needed` |
| Score | 4/5 (all UNCERTAIN due to compile block) | 5/5 (all VERIFIED structurally) |
| Regressions | — | None detected |

---

## Automated Gate: dart analyze

```
dart analyze lib

Analyzing lib...
  warning - features/machines/providers/machines_provider.g.dart (generated — acceptable)
  warning - features/terminal/providers/permission_detector_provider.g.dart (generated — acceptable)
  warning - features/terminal/providers/ssh_session_provider.g.dart (generated — acceptable)
  info    - features/terminal/providers/permission_detector_provider.dart:53 — RegExp deprecation notice (info only)

0 errors found.
```

All warnings are in generated `.g.dart` files (`$Ref`, `$ClassProviderElement`, `$Family`, `$ClassFamilyOverride` from riverpod_generator) and are expected/acceptable for this Riverpod 3.x + riverpod_generator 4.x setup. The one `info`-level notice (`RegExp` deprecation) is in hand-written code but is not an error and does not affect compilation or runtime.

**Automated gate: PASSED.**

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | When initial SSH connection fails, the user sees a retry counter and countdown timer ("Attempt N/5 — retrying in Xs") without manual action | VERIFIED (structural) | `SshConnecting` state carries `attempt`, `maxAttempts`, `secondsLeft`; `_initialBackoff = [1,2,4,8,16]`; `_waitWithCountdown` drives `Timer.periodic` updates; `ReconnectOverlay` renders `'Attempt $attempt/$maxAttempts — retrying in ${secondsLeft}s'` (line 35); wired into `TerminalScreen` Stack layer 3 |
| 2 | When a mid-session connection drops, an inline banner appears in the terminal view — terminal history remains visible throughout | VERIFIED (structural) | `_installDoneWatcher()` triggers `_runMidSessionRetry()`; `SshReconnecting` carries `terminal` field (RECON-05); `ReconnectBanner` renders `'Connection lost · Attempt $attempt/$maxAttempts · Retry in ${secondsLeft}s'`; pinned via `Positioned(top:0)` in Stack — `TerminalViewWrapper` base layer remains mounted |
| 3 | The user can tap a Cancel button at any point during automatic retries to stop the retry loop immediately | VERIFIED (structural) | `cancel()` sets `_cancelRequested = true` and cancels `_countdownTimer`; checked at every loop iteration (`if (_cancelRequested \|\| _disposed)`); `onCancel` prop wired from both `ReconnectOverlay` (line 198) and `ReconnectBanner` (line 180) to `.notifier.cancel()` |
| 4 | After all automatic retries are exhausted, the user can tap a "Retry" button to attempt one more connection manually | VERIFIED (structural) | `ReconnectFailedOverlay` has `FilledButton(onPressed: onRetry)` (line 103); `onRetry` wired to `.notifier.reconnect()` (line 205); `reconnect()` runs a single `_connectOnce()` call without a loop; `_isMidSession` flag determines which connecting state to emit |
| 5 | After a successful reconnection, the terminal scrollback buffer is unchanged — no prior output is lost or cleared | VERIFIED (structural) | `_terminal` is an instance field (`Terminal? _terminal`), created exactly once via `_terminal ??= Terminal(maxLines: 2000)` (line 87); passed through every state variant that has a terminal; `TerminalViewWrapper` uses `ValueKey(keyboardHeight)` — not session state — so it never remounts; `SshConnected`, `SshReconnecting`, `SshFailed` all carry the same `_terminal!` reference |

**Score:** 5/5 truths verified at code level.

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/terminal/models/ssh_session_state.dart` | Sealed class with 4 variants, Terminal in 3 | VERIFIED | 81 lines; `sealed class SshSessionState`; 4 variants confirmed (`SshConnecting`, `SshConnected`, `SshReconnecting`, `SshFailed`); `final Terminal terminal` in 3 variants; imports `package:xterm/xterm.dart` |
| `lib/features/terminal/providers/ssh_session_provider.dart` | Full state machine with retry loops, backoff, cancel, reconnect | VERIFIED | `Future<SshSessionState> build`; `_initialBackoff = [1,2,4,8,16]`; `_midSessionBackoff = [2,4,8]`; `void cancel()`; `Future<void> reconnect()`; `Terminal? _terminal`; `_terminal ??= Terminal(maxLines: 2000)`; `_connectionGeneration` guard; `_runMidSessionRetry`; `@Riverpod(retry: _noRetry)` |
| `lib/features/terminal/providers/permission_detector_provider.dart` | Permission detector using SshSessionState variants — no .select() | VERIFIED | `.select()` removed; `ref.watch(sshSessionProvider(machineId)).value` + `is SshConnected \|\| is SshReconnecting \|\| is SshFailed` type check; comment documents the accepted CR-02 limitation; dart analyze: 0 errors |
| `lib/features/terminal/widgets/reconnect_overlay.dart` | ReconnectOverlay + ReconnectFailedOverlay with locked copy | VERIFIED | `class ReconnectOverlay` and `class ReconnectFailedOverlay`; locked copy `'Attempt $attempt/$maxAttempts — retrying in ${secondsLeft}s'` (line 35); `onCancel` param + `OutlinedButton`; `onRetry` param + `FilledButton`; uses `colorScheme` tokens only |
| `lib/features/terminal/widgets/reconnect_banner.dart` | ReconnectBanner with locked copy and AnimatedContainer | VERIFIED | `class ReconnectBanner`; locked copy `'Connection lost · Attempt $attempt/$maxAttempts · Retry in ${secondsLeft}s'` (line 36); `AnimatedContainer(duration: Duration(milliseconds: 200))`; height 44; `colorScheme.errorContainer`; `onCancel` param + `TextButton`; `Material + SafeArea(top: true)` wrapper |
| `lib/features/terminal/screens/terminal_screen.dart` | Stack with 4 layers, cancel/reconnect wired, Reconnected SnackBar | VERIFIED | `Stack(children: [...])` with 4 layers; `ReconnectOverlay` (SshConnecting); `ReconnectBanner` via `Positioned(top:0)` (SshReconnecting); `ReconnectFailedOverlay` (SshFailed); `TerminalViewWrapper(key: ValueKey(keyboardHeight))` base layer; `.cancel()` from both overlay and banner; `.reconnect()` from failed overlay; `SnackBar('Reconnected', duration: 2s)` on `SshReconnecting→SshConnected`; no `AlertDialog` in source |
| `lib/features/terminal/widgets/input_bar.dart` | isConnected gated on SshConnected only | VERIFIED | `final stateValue = ref.watch(sshSessionProvider(widget.machineId)).value; final isConnected = stateValue is SshConnected;` (lines 130–131) |
| `lib/features/terminal/providers/permission_detector_provider.g.dart` | Regenerated with correct family types | VERIFIED | `$StreamNotifierProvider<PermissionDetector, String?>`; `PermissionDetectorFamily`; no `.select()` artifacts |
| `lib/features/terminal/providers/ssh_session_provider.g.dart` | Regenerated with SshSessionState type | VERIFIED | `$AsyncNotifierProvider<SshSession, SshSessionState>` confirmed; `retry: _noRetry` in generated code |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ssh_session_provider.dart` | `ssh_session_state.dart` | import + `Future<SshSessionState> build` | WIRED | Import line 11; `Future<SshSessionState> build` line 74 |
| `ssh_session_provider.dart` | `SSHClient.done` | `_installDoneWatcher()` + generation guard | WIRED | `_client!.done.then(...)` with `gen == _connectionGeneration` guard |
| `terminal_screen.dart` | `ssh_session_provider.dart` | `cancel()` from overlay/banner `onCancel` | WIRED | Lines 179–182 (banner), 197–199 (overlay) call `.notifier.cancel()` |
| `terminal_screen.dart` | `ssh_session_provider.dart` | `reconnect()` from failed overlay `onRetry` | WIRED | Lines 205–207 call `.notifier.reconnect()` |
| `terminal_screen.dart` | SshReconnecting→SshConnected | `ref.listen` fires Reconnected SnackBar | WIRED | Lines 53–59: `if (prevState is SshReconnecting && nextState is SshConnected)` → SnackBar |
| `permission_detector_provider.dart` | `ssh_session_provider.dart` | `ref.watch(...).value` type-check | WIRED | `ref.watch(sshSessionProvider(machineId)).value` + `is SshConnected \|\| is SshReconnecting \|\| is SshFailed` — no analyzer error |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `reconnect_overlay.dart` | `attempt`, `maxAttempts`, `secondsLeft` | Props from `TerminalScreen` driven by `SshConnecting` state from provider | Yes — populated by real retry loop in `_waitWithCountdown` via `Timer.periodic` | FLOWING |
| `reconnect_banner.dart` | `attempt`, `maxAttempts`, `secondsLeft` | Props from `TerminalScreen` driven by `SshReconnecting` state | Yes — populated by `_runMidSessionRetry` countdown | FLOWING |
| `reconnect_overlay.dart` (ReconnectFailedOverlay) | `onRetry` callback | `notifier.reconnect()` — attempts real SSH via `_connectOnce()` | Yes — calls real SSH stack (`SSHSocket.connect` + `SSHClient`) | FLOWING |
| `terminal_screen.dart` | `sessionState` | `sessionAsync.value` from `sshSessionProvider` | Yes — live `AsyncValue<SshSessionState>` from notifier | FLOWING |
| `permission_detector_provider.dart` | `isActive` | `ref.watch(sshSessionProvider(machineId)).value` | Yes — reflects live session state type; rebuilds on every 1-Hz countdown tick (accepted limitation) | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — app requires a physical device on a LAN and a real SSH host to exercise connection behavior. No locally runnable entry points can validate reconnection logic without live network infrastructure. These checks are handled by the human verification section below.

---

## Probe Execution

No probe scripts found in `scripts/*/tests/probe-*.sh`. The automated gate for this phase is `dart analyze lib`. Result: **0 errors** (PASSED).

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| RECON-01 | 04-01, 04-02, 04-03 | Fallar conexión inicial → reintentar hasta 5x con backoff 1→2→4→8→16s, mostrando intento y tiempo de espera | VERIFIED (structural) / HUMAN-PENDING (runtime) | `_initialBackoff = [1,2,4,8,16]`; `_waitWithCountdown`; `SshConnecting` state; `ReconnectOverlay` with locked copy |
| RECON-02 | 04-02, 04-03 | Sesión activa caída → reintentar 3x con banner inline en terminal | VERIFIED (structural) / HUMAN-PENDING (runtime) | `_runMidSessionRetry()`; `_midSessionBackoff = [2,4,8]`; `ReconnectBanner` pinned via `Positioned(top:0)` |
| RECON-03 | 04-02, 04-03 | Usuario puede cancelar reintentos con botón visible | VERIFIED (structural) / HUMAN-PENDING (runtime) | `cancel()` sets `_cancelRequested`; wired from both overlay and banner; `_countdownTimer` cancelled immediately |
| RECON-04 | 04-02, 04-03 | Tras agotar reintentos automáticos, usuario puede forzar reintento manual | VERIFIED (structural) / HUMAN-PENDING (runtime) | `reconnect()` on notifier; single `_connectOnce()` call — no loop; wired to `ReconnectFailedOverlay.onRetry` |
| RECON-05 | 04-01, 04-02, 04-03 | Scrollback preservado durante y después de reconexión — xterm buffer no se limpia | VERIFIED (structural) / HUMAN-PENDING (runtime) | `_terminal` instance field; `??=` initialization; passed through all state variants; `TerminalViewWrapper` key is `ValueKey(keyboardHeight)` |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `permission_detector_provider.dart` | 53 | `RegExp` deprecation (`info` level only) | INFO | No functional impact; `RegExp` works as before; not a compilation error; no action required before ship |

No debt markers (TBD, FIXME, XXX) found in any phase-modified file.
No empty implementations (return null, return [], placeholder text) found in rendering paths.
No hardcoded empty props at call sites.
Previous BLOCKER (`.select()` undefined_method) is closed.

---

## Human Verification Required

### 1. RECON-01: Initial Connection Failure Overlay

**Test:** Add a machine with a wrong port (e.g. 2222 when sshd is not listening there), then tap it to connect.
**Expected:** The overlay shows "Attempt 1/5 — retrying in Xs". The counter advances (2/5, 3/5…) with each attempt. The seconds count down within each attempt. A Cancel button is always visible and tappable.
**Why human:** Requires running the Flutter app on a device/emulator on a LAN. Countdown timing and overlay rendering are runtime visual properties.

### 2. RECON-03: Cancel Stops Retry Loop Immediately

**Test:** During any countdown in RECON-01, tap the Cancel button.
**Expected:** Retries stop before the next attempt fires. The `ReconnectFailedOverlay` appears with a Retry button. No further connection attempts are made.
**Why human:** Interactive user action — requires physical or emulated tap event and observation of state transitions.

### 3. RECON-04: Manual Retry After Exhaustion

**Test:** On the `ReconnectFailedOverlay` (after all retries exhausted or after Cancel), tap Retry.
**Expected:** Exactly one connection attempt fires (no loop). Result is either `SshConnected` (terminal becomes active) or `SshFailed` (failed overlay remains). The "Retry" button does not trigger a new 5-attempt loop.
**Why human:** Requires observing that exactly one attempt fires — count and timing are not verifiable statically.

### 4. RECON-02: Mid-Session Inline Banner with Scrollback Visible

**Test:** Connect to a real machine, run `claude` or any command so the terminal has visible scrollback. Drop the connection (disable Wi-Fi, airplane mode, or `sudo systemctl restart sshd` on the host).
**Expected:** The inline `ReconnectBanner` appears pinned to the top showing "Connection lost · Attempt N/3 · Retry in Xs". The prior scrollback output is fully visible below the banner. No full-screen overlay replaces the terminal content. The banner shows up to 3 attempts with backoff 2s/4s/8s.
**Why human:** Requires LAN device, live SSH session, and network disruption. Scrollback visibility during reconnect is a visual/runtime property.

### 5. RECON-05: Scrollback Unchanged After Successful Reconnect

**Test:** After reconnection succeeds (or after manually tapping Retry successfully), observe the terminal.
**Expected:** A "Reconnected" SnackBar appears for approximately 2 seconds. The terminal scrollback content is exactly what it was before the disconnect — no lines cleared, no blank screen, no duplication.
**Why human:** Requires comparing visual terminal state before and after reconnect. xterm buffer integrity is a runtime property.

### 6. No AlertDialog or Crash on Any Disconnect Path

**Test:** Exercise all disconnect scenarios: initial failure (all 5 retries exhausted), mid-session drop (all 3 retries exhausted), cancel during initial, cancel during mid-session, manual retry success, manual retry failure.
**Expected:** No `AlertDialog` appears at any point. The app does not crash, hang, or show a blank screen. Every scenario ends in either `SshConnected` or `SshFailed` state with the appropriate UI (SnackBar or overlay).
**Why human:** Cross-scenario stability requires exercising all code paths on a real device.

---

## Gaps Summary

No gaps. The single automated blocker from the initial verification (`.select()` compile error in `permission_detector_provider.dart`) is closed. All five success criteria are structurally verified. Six human device-level scenarios remain as required end-of-phase testing per Plan 04-03 Task 3.

---

_Verified: 2026-06-20T23:00:00Z_
_Verifier: Claude (gsd-verifier)_
