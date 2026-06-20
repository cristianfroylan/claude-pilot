# Roadmap: claude-pilot

## Overview

Three phases deliver a Flutter SSH remote control for Claude Code. Phase 1 establishes a working SSH terminal — machines, connection, real terminal rendering, basic input. Phase 2 adds the features that make claude-pilot a Claude Code remote rather than a generic SSH client: quick commands, voice dictation, and permission approval cards. Phase 3 hardens the app for real-world daily use — stability under connection loss, PTY edge cases, iOS background behavior, and visual polish.

v2.0 (Phases 4–7) extends the working foundation with power-user features: robust reconnection with exponential backoff, biometric app lock, a session start picker for configured project folders, and multi-session tab navigation.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

### v1.0 — Core Remote Control (Phases 1–3)

- [x] **Phase 1: SSH Terminal** - Working SSH connection with real ANSI terminal and basic text input (completed 2026-06-19)
- [x] **Phase 2: Claude Code Remote** - Quick commands panel, voice dictation, and permission approval cards (completed 2026-06-19)
- [x] **Phase 3: Polish and Stability** - PTY resize hardening, iOS keepAlive, connection robustness, visual polish (completed 2026-06-19)

### v2.0 — Power User Features (Phases 4–7)

- [x] **Phase 4: Reconexión Robusta** - Exponential backoff reconnection with inline banner, attempt counter, and Terminal scrollback preservation (completed 2026-06-20)
- [ ] **Phase 5: Autenticación Biométrica** - Face ID/fingerprint app lock on cold launch and machine edit/delete, with background re-lock
- [ ] **Phase 6: Session Start Picker** - Per-machine working folder configuration and project picker sheet after SSH connects
- [ ] **Phase 7: Sesiones Múltiples con Tabs** - Independent SSH sessions per tab with dynamic tab strip, keepAlive session lifecycle, and isolated failure handling

## Phase Details

### Phase 1: SSH Terminal

**Goal**: Users can connect to a machine and interact with Claude Code via a real terminal
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: MACH-01, MACH-02, MACH-03, MACH-04, MACH-05, SSH-01, SSH-02, SSH-03, SSH-04, TERM-01, TERM-02, TERM-03, TERM-04, INP-01, INP-02, INP-03, INP-04
**Success Criteria** (what must be TRUE):

  1. User can add a machine with credentials and see it listed; credentials survive app restart encrypted
  2. User can tap a machine, watch the connection status change to "connected," and see live Claude Code output with full ANSI colors and cursor sequences rendered correctly
  3. User can type a prompt in the input bar, send it, and watch Claude Code respond in real time in the terminal
  4. User can interrupt a running process with Ctrl+C, close stdin with Ctrl+D, and send ESC — all without the app crashing when the SSH connection drops unexpectedly

**Plans:** 3/3 plans complete
Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Walking skeleton: Flutter project, packages, Android hardening, dark theme, routing

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Machine manager: add/edit/delete machines with encrypted credential storage

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-03-PLAN.md — SSH terminal: live ANSI session, InputBar, control signals, crash-safe disconnect

**UI hint**: yes

### Phase 2: Claude Code Remote

**Goal**: Users can control Claude Code from the phone without typing — quick commands, voice, and permission approvals
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: CMD-01, CMD-02, CMD-03, CMD-04, CMD-05, VOZ-01, VOZ-02, VOZ-03, VOZ-04, APRO-01, APRO-02, APRO-03
**Success Criteria** (what must be TRUE):

  1. User can open the quick commands panel and execute any slash command, navigation command, or session command with a single tap — including navigating shell history with up/down arrows
  2. User can hold the microphone button, dictate a prompt, release, review the transcribed text in the input field, and explicitly tap send — voice never auto-submits
  3. When Claude Code displays a permission prompt, a card appears automatically with Approve and Reject buttons that send the correct response to the terminal
  4. If voice recognition is unavailable on the device, the microphone button is hidden with no visible error

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 02-01-PLAN.md — Quick commands panel: sectioned Claude/Shell/Session text chips (one-tap send)
- [x] 02-02-PLAN.md — Permission approval card: stdout interception, detector provider, AnimatedSwitcher card

**Wave 2** *(blocked on Wave 1 — shares input_bar.dart with 02-01)*

- [x] 02-03-PLAN.md — Voice dictation: speech_to_text mic button, review bottom sheet, graceful unavailability

**UI hint**: yes

### Phase 3: Polish and Stability

**Goal**: The app survives real-world daily use without intervention — stable connections, correct PTY sizing in all orientations, and a polished visual experience
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: (no new v1 requirements — cross-cutting stability and UX work across all Phase 1 and Phase 2 features)
**Success Criteria** (what must be TRUE):

  1. Terminal text reflows correctly when the soft keyboard appears/disappears and when the device is rotated — no clipped diffs or permission cards from Claude Code
  2. SSH session remains alive after the app is backgrounded on iOS for at least 30 seconds and resumes without a manual reconnect
  3. Visual appearance is consistent: dark background, monospace font, readable on both Android and iOS without layout overflows or rendering glitches

**Plans**: 1/1 plans complete
**UI hint**: yes

### Phase 4: Reconexión Robusta

**Goal**: Users never lose work to a dropped connection — the app retries automatically with visible progress and preserves the terminal scrollback buffer throughout
**Depends on**: Phase 3
**Requirements**: RECON-01, RECON-02, RECON-03, RECON-04, RECON-05
**Success Criteria** (what must be TRUE):

  1. When the initial SSH connection fails, the user sees a retry counter and countdown timer (e.g. "Attempt 2/5 — retrying in 4s") without any manual action
  2. When a mid-session connection drops, an inline banner appears in the terminal view showing reconnection progress — the terminal history (scrollback) remains visible and intact throughout
  3. The user can tap a Cancel button at any point during automatic retries to stop the retry loop immediately
  4. After all automatic retries are exhausted, the user can tap a "Retry" button to attempt one more connection manually
  5. After a successful reconnection, the terminal scrollback buffer is unchanged — no prior output is lost or cleared

**Plans**: 3 plans

Plans:

**Wave 1**

- [x] 04-01-PLAN.md — SshSessionState sealed class (4 variants, Terminal carried) — the contract

**Wave 2** *(blocked on Wave 1 — consumes the sealed state type)*

- [x] 04-02-PLAN.md — Reconnection state machine in SshSession (retry loops, backoff, countdown, cancel/reconnect, drop detection) + update all consumers

**Wave 3** *(blocked on Wave 2 — shares terminal_screen.dart, needs cancel()/reconnect())*

- [x] 04-03-PLAN.md — Reconnection UI: overlay, inline banner, Retry, Reconnected SnackBar wired via Stack

**UI hint**: yes

### Phase 5: Autenticación Biométrica

**Goal**: The app is protected by the device's biometric or PIN authentication so unattended devices cannot expose SSH credentials or active sessions
**Depends on**: Phase 4
**Requirements**: BIO-01, BIO-02, BIO-03, BIO-04
**Success Criteria** (what must be TRUE):

  1. On cold launch, the user sees a lock screen and must authenticate with Face ID, fingerprint, or device PIN before reaching the machine list
  2. Before editing or deleting a saved machine's credentials, the user must re-authenticate biometrically — the edit form does not open until authentication succeeds
  3. If the app is sent to background and returns after more than 10 minutes, the lock screen reappears and requires re-authentication
  4. On a device with no biometric hardware enrolled, the OS PIN/password prompt appears automatically as fallback — no additional code path or degraded UI is shown

**Plans**: 3 plans

Plans:

**Wave 1**

- [x] 05-01-PLAN.md — Platform prerequisites + BiometricAuth provider (pubspec, Android FlutterFragmentActivity + USE_BIOMETRIC, iOS NSFaceIDUsageDescription, Riverpod keepAlive Notifier<bool>)

**Wave 2** *(blocked on Wave 1 — consumes biometricAuthProvider and local_auth package)*

- [ ] 05-02-PLAN.md — App root auth gate + LockScreen (app.dart ConsumerStatefulWidget, AppLifecycleListener 10-min timeout, LockScreen auto-trigger)
- [ ] 05-03-PLAN.md — Edit/delete auth gate (requireBiometric() utility, machine_list_screen.dart guard on onEdit/onDelete)

**UI hint**: yes

### Phase 6: Session Start Picker

**Goal**: Users can land in the right project directory immediately after connecting — no manual `cd` required
**Depends on**: Phase 5
**Requirements**: PICK-01, PICK-02, PICK-03, PICK-04
**Success Criteria** (what must be TRUE):

  1. When editing a machine, the user can add, reorder, and delete a list of working folder paths that are saved per machine
  2. After an SSH session connects (shell is ready), a picker sheet appears showing the configured folders; tapping a folder closes the sheet and the terminal immediately reflects the `cd <path>` command having been sent
  3. The user can dismiss the picker with a "Start blank" option to enter the session without any `cd` command
  4. If a machine has no configured folders, the session starts in blank mode directly — the picker sheet never appears

**Plans**: 2 plans

Plans:

**Wave 1**

- [ ] 06-01-PLAN.md — Machine model folderPaths extension + Component A folder editor in AddEditMachineScreen

**Wave 2** *(blocked on Wave 1 — consumes machine.folderPaths)*

- [ ] 06-02-PLAN.md — SessionPickerSheet widget + TerminalScreen conversion + picker trigger
**UI hint**: yes

### Phase 7: Sesiones Múltiples con Tabs

**Goal**: Users can run multiple independent Claude Code sessions simultaneously and switch between them without losing output or triggering reconnections
**Depends on**: Phase 6
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04
**Success Criteria** (what must be TRUE):

  1. The user can open a second SSH session (same or different machine) while the first remains active and connected — both sessions run independently with separate xterm buffers
  2. A tab strip is always visible with each tab showing the machine name; tapping a tab switches the terminal view without disconnecting or clearing the other session
  3. Each tab has a close button; tapping it disconnects that session's SSH cleanly and removes the tab — other tabs and their sessions are unaffected
  4. If a session in one tab drops, that tab shows a red error indicator and the last visible terminal output — all other tabs continue operating normally

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. SSH Terminal | 3/3 | Complete | 2026-06-19 |
| 2. Claude Code Remote | 3/3 | Complete | 2026-06-19 |
| 3. Polish and Stability | 1/1 | Complete | 2026-06-19 |
| 4. Reconexión Robusta | 3/3 | Complete   | 2026-06-20 |
| 5. Autenticación Biométrica | 1/3 | In Progress|  |
| 6. Session Start Picker | 0/? | Not started | - |
| 7. Sesiones Múltiples con Tabs | 0/? | Not started | - |
