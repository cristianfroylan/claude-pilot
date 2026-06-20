---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Power User Features
status: executing
stopped_at: Roadmap v2.0 created — Phases 4–7 defined
last_updated: "2026-06-20T21:32:19.616Z"
last_activity: 2026-06-20 -- Phase 04 planning complete
progress:
  total_phases: 7
  completed_phases: 3
  total_plans: 10
  completed_plans: 8
  percent: 43
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-20)

**Core value:** Enviar un prompt a Claude Code desde el teléfono y ver la respuesta llegar — sin abrir la laptop.
**Current focus:** Milestone v2.0 — Power User Features

## Current Position

Phase: Phase 4 — Reconexión Robusta (not started)
Plan: —
Status: Ready to execute
Last activity: 2026-06-20 -- Phase 04 planning complete

Progress: [████████░░] 80%

## Performance Metrics

**Velocity (v1.0):**

| Phase | Duration | Tasks | Files |
|-------|----------|-------|-------|
| Phase 02-claude-code-remote P01 | 98s | 2 tasks | 1 files |
| Phase 02-claude-code-remote P02 | 203s | 3 tasks | 6 files |
| Phase 02-claude-code-remote P03 | 8m | 3 tasks | 4 files |
| Phase 03-polish-and-stability P01 | 138s | 3 tasks | 4 files |
| Phase 04-reconexi-n-robusta P01 | 5m | 1 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Decisions carried from v1.0:

- [Init]: SSH directo (no bridge) — sin proceso extra en la PC
- [Init]: xterm.dart + dartssh2 (mismo autor, TerminalStudio) — wiring ~5 líneas
- [Init]: Riverpod AsyncNotifier.autoDispose.family(machineId) — SSHClient propiedad del notifier, cierre automático
- [Init]: Terminal de xterm ES el estado — sin wrapper extra, TerminalView consume directamente
- [Init]: Voz nunca auto-envía — transcript va al campo de texto para revisión explícita
- [v1]: keepAliveInterval set to 30s on SSHClient to prevent iOS TCP drop during backgrounding
- [v1]: SafeArea(top:true) wraps Scaffold body Column (not Scaffold) to avoid double padding with AppBar
- [v1]: ValueKey(keyboardHeight) on TerminalViewWrapper forces PTY reflow on keyboard/rotation events

v2.0 architecture decisions (from research):

- [v2]: Build order is Reconnection → Biometric → Picker → Tabs. SshSessionState sealed class (Phase 4) must be stable before any other feature touches sshSessionProvider consumers.
- [v2]: SshSession never emits AsyncLoading during reconnect — use AsyncData(SshReconnecting(...)) to preserve xterm Terminal scrollback buffer
- [v2]: @Riverpod(retry: false) on SshSession — prevents Riverpod 3 auto-retry stacking with custom backoff loop
- [v2]: biometricAuthProvider is keepAlive: true — autoDispose silently resets auth state during navigation transitions
- [v2]: ref.keepAlive() in SshSession.build() + keepAliveLink.close() on tab close — explicit session lifetime for tabs
- [v2]: Tabs use TabController + IndexedStack (native Flutter), not StatefulShellRoute — SSH sessions are runtime-created, static branch counts incompatible
- [v2]: Folder listing uses dartssh2 SFTP client.sftp().listdir(), not shell ls parsing — structured SftpName objects, no parsing fragility
- [v2]: minSdk raised from 23 to 24 for local_auth biometric requirement

### Pending Todos

- Verify Riverpod 3 @Riverpod(retry: false) annotation syntax before Phase 4 implementation
- Confirm local_auth 3.0.1 uses `persistAcrossBackgrounding` (not legacy `stickyAuth`) before Phase 5 implementation
- Verify StatefulShellRoute + Riverpod 3 TickerMode interaction on physical device during Phase 7 planning

### Blockers/Concerns

None at roadmap creation.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Personalización | PERS-01..02 (custom commands + visual theme) | v3 | Init |
| Acceso remoto | VPN/tunnel support | v3 | Init |
| Notificaciones push | Background alerts | v3 | Init |
| Tabs UX | Tab reorder by long-press drag | v3 | v2.0 research |
| Session picker | Git branch display in picker | v3 | v2.0 research |
| Tabs UX | Swipe left/right on terminal body to switch tabs | v3 | v2.0 research — conflicts with xterm horizontal scroll |

## Session Continuity

Last session: 2026-06-20T21:32:19.608Z
Stopped at: Roadmap v2.0 created — Phases 4–7 defined
Resume file: None
Next action: /gsd:plan-phase 4
