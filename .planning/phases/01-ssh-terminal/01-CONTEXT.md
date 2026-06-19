# Phase 1: SSH Terminal - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 delivers the foundational Flutter app: a machine manager screen where users add/edit/delete SSH machines with encrypted credentials, and a terminal screen that opens a real SSH PTY session and streams Claude Code output with full ANSI fidelity. The user can type prompts in an input bar and send control signals (Ctrl+C, Ctrl+D, ESC). The app must not crash when the SSH connection drops unexpectedly.

Requirements in scope: MACH-01..05, SSH-01..04, TERM-01..04, INP-01..04

</domain>

<decisions>
## Implementation Decisions

### App Navigation & Structure
- Navigation system: `go_router` — declarative routing, deep-link ready, current Flutter standard
- Directory layout: feature-first — `lib/features/machines/` and `lib/features/terminal/`
- Entry point: `ProviderScope` wraps `MaterialApp.router` in `main.dart`
- Material version: Material 3 with `useMaterial3: true` and a dark `ColorScheme`

### Machine Manager UI
- Machine list: full-page `ListView` with a FAB to add new machines
- Add/edit machine: dedicated page (`/machines/add`, `/machines/:id/edit`) — more room for form fields than a bottom sheet
- Connection status indicator: colored dot + text label (connected = green, disconnected = grey, error = red)
- Credential entry: username + password fields only (v1 constraint — no passphrase/key support)

### Terminal Screen Layout
- Layout: `Column` — `Expanded(TerminalView)` fills the available height; `InputBar` pinned at bottom, sits above the software keyboard via `resizeToAvoidBottomInset: true`
- PTY sizing: computed from `MediaQuery` at mount — `columns = width ~/ 8`, `rows = availableHeight ~/ 16`; wired to `xterm.Terminal.onResize` → `session.resizeTerminal()`; updated on `LayoutBuilder` changes
- App bar: minimal `AppBar` showing machine name + disconnect `IconButton` — connection state must remain visible; no fullscreen immersive
- Scrollback: xterm.dart built-in buffer (default 1000 lines)

### Input Bar Controls
- Control buttons: horizontal `Row` of chip-style buttons above the text field — Ctrl+C, Ctrl+D, ESC
- Send button: always visible `IconButton` at end of text field row
- Input field: single-line `TextField` with `TextInputAction.send`; `onSubmitted` fires same handler as send button
- Keyboard dismiss: Android back dismisses keyboard only; disconnect is an explicit AppBar action

### Claude's Discretion
- Exact color values for dark theme (background, surface, terminal bg) — use Material 3 dark baseline or xterm.dart default colors
- Exact font size and padding for input bar
- Error/loading states UI (connecting spinner, error snackbar vs. inline message)
- Whether to show a confirmation dialog before deleting a machine

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — greenfield project. No existing Flutter code.

### Established Patterns
- None yet — this phase establishes all patterns for the project.

### Integration Points
- `pubspec.yaml` to be created with: `dartssh2`, `xterm`, `flutter_riverpod`, `flutter_secure_storage`, `shared_preferences`, `go_router`
- `AndroidManifest.xml`: needs `android:allowBackup="false"` before any test restore
- `Info.plist` (iOS): no special keys needed for Phase 1 (voice permissions are Phase 2)

</code_context>

<specifics>
## Specific Ideas

- SSHStateError crash (Transport is closed) must be handled from day one: wrap `session.done` + `client.done` in try-catch; Riverpod `onDispose` closes connection
- PTY initial size: default 80×24 until first autoResize; `terminal.onResize` → `session.resizeTerminal()` wiring confirmed
- dartssh2 + xterm.dart are from the same author (TerminalStudio) — the xterm.dart repo has an official SSH example (`example/lib/ssh.dart`) that demonstrates the exact wiring; use it as the reference implementation
- Machine metadata (name, IP, port, username) in `shared_preferences`; SSH password keyed as `ssh_password_<uuid>` in `flutter_secure_storage`

</specifics>

<deferred>
## Deferred Ideas

- Reconnect on drop (RECON-01..03) — v2
- iOS keepAlive (keepAliveInterval: 30s) — v2
- SSH key authentication — v2 (v1 is password-only)
- Custom theme settings — v2

</deferred>
