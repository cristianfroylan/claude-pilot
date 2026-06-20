# Phase 4: Reconexión Robusta - Context

**Gathered:** 2026-06-20
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers robust reconnection so users never lose work to a dropped connection. Specifically: automatic retry with exponential backoff on both initial connection failures and mid-session drops, visible progress UI (attempt counter + countdown timer), cancel and manual retry controls, and full preservation of the xterm Terminal scrollback buffer throughout the reconnection cycle.

Out of scope: reconnection analytics, notifications, or any changes to machine management.

</domain>

<decisions>
## Implementation Decisions

### Reconnection State Model
- Use `AsyncData(SshSessionState)` with a sealed class — never emit `AsyncLoading` or `AsyncError` during reconnect so the xterm `Terminal` instance (and its scrollback buffer) is always reachable from the UI
- Sealed class variants: `SshConnecting | SshConnected(terminal) | SshReconnecting(terminal, attempt, maxAttempts, secondsLeft) | SshFailed(terminal)`
- The `Terminal` instance is carried in all variants — UI always has a valid terminal to render
- Retry loop lives inside `SshSession.build()` with a `_isMidSession` bool flag distinguishing initial vs mid-session paths — no external ReconnectManager class
- Countdown exposed via `secondsLeft` field in `SshReconnecting`, updated each second via `Timer.periodic` that writes `state = AsyncData(SshReconnecting(..., secondsLeft: n))`

### Retry Parameters & Cancel
- Initial connection: 5 attempts, exponential backoff 1s→2s→4s→8s→16s (per RECON-01)
- Mid-session drop: 3 attempts, backoff 2s→4s→8s (per RECON-02)
- Cancel mechanism: `bool _cancelRequested` field on the notifier, checked at each loop iteration before sleeping and before retrying
- Manual retry post-exhaustion: public `reconnect()` method on `SshSession` notifier that resets `_cancelRequested = false` and re-runs the retry loop from the current state's terminal — does NOT call `ref.invalidateSelf()` (would create new Terminal and clear scrollback)
- `@Riverpod(retry: false)` on SshSession — prevents Riverpod 3 auto-retry from stacking with custom backoff loop (already noted in STATE.md)

### UI Feedback
- Initial connection failure UI: overlay on `TerminalScreen` (not a Dialog) showing spinner + "Attempt N/5 — retrying in Xs" + Cancel button — terminal content visible in background
- Mid-session drop UI: inline `AnimatedContainer` banner pinned to top of terminal view — one compact line showing "Connection lost · Attempt N/3 · Retry in Xs" + Cancel — terminal scrollback fully visible below
- Post-reconnect: brief `SnackBar("Reconnected")` auto-dismissing in 2s — does not write to terminal (would contaminate Claude Code scrollback)

### Claude's Discretion
- Exact widget styling (colors, fonts, padding) consistent with existing `AppTheme` — no new design tokens needed
- Whether to extract reconnect overlay into its own widget file or keep inline in `terminal_screen.dart` — prefer separate file if >50 lines
- `@Riverpod(retry: false)` exact annotation syntax — verify against Riverpod 3 docs during planning research

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SshSession` notifier in `lib/features/terminal/providers/ssh_session_provider.dart` — already has a 3-attempt retry loop with 1s fixed delay; Phase 4 extends this with sealed state, exponential backoff, and countdown
- `Terminal` (xterm) instance created in `_connectOnce()` — must be extracted to instance field so it persists across reconnect attempts without rebuild
- `TerminalViewWrapper` widget handles PTY resize — will need to remain mounted during reconnection (already handled by `AnimatedContainer` banner approach)
- `AppTheme` in `lib/core/theme/app_theme.dart` — use existing colors/typography for overlay and banner

### Established Patterns
- Riverpod `@riverpod` annotation with `AsyncNotifier` pattern — `SshSession extends _$SshSession`
- `ref.onDispose()` registered first before any awaits — maintain this pattern
- `_disposed` bool guard on all async continuations — extend to `_cancelRequested` with same guard pattern
- `StreamController.broadcast()` for `permissionStream` — pattern for exposing internal streams

### Integration Points
- `TerminalScreen` (`lib/features/terminal/screens/terminal_screen.dart`) — wrap its body in a `Stack` to overlay the reconnection UI
- `ssh_session_provider.dart` — primary file to modify; `.g.dart` will regenerate
- No new routes needed — reconnection UI is in-place within existing terminal screen

</code_context>

<specifics>
## Specific Ideas

- From REQUIREMENTS.md RECON-05: "El historial del terminal (scrollback) se preserva durante y después de la reconexión — no se limpia el buffer de xterm" — this is the non-negotiable constraint driving the sealed class approach
- From STATE.md: "SshSession never emits AsyncLoading during reconnect — use AsyncData(SshReconnecting(...)) to preserve xterm Terminal scrollback buffer" — locked decision from v2.0 research
- RECON-01 specifies exact UX copy: "Attempt 2/5 — retrying in 4s"
- RECON-02 specifies inline banner in terminal view (not full-screen)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
