# Feature Landscape: claude-pilot

**Domain:** Mobile SSH remote control for AI coding agent (Claude Code)
**Researched:** 2026-06-19
**Confidence:** HIGH (spec is clear, domain well-understood, competing apps verified)

---

## Table Stakes

Features users expect from any mobile SSH terminal. Missing any of these makes the app feel broken, not minimal.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| SSH connection with username/password auth | Fundamental transport; without it the app doesn't exist | Low | dartssh2 handles this; v1 scope is password-only per SPEC |
| ANSI color rendering (16 + 256 palette) | Claude Code output is color-coded by design; monochrome makes it unreadable | Medium | xterm.dart renders at 60fps, handles 256-color and truecolor — use it, do not hand-roll |
| Scrollable output buffer | Sessions produce hundreds of lines; can't only see last screen | Low | xterm.dart includes this; size the buffer generously (5000+ lines) |
| Monospace font with correct line wrap | Code, diffs, and ASCII art all depend on fixed-width rendering | Low | Use Cascadia Code or JetBrains Mono bundled in assets — do not rely on system default |
| Ctrl+C as a single tap | Interrupting a stuck Claude Code run is the most frequent emergency action | Low | Map to SSH PTY signal SIGINT via escape sequence `\x03` — not a keyboard shortcut |
| Connection status visible at all times | User needs to know if they're actually connected before sending a prompt | Low | Persistent status indicator in header, not buried in a menu |
| Saved machine list with persist across app restarts | Re-entering IP/port/user every session is unacceptable friction | Low | flutter_secure_storage for credentials; regular SharedPreferences for non-sensitive metadata (name, IP, port) |
| Input field that accepts multi-line prompts | Claude Code prompts are often paragraphs, not one-liners | Low | Use TextField with maxLines: null and minLines: 3 |
| Send on tap (not on keyboard Enter) | Mobile Enter key behavior is unreliable and conflicts with newlines in prompts | Low | Dedicated send button; Enter key inserts newline |
| Graceful disconnect / reconnect | Mobile networks drop; SSH will die; user must be able to reconnect without restarting app | Medium | Detect TCP drop, show reconnect banner, re-establish SSH to same machine with same credentials |

---

## Differentiators

Features specific to the Claude Code remote control use case. A generic SSH client does not have these. They are the reason this app exists.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Quick command panel — control signals section | Ctrl+C, Ctrl+D, ESC, `\q` available as single taps; mobile keyboard cannot produce these | Low | Persistent bottom sheet with swipe-up toggle; signals section always rendered first |
| Quick command panel — Claude slash commands section | `/clear`, `/compact`, `/gsd`, `/cost`, `/status` on one tap; typing them on mobile is error-prone | Low | Predefined list in the panel; tap inserts text + sends |
| Permission approval cards | Claude Code's `y/n` prompts detected and rendered as prominent Approve/Reject buttons over the terminal | High | Must detect the prompt pattern in the output stream (heuristic or regex on known Claude Code prompt strings); sends `y\n` or `n\n` via SSH PTY |
| Voice-to-text prompt entry (hold-to-record) | Sending a multi-paragraph prompt by typing on glass is painful; voice removes the friction | Medium | speech_to_text on-device; transcription lands in editable field before send — never auto-sends |
| tmux-aware reconnect suggestion | After a dropped connection, app suggests `tmux attach` as the recovery command rather than a bare shell | Low | After reconnect, insert a one-tap "Reattach session" button if a tmux session was active |
| Command history navigation (up/down) | Claude Code sessions are stateful; re-sending the last prompt or navigating to a previous command is common | Low | Maintain local ring buffer of sent commands; up/down arrows in quick panel replay them via SSH PTY arrow escape sequences |
| Claude-specific dark theme | The app should feel like a companion to Claude Code's visual identity, not a generic green-on-black SSH client | Low | Background #1a1a1a, accent colors matching Claude Code's default theme; makes the mental model "same session, different window" |
| Session-start shortcuts | `claude`, `claude .` as one-tap panel buttons to launch Claude Code in the current directory | Low | Part of the slash commands panel under "Session" section; avoids typing the binary name |

---

## Anti-Features

Features that would add build complexity and maintenance burden without improving the remote control experience. Explicitly not worth building.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full terminal emulator / VIM / Nano editing | The desktop does the editing; replicating it on the phone contradicts the TV remote metaphor and requires massive complexity | Trust that Claude Code handles file editing; the phone only sends prompts and sees output |
| SFTP / file browser | File management is desktop work; adds 3-4 screens of UI for zero Claude Code workflow benefit | Out of scope per SPEC; no exceptions in v1 or v2 |
| Mosh (UDP) transport | Mosh needs a server-side mosh-server binary and separate port; adds setup friction for the target user (personal Linux desktop) | SSH reconnect + tmux-attach pattern achieves the same result with zero server-side setup |
| Push notifications when Claude finishes | Requires a notification service or a long-lived background connection; complex on both iOS (background execution limits) and Android; the user is already looking at the app if they care about output | Viable in v2 with a simple polling approach or native Claude Code remote control API; not for v1 |
| Multiple simultaneous sessions | Adds tab management UI; the target user has one desktop, one Claude Code instance | v2 if needed; flagged Out of Scope in SPEC |
| SSH key management with key generation | Generates passphrase/key pair UI, file storage, agent forwarding complexity; v1 users are on home LAN where password auth is acceptable | Password auth only in v1; key import (no generation) can be v2 if requested |
| Session recording / playback | Useful for auditing multi-user servers; irrelevant for personal single-user use | Not requested; do not add |
| Syntax highlighting in the terminal | ANSI colors from Claude Code itself provide all necessary highlighting; adding a second layer breaks ANSI fidelity | Render ANSI faithfully; do not post-process output |
| Swipe gestures to send arrow keys | JuiceSSH uses this pattern; it conflicts with scroll gesture on a terminal that needs vertical scrolling | Use explicit quick panel buttons for history navigation; scroll is scroll |
| Auto-send on voice transcription | Removes the review step; one misheard word sends the wrong instruction to Claude Code | Always land transcription in the editable field; require explicit tap to send |
| Theming / color scheme customization | Adds settings UI and state; the user's workflow is fixed (Claude Code dark theme on desktop) | Ship one well-chosen dark theme; add customization only if explicitly requested |
| Connection sharing / team features | This is a single-user personal tool | No multi-user, no snippet sharing, no cloud sync |

---

## Feature Dependencies

```
SSH connection established
    │
    ├─ Terminal output rendering (requires active session)
    │       └─ ANSI color parsing (requires terminal widget)
    │               └─ Permission card detection (requires output stream access)
    │
    ├─ Any input method (requires active session)
    │       ├─ Text input → send
    │       ├─ Voice transcription → text input → send
    │       └─ Quick command panel → send
    │
    └─ Command history navigation (requires prior sends in this session)

Machine Manager (always available, no session required)
    └─ Add / edit / delete machines
            └─ Secure credential storage
```

---

## The Mobile Keyboard Problem

Research on Termius, JuiceSSH, and Blink Shell reveals a consistent pattern: **mobile keyboards cannot produce the special keys that terminal workflows require** (Ctrl+C, Ctrl+D, ESC, arrow keys, Tab). Every major SSH app solves this the same way:

- A persistent supplemental key row above the keyboard (Blink "Smart Keys")
- A popup special-character keyboard (JuiceSSH)
- A collapsible accessory panel (Termius)

For claude-pilot, the correct solution is the **collapsible bottom sheet panel** from the SPEC. Key design rationale:

1. It does not consume vertical real estate when not needed (unlike a persistent key row)
2. It maps to the "TV remote" metaphor — a panel of contextual controls you reach for when needed
3. It has enough space to group commands by intent (control signals, slash commands, navigation, session) which a single row cannot do
4. Flutter's `DraggableScrollableSheet` implements this with native physics

The panel should always open to show the control signals section first (Ctrl+C is the most urgent action). Slash commands and navigation can scroll below.

---

## Permission Card Detection Strategy

Claude Code's permission prompts are text-pattern detectable in the PTY output stream. Known patterns (HIGH confidence, verified in research):

- `Allow [Tool] for "[description]"?` followed by `(y/n)` or option list
- `Claude wants to [action]:` followed by the subject and yes/no options

The detection logic should:
1. Watch the output stream for these patterns via regex
2. On match, extract the action description and render the approval card overlay
3. After the user taps Approve or Reject, send `y\n` or `n\n` and dismiss the card
4. Timeout: if the user does not respond within 60 seconds, the card stays (do not auto-approve)

Risk: Claude Code may change its prompt format between versions. The detection regex should be made configurable or easy to update without a full app release.

---

## MVP Recommendation

Prioritize for Phase 1 (functional foundation):
1. Machine Manager (add, list, delete, connect)
2. SSH connection with terminal output via xterm.dart
3. ANSI color rendering
4. Text input + send button
5. Ctrl+C as single tap (bare minimum quick panel)

Phase 2 (remote control value):
1. Full quick command panel (all four sections)
2. Voice-to-text prompt entry
3. Permission approval cards
4. Command history navigation (up/down)

Phase 3 (polish + resilience):
1. tmux-aware reconnect suggestion
2. Reconnect banner + one-tap reconnect
3. Customizable slash commands in panel
4. Theme refinements

Defer indefinitely:
- Push notifications (architecture cost too high for v1 LAN-only scope)
- Multiple sessions (no second Claude Code instance to justify it)
- SFTP (violates metaphor)

---

## Sources

- SPEC.md and PROJECT.md (primary spec, defines scope boundaries)
- Blink Shell: https://blink.sh/ and https://github.com/blinksh/blink (Smart Keys pattern for mobile keyboard)
- Termius feature set: https://termius.com (snippet/command panel approach)
- JuiceSSH: popup keyboard + snippets approach (community discussion at https://lowendspirit.com/discussion/5762/)
- xterm.dart: https://github.com/TerminalStudio/xterm.dart (60fps Flutter terminal emulator, confirmed mobile support in v3.0.0)
- speech_to_text package: https://pub.dev/packages/speech_to_text (on-device, requires internet for accuracy per Google/Apple ASR backend — LOW confidence on fully offline claim; verify on target devices)
- Claude Code permission format: https://github.com/anthropics/claude-code/issues/32973 and https://code.claude.com/docs/en/permissions
- Mobile approval system case study: https://dev.to/coa00/how-i-built-a-mobile-approval-system-for-claude-code-so-i-can-finally-leave-my-desk-1ida
- tmux session persistence: https://neoshell.app/notes/solving-session-persistence-for-mobile-ssh-with-tmux-and-zellij/
- NNGroup bottom sheet UX: https://www.nngroup.com/articles/bottom-sheet/ (persistent vs modal tradeoffs)
- Claude Code native remote control context: https://devops.com/claude-code-remote-control-keeps-your-agent-local-and-puts-it-in-your-pocket/
