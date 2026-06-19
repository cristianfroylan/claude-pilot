# Phase 3: Polish and Stability - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 is cross-cutting hardening of all Phase 1 and Phase 2 work. No new user-facing features are added. The phase addresses three stability pillars:

1. **PTY resize correctness** — terminal text must reflow when the soft keyboard appears/disappears and when the device rotates. The `LayoutBuilder`-based resize from Phase 1 may not fire reliably across all keyboard/rotation transitions; this phase ensures it does.

2. **SSH keepalive** — SSH sessions must survive app backgrounding. On iOS, the TCP connection can be killed by the OS; `keepAliveInterval` on `SSHClient` mitigates this. On Android, LAN SSH connections are typically resilient without extra configuration.

3. **Visual polish** — consistent dark theme, no layout overflows in `PermissionCard`, `VoiceBottomSheet`, or `InputBar` on small screens; `SafeArea` coverage; monospace font confirmed on both platforms; no rendering glitches in landscape orientation.

Requirements in scope: none new — cross-cutting polish across MACH-01..05, SSH-01..04, TERM-01..04, INP-01..04, CMD-01..05, VOZ-01..04, APRO-01..03

</domain>

<decisions>
## Implementation Decisions

### PTY Resize
- Root cause: `LayoutBuilder` fires on widget rebuild, but keyboard-triggered inset changes may not always propagate through to the terminal's `LayoutBuilder` subtree in all Flutter versions
- Fix: Wrap `TerminalScreen`'s `Scaffold` body in a `MediaQuery`-aware widget that explicitly listens to `viewInsets` changes and forces a `TerminalViewWrapper` rebuild when the keyboard height changes
- Orientation: Allow both portrait and landscape; PTY cols/rows formula already adapts via `LayoutBuilder` — no change needed to the formula itself
- Keep `resizeToAvoidBottomInset: true` on Scaffold (already set in Phase 1)

### SSH Keepalive
- Add `keepAliveInterval: const Duration(seconds: 30)` to `SSHClient` constructor in `ssh_session_provider.dart`
- This is the standard SSH keepalive mechanism and prevents iOS from silently dropping the TCP connection during brief backgrounding
- Android: no additional work needed for LAN connections

### Visual Polish
- Add `SafeArea` wrapper around the Scaffold body (above AppBar) if not already present — prevents notch/status-bar clipping on iOS
- Audit `PermissionCard` for text overflow: the 80-char truncation should prevent long-line issues, but add `overflow: TextOverflow.ellipsis` to the excerpt `Text` widget
- Audit `VoiceBottomSheet` for small-screen overflow: ensure the sheet is scrollable if content exceeds available height
- `InputBar` on small screens: the Command panel's `ConstrainedBox(maxHeight: 240)` from Phase 1 already prevents overflow; confirm it works in landscape
- Font: xterm.dart uses its own monospace renderer — no Flutter font override needed; confirm it renders correctly on iOS (no tofu/fallback characters)
- Remove any remaining debug artifacts (e.g., excessive rebuild logs)

### Claude's Discretion
- Exact `keepAliveInterval` value (30s is standard; adjust if testing reveals a better value)
- Whether to add `countOfAvailableLines` to the terminal scrollback limit or leave at 2000
- Exact `SafeArea` placement (top only vs all sides)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/terminal/providers/ssh_session_provider.dart` — `SSHClient` constructor (add `keepAliveInterval`)
- `lib/features/terminal/widgets/terminal_view_wrapper.dart` — `LayoutBuilder` PTY resize logic (may need `key:` or `MediaQuery` listener)
- `lib/features/terminal/screens/terminal_screen.dart` — Scaffold body, `resizeToAvoidBottomInset`, `Column` layout
- `lib/features/terminal/widgets/permission_card.dart` — excerpt `Text` widget (add overflow)
- `lib/features/terminal/widgets/voice_bottom_sheet.dart` — bottom sheet layout (add scroll wrapper if needed)
- `lib/features/terminal/widgets/input_bar.dart` — Command panel with `ConstrainedBox(maxHeight: 240)`

### Established Patterns
- PTY resize: `WidgetsBinding.instance.addPostFrameCallback` in `TerminalViewWrapper`
- State: `@riverpod` codegen, no raw `setState` in providers
- Theme: `Theme.of(context).colorScheme` everywhere

### Integration Points
- `SSHClient` constructor in `_connectOnce` — `keepAliveInterval` parameter
- `terminal_screen.dart` `Scaffold` — `SafeArea` wrapping
- `permission_card.dart` — `Text` overflow property
- `voice_bottom_sheet.dart` — possible `SingleChildScrollView` wrapper

</code_context>

<specifics>
## Specific Ideas

- The `keepAliveInterval` parameter on `SSHClient` from dartssh2 is the correct mechanism for iOS background keepalive — it sends SSH keepalive packets that prevent the TCP connection from being silently dropped by the iOS networking stack
- PTY resize correctness: if `LayoutBuilder` already works correctly in practice (Phase 1 testing confirmed it resizes on keyboard appear/disappear), the main remaining risk is **rotation** — test with a simple `OrientationBuilder` or rely on the existing `LayoutBuilder` which fires on rotation too
- The Phase 1 `TerminalViewWrapper` comment says "MUST use addPostFrameCallback" — this pattern is correct and should be preserved

</specifics>

<deferred>
## Deferred Ideas

- Reconnect on drop (RECON-01..03) — v2
- iOS keepAlive beyond 30s (background app refresh) — v2
- Custom theme settings — v2
- Multiple simultaneous sessions — v2

</deferred>
