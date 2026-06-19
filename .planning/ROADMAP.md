# Roadmap: claude-pilot

## Overview

Three phases deliver a Flutter SSH remote control for Claude Code. Phase 1 establishes a working SSH terminal — machines, connection, real terminal rendering, basic input. Phase 2 adds the features that make claude-pilot a Claude Code remote rather than a generic SSH client: quick commands, voice dictation, and permission approval cards. Phase 3 hardens the app for real-world daily use — stability under connection loss, PTY edge cases, iOS background behavior, and visual polish.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: SSH Terminal** - Working SSH connection with real ANSI terminal and basic text input (completed 2026-06-19)
- [ ] **Phase 2: Claude Code Remote** - Quick commands panel, voice dictation, and permission approval cards
- [ ] **Phase 3: Polish and Stability** - PTY resize hardening, iOS keepAlive, connection robustness, visual polish

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

**Plans:** 2/3 plans executed

Plans:

**Wave 1**

- [x] 02-01-PLAN.md — Quick commands panel: sectioned Claude/Shell/Session text chips (one-tap send)
- [x] 02-02-PLAN.md — Permission approval card: stdout interception, detector provider, AnimatedSwitcher card

**Wave 2** *(blocked on Wave 1 — shares input_bar.dart with 02-01)*

- [ ] 02-03-PLAN.md — Voice dictation: speech_to_text mic button, review bottom sheet, graceful unavailability

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

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. SSH Terminal | 3/3 | Complete   | 2026-06-19 |
| 2. Claude Code Remote | 2/3 | In Progress|  |
| 3. Polish and Stability | 0/TBD | Not started | - |
