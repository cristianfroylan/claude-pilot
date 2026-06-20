# Feature Landscape: claude-pilot

**Domain:** Mobile SSH remote control for AI coding agent (Claude Code)
**Researched:** 2026-06-19 (v1.0) / 2026-06-20 (v2.0 addendum)
**Confidence:** HIGH (spec is clear, domain well-understood, competing apps verified)

---

## Table Stakes — v1.0 (already built, for reference)

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

## Differentiators — v1.0 (already built, for reference)

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

## Anti-Features — v1.0 (still valid in v2.0)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full terminal emulator / VIM / Nano editing | The desktop does the editing; replicating it on the phone contradicts the TV remote metaphor and requires massive complexity | Trust that Claude Code handles file editing; the phone only sends prompts and sees output |
| SFTP / file browser | File management is desktop work; adds 3-4 screens of UI for zero Claude Code workflow benefit | Out of scope per SPEC; no exceptions in v1 or v2 |
| Mosh (UDP) transport | Mosh needs a server-side mosh-server binary and separate port; adds setup friction for the target user (personal Linux desktop) | SSH reconnect + tmux-attach pattern achieves the same result with zero server-side setup |
| Push notifications when Claude finishes | Requires a notification service or a long-lived background connection; complex on both iOS (background execution limits) and Android | Viable in v3 |
| SSH key management with key generation | Generates passphrase/key pair UI, file storage, agent forwarding complexity; v1 users are on home LAN where password auth is acceptable | Password auth only in v1; key import (no generation) can be v2 if requested |
| Session recording / playback | Useful for auditing multi-user servers; irrelevant for personal single-user use | Not requested; do not add |
| Syntax highlighting in the terminal | ANSI colors from Claude Code itself provide all necessary highlighting; adding a second layer breaks ANSI fidelity | Render ANSI faithfully; do not post-process output |
| Swipe gestures to send arrow keys | JuiceSSH uses this pattern; it conflicts with scroll gesture on a terminal that needs vertical scrolling | Use explicit quick panel buttons for history navigation; scroll is scroll |
| Auto-send on voice transcription | Removes the review step; one misheard word sends the wrong instruction to Claude Code | Always land transcription in the editable field; require explicit tap to send |
| Theming / color scheme customization | Adds settings UI and state; the user's workflow is fixed (Claude Code dark theme on desktop) | Ship one well-chosen dark theme; add customization only if explicitly requested |
| Connection sharing / team features | This is a single-user personal tool | No multi-user, no snippet sharing, no cloud sync |

---

---

# v2.0 Power User Features

Research date: 2026-06-20. Four new features only.

---

## Feature 1: Multi-Session Tabs

### What this is

Multiple independent SSH connections open simultaneously, each in its own tab.
The user switches between tabs without disconnecting. Each tab has its own
`sshSessionProvider` instance. Navigation between tabs does not pop any route —
tabs are siblings inside a single tab-host screen.

### Table Stakes (must-have for the feature to feel complete)

| Behavior | Detail | Complexity |
|----------|--------|------------|
| Tab strip always visible | Horizontal scrollable row of tabs at the top or bottom of the terminal screen. Never auto-hides. | Low |
| Each tab shows machine name | "dev-box", "pi4" — not "Tab 1". If the same machine has two tabs open, disambiguate: "dev-box (2)". | Low |
| Tap switches without disconnecting | The SSH session keeps running while hidden. The xterm Terminal widget stays alive via AutomaticKeepAliveClientMixin. | Medium |
| Close button per tab | Small × on each tab chip. One tap closes the tab and terminates that SSH session. No confirmation dialog (see differentiators for optional guard). | Low |
| Add-tab button | A + at the end of the tab strip opens the machine list. After picking a machine the new tab is created and focused. | Low |
| Tab strip scrolls when tabs overflow | Horizontal scroll, not wrapping. Users will have 2–4 tabs max; strip does not need to show all at once. | Low |
| Tab state survives orientation change | Connected session is not rebuilt on rotate. Use `AutomaticKeepAliveClientMixin` on the terminal content widget. | Low |

### Differentiators

| Behavior | Value | Complexity |
|----------|-------|------------|
| Connection-state dot per tab | Green = connected, amber = reconnecting, red = dropped. At-a-glance health across sessions. | Low |
| Close-confirmation guard | "Session has recent output — close anyway?" if output arrived < 5 s ago. Guards accidental taps. | Medium |
| Tab reorder by long-press drag | Useful with 3+ tabs. | High |
| Swipe left/right on terminal body to switch tabs | Chrome-on-iOS style. Conflicts with xterm's horizontal scroll — non-trivial to implement safely without intercepting touch events meant for the terminal. | High |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Split-screen (two terminals side-by-side) | Phone screen too small; Termius split is a desktop/iPad-only feature | Tabs are the correct mobile abstraction |
| Tab groups / named workspaces | Adds management overhead; user has fewer than 5 machines | Out of scope for v2 |
| Persist open tabs across app restarts | Sessions die on restart anyway; complicates state model | Reconstruct tabs from machine list on next launch |

### Session Drop Behavior (tab-specific)

When a session drops (network interruption or remote close):

1. The tab stays open. Do not auto-close it.
2. The connection-state dot turns red.
3. The terminal body freezes on last output (xterm model stays intact, do not clear it).
4. A small inline banner at the top of that tab's terminal shows "Connection lost — Reconnect / Close".
5. Tapping "Reconnect" triggers the reconnection flow (Feature 4).
6. Other tabs are completely unaffected.

This matches what Termius and browser tabs do: a dropped session does not disrupt other sessions.

### Implementation Notes

The current GoRouter pushes `/machines/:id/terminal` as a route. Multi-tab replaces this
with an in-place tab-host widget. The router no longer owns the terminal screen; it signals
the tab host to open a new tab. **This is the largest structural change in v2.0.**

`sshSessionProvider(machineId)` is `autoDispose` today. With tabs, the provider must
remain alive while its tab is not focused. Use `ref.keepAlive()` or switch to a non-autoDispose
provider scoped to the tab host.

Each tab needs a stable key that is NOT the machine ID (since the same machine can be
open twice). Use a UUID generated when the tab is created. The machine ID identifies
the SSH target; the tab UUID identifies the provider instance.

### Dependencies

None from the other three new features. This is the foundational structural change of v2.0.
Feature 4 (Reconnection) integrates here via the per-tab connection-state dot.

---

## Feature 2: Session Start Picker

### What this is

When the user opens a new SSH tab (or the existing single-session connect flow), a
bottom sheet appears first. The user picks: start a blank shell, or pick a project
folder from a configurable per-machine list. Picking a folder automatically sends
`cd <folder>` on the new shell.

### UX Flow

```
User taps machine to connect
    ↓ SSH shell is established
Session Start Sheet appears (bottom sheet, modal)
    ├── [Start blank]  →  shell opens at default directory (home)
    └── [Pick project] →  folder list shown
            ├── Configured folders present → listed immediately
            ├── No configured folders → ls -d */ runs → directories shown
            ├── ls returns nothing → empty state + "Configure" link
            └── ls fails → error message → auto-proceed to blank after 2 s
                User taps folder → cd <path>\n sent → sheet dismissed → shell ready
```

**Swipe down or tap outside** = start blank. This is the safe default and the fast path.

The sheet appears at **every** session open, not just the first time. It is intentionally
non-blocking: "blank" is always one dismiss away.

The sheet appears **after** the SSH shell is ready (session in `data` state), not before
connection. This means the app connects first, then offers the picker. Delaying connection
until the user picks would make the cold-connect latency feel user-caused.

### Table Stakes

| Behavior | Detail | Complexity |
|----------|--------|------------|
| Sheet appears at session open | Appears when `sshSessionProvider` reaches `data` state. | Low |
| "Start blank" always present | Single tap (or swipe down). This is the fast path. | Low |
| Configured folders listed first | Per-machine list stored in `shared_preferences` (not sensitive). User configures in machine edit screen. | Medium |
| Tapping a folder sends `cd <path>\n` | Identical mechanism to the "cd ~" chip in InputBar. No new SSH plumbing needed. | Low |
| ls fallback when no folders configured | Issue `ls -d */` on the shell and parse directory names from output. Show as tappable list. Fragile (see edge cases) — used only as fallback, not primary path. | High |
| Empty state when ls returns nothing | "No folders found. Tap 'Configure' to add project paths." with link to machine edit. | Low |

### Differentiators

| Behavior | Value | Complexity |
|----------|-------|------------|
| Remember last-used folder per machine | Auto-highlight the last folder used for that machine. Removes friction for users with a single main project per machine. | Medium |
| Show git branch next to folder name | After ls, run `git -C <dir> branch --show-current` for each listed directory. Reveals active branch. Highly useful for Claude Code users. | High |
| Search/filter in folder list | Text filter over the list. Useful when ls returns many directories. | Low |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Recursive directory browser | One level is enough; a tree browser is scope creep | User configures explicit paths in machine edit |
| SFTP-based folder listing | Adds dartssh2 SFTP codepath | ls via existing shell is sufficient |
| Full file manager | Explicitly out of scope in PROJECT.md | — |

### Edge Cases

| Case | Behavior |
|------|----------|
| ls returns nothing (empty home dir) | Empty state: "No folders found. Start blank or configure folders manually." |
| ls fails (permission denied, command not found on the remote) | Error inline: "Could not list folders — starting blank." Auto-dismiss sheet after 2 s. |
| cd fails after picking (folder deleted since config) | Shell outputs `cd: no such file or directory` naturally in the terminal. No special handling needed. |
| Very long ls output (100+ directories) | Truncate to 20 entries + "show more" or show search filter immediately. |
| User changes mind after tapping "Pick project" | "Back" button or swipe-down returns to sheet. Tapping "Start blank" is always available. |
| Root directory selected (ls shows repo root) | Known pitfall from Claude Desktop: the root folder may not be selectable if picker only shows subdirectories. Explicitly include `.` ("current directory") as a selectable option at the top of the list. See sources. |

### Dependencies

- Machine edit screen must grow a "Project folders" section (list of absolute paths; add/remove).
- The picker sheet must not appear until the session is in `data` state (shell ready).
- No dependency on Feature 1 (tabs), but the two integrate: each new tab triggers the picker independently.

---

## Feature 3: Biometric App Lock

### What this is

The app requires biometric authentication (Face ID / fingerprint) or device PIN
fallback at two moments: app launch, and before editing or deleting a machine's
credentials. This is app-level security, not per-connection. It mirrors the pattern
used by banking apps (YNAB, 1Password, banking clients).

The Flutter package is `local_auth` (current version: **3.0.1**, publisher: flutter.dev team).

### Trigger Points (exactly when the lock fires)

| Trigger | Behavior |
|---------|----------|
| App cold launch | Lock screen or overlay shown before machine list is visible. User cannot interact until authenticated. |
| App resumed from background after grace period | Re-prompt if app was backgrounded for > grace period (recommended default: 10 minutes). Standard for banking apps: Blackthorn uses 15 min, Oracle CX 10 min, Android docs recommend 15 min. |
| Tapping "Edit" on a saved machine | Biometric prompt fires before the edit screen opens. Protects credentials (host, username, password). |
| Tapping "Delete" on a saved machine | Same prompt. Delete also reads credentials from secure storage to clean up. |

**Not triggered by:** briefly switching to another app (within grace period), locking the screen and unlocking, navigating between tabs, opening a terminal session.

### Table Stakes

| Behavior | Detail | Complexity |
|----------|--------|------------|
| Lock on cold launch | App renders a lock overlay or a dedicated lock screen. The machine list widget is not built or shown until auth succeeds. | Low |
| OS native biometric dialog | Do not build a custom UI. `local_auth.authenticate()` raises the system sheet (Touch ID / Face ID / fingerprint). | Low |
| Fallback to device PIN / pattern / passcode | `biometricOnly: false` (the default in local_auth). The OS handles this automatically in the same dialog — user taps "Use Passcode". No custom code needed. | Low |
| Re-lock after background grace period | Use `WidgetsBindingObserver.didChangeAppLifecycleState` to detect `resumed`. Track `lastAuthTime` in a top-level Riverpod `NotifierProvider`. If `DateTime.now() - lastAuthTime > gracePeriod` → re-lock. | Medium |
| Gate machine edit and delete behind biometric | The `onEdit` and `onDelete` callbacks in `MachineListTile` call auth first, then proceed. | Low |
| Auth failure: do not grant access | On failure (user canceled or biometric rejected), the lock overlay stays. Re-show auth dialog on next tap. The OS manages the 5-attempt lockout (30 s lockout on Android, passcode required on iOS). App does not implement its own lockout counter. | Low |

### Differentiators

| Behavior | Value | Complexity |
|----------|-------|------------|
| Configurable grace period (5 / 10 / 30 min / Never) | Lets the user tune security vs convenience. | Low |
| Visual blur of machine list before auth passes | Prevents shoulder-surfing of machine names while the OS prompt is on screen. `BackdropFilter` in a Stack overlay. | Low |
| "Biometrics only" toggle (disable PIN fallback) | Set `biometricOnly: true`. For users who want strict biometric guarantee. Note: higher lockout risk. | Low |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom in-app PIN screen | `flutter_secure_storage` + custom 4-digit PIN is significant scope; the OS device PIN does the same job via `local_auth` | Use OS device PIN as the fallback |
| Per-connection (per-tab) auth prompt | Breaks the flow — user already passed the app lock. Asking again is friction without security gain | App-level lock covers this |
| Biometric enrollment from within the app | Not possible on iOS or Android without navigating to OS Settings | Show a message directing user to device Settings |

### Edge Cases

| Case | Behavior |
|------|----------|
| Device has no biometric hardware | `canCheckBiometrics` returns false. `isDeviceSupported()` may still return true (PIN available). `authenticate()` shows PIN dialog. App works normally. |
| Biometric hardware present but no enrolled biometrics | `getAvailableBiometrics()` returns empty list. `authenticate()` shows PIN dialog. App works normally. |
| No device PIN set at all | `isDeviceSupported()` returns false. Cannot enforce lock. Show one-time warning: "Enable a device lock in Settings to secure Claude Pilot." Proceed without lock. |
| Authentication canceled (incoming call, user dismisses) | `local_auth` returns `AuthenticationError.canceled`. Re-show lock overlay. Do not grant access on cancel. |
| App backgrounded mid-authentication | System cancels the dialog. On return to foreground, re-trigger auth immediately. `persistAcrossBackgrounding: true` can make the plugin wait for foreground before returning — use this to avoid a double-prompt on some devices. |
| Biometric lockout (5 failed attempts) | OS enforces 30-second lockout (Android) or passcode requirement (iOS). The app's lock overlay stays. App does not need to implement this. |

### Implementation Notes

Check capability at startup: `canCheckBiometrics || isDeviceSupported()`. If neither:
skip lock, show a one-time warning.

Wrap the root navigator with a lock-overlay Riverpod provider. Default state is
"locked". State lifts to "unlocked" on successful auth. `lastAuthTime` is stored in the
provider, not widget state, so it survives widget rebuilds.

Set `persistAcrossBackgrounding: true` in `local_auth` options. This causes the plugin
to pause and wait for the app to foreground before returning the auth result, which is
safer than getting a canceled result immediately.

### Dependencies

No dependency on Features 1, 2, or 4. This is a cross-cutting concern that wraps the
entire app. It can be built in any order relative to the other features.

---

## Feature 4: Robust Reconnection

### Current State (what already exists in v1.0)

`SshSession.build()` retries 3 times with a fixed 1-second delay between attempts
(`maxAttempts = 3`, `Future.delayed(1s)`). The UI shows only a `CircularProgressIndicator`
with "Connecting…" and no progress detail during the entire retry window.

On mid-session drop, there is a SnackBar but no automatic reconnect attempt. The session
enters an error state and stays there.

### The Two Scenarios

**A. Initial connection failure** — host unreachable, wrong credentials, SSH refused.
The 3-attempt retry exists. This feature makes it visible and controllable.

**B. Mid-session drop** — network blink, laptop sleep/wake, server restarted.
Currently shows a SnackBar and stops. This feature adds auto-retry here too.

### Standard Backoff Pattern (HIGH confidence — multiple sources)

```
delay(attempt) = min(base * 2^attempt + jitter, cap)
where:
  base   = 1 second
  jitter = random(0, 1) second  ← smooths concurrent reconnects across tabs
  cap    = 30 seconds
```

Sequence without jitter: 1 s → 2 s → 4 s → 8 s → 16 s → 30 s → 30 s → …

For a LAN SSH client, the remote is either reachable (round-trip < 5 ms) or it is not
(laptop asleep, network down). Waiting more than 30 s per attempt adds no value.
Capping at 30 s is the industry standard for mobile WebSocket/TCP reconnection.

**Recommended attempt counts:**
- Initial connect failure: increase from 3 to **5 attempts** with exponential backoff. After 5 → stop, show "Review settings" dialog.
- Mid-session drop: **3 attempts** with backoff (1 s, 2 s, 4 s). After 3 → stop, show manual retry UI. Do not auto-retry indefinitely.

### Table Stakes

| Behavior | Detail | Complexity |
|----------|--------|------------|
| Attempt counter shown during retry | "Reconnecting… attempt 2 of 5" — inline below or replacing the spinner. | Low |
| Countdown to next retry | "Retrying in 4 s…" displayed during the inter-attempt wait. More reassuring than a frozen spinner. | Low |
| Cancel button available throughout | Stops the retry loop immediately. Shows the manual-retry state. | Low |
| Manual retry button after exhaustion | "Try again" restarts the full retry sequence from attempt 1. | Low |
| Review settings link after initial-connect exhaustion | Already exists in v1.0 dialog. Keep it. | Low |
| Mid-session drop shows inline reconnect UI, not a SnackBar | Terminal body stays visible with last output intact. A non-intrusive banner at the top of the terminal shows "Connection lost. Reconnecting (1/3)…" with a Cancel button. | Medium |
| Reconnect success is silent | If mid-session reconnect succeeds, dismiss the banner and show a brief "Reconnected" toast. Do not disrupt the terminal view. | Low |

### Differentiators

| Behavior | Value | Complexity |
|----------|-------|------------|
| TCP reachability check before SSH | `InternetAddress.lookup(host)` or raw TCP connect to port 22 before starting the SSH handshake. Distinguishes "network down" from "SSH rejected", allowing a more specific error message. | Medium |
| Reconnect succeeds without clearing terminal | On successful mid-session reconnect, the xterm Terminal (render state + scrollback) is preserved. Only the SSH transport is rebuilt. | Medium (see notes) |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Infinite auto-retry on mid-session drop | Drains battery, masks real failures, confuses the user | Cap at 3 auto-retries, then require manual action |
| Exponential backoff cap > 30 s for LAN | LAN is either up or it is not; waiting 2+ minutes is just frustrating | Hard cap at 30 s |
| Modal dialog during retry | Blocks the terminal, prevents seeing last output | Inline banner in the terminal body |

### UI State Machine

```
[Connecting]
    "Connecting… attempt N of M"
    "Retrying in X s…" | [Cancel]
    ↓ (all N attempts fail)
[Connection failed]
    "Could not connect after M attempts."
    [Review settings] | [Try again]

[Connected] — normal terminal view
    ↓ (mid-session drop detected via _client.done error)
[Reconnecting mid-session]
    Terminal body frozen on last output
    Banner: "Connection lost. Reconnecting (1/3)…" | [Cancel]
    ↓ (reconnect succeeds)
[Reconnected]
    Banner dismissed, brief toast "Reconnected", terminal resumes live
    ↓ (all 3 mid-session attempts fail)
[Reconnect failed]
    Banner stays: "Could not reconnect."
    [Try again] | [Close tab]
```

### Implementation Notes

The retry loop in `SshSession.build()` currently has no way to expose progress to the
UI (it is hidden inside the `Future<Terminal>` computation). The backoff logic must
be refactored to expose state: either a second provider that publishes retry progress,
or by using `AsyncNotifier.update()` to emit intermediate states.

Mid-session reconnect must **reuse the existing `Terminal` instance** (xterm model with
scrollback). Only `SSHClient` and `SSHSession` are rebuilt. The `_connectOnce()` method
already accepts the terminal separately from the client — this pattern should be extended.

Jitter prevents two tabs reconnecting at the exact same millisecond, which would hammer
the SSH daemon simultaneously.

The `_client.done.catchError` hook already routes transport drops to `state = AsyncError`.
The reconnect loop should hook here: catch error → enter mid-session retry loop → on
success set `state = AsyncData(sameTerminal)` → on exhaustion set `state = AsyncError`.

### Dependencies

No hard dependency on Features 1, 2, or 3. Integrates naturally with Feature 1 (tabs):
each tab has an independent session, so a dropped tab shows its own reconnect banner
without affecting others. The connection-state dot (Feature 1 differentiator) maps
directly to this feature's state machine.

---

## Feature Dependencies Summary

```
Feature 1 (Tabs) — structural change: router no longer owns the terminal screen
    └── Feature 4 (Reconnection) integrates via per-tab connection-state dot

Feature 2 (Session Picker)
    └── requires Feature 1 OR the existing single-session flow — works with both
    └── requires machine edit screen to grow a folder list section

Feature 3 (Biometric Lock)
    └── fully independent — wraps the entire app
    └── no dependency on 1 / 2 / 4

Feature 4 (Reconnection)
    └── independent of 1 / 2 / 3
    └── integrates with Feature 1 for per-tab reconnect UI
```

**Recommended build order: 1 → 4 → 2 → 3**

- Build tabs first: biggest structural change; everything else sits inside it
- Reconnection second: uses the tab infrastructure; highest safety-and-reliability value
- Session picker third: extends the machine model and edit screen; lower risk
- Biometric lock last: orthogonal; can be deferred if time runs short without harming the core

---

## Complexity Summary — v2.0 Features

| Feature | Overall Complexity | Riskiest Part |
|---------|-------------------|---------------|
| Multi-session tabs | Medium | Migrating from router-push to tab host; SSH session lifetime with Riverpod keepAlive |
| Session start picker | Medium | ls parsing fallback (fragile); adding folder config to machine edit screen |
| Biometric lock | Low | Edge cases (no hardware, no enrolled biometrics, no device PIN); grace period timer in Riverpod |
| Robust reconnection | Medium | Reusing the xterm Terminal across SSH transport reconnects; exposing retry progress to UI |

---

## Feature Dependencies Tree (v1.0 + v2.0 combined)

```
SSH connection established
    │
    ├─ Terminal output rendering
    │       └─ ANSI color parsing
    │               └─ Permission card detection
    │
    ├─ Any input method
    │       ├─ Text input → send
    │       ├─ Voice transcription → text input → send
    │       └─ Quick command panel → send
    │
    ├─ Multi-session tabs (v2)
    │       └─ Session start picker (v2) — fires per new tab
    │       └─ Robust reconnection (v2) — fires per dropped tab
    │
    └─ Robust reconnection (v2) — also applies to single-session flow

Machine Manager (always available, no session required)
    ├─ Add / edit / delete machines
    │       ├─ Secure credential storage
    │       └─ [v2] Biometric auth gates edit/delete
    │       └─ [v2] Project folder list per machine
    │
    └─ [v2] Biometric lock gates the entire app at launch

[v2] Biometric lock — wraps app root, no session dependency
```

---

## The Mobile Keyboard Problem (v1.0 context, still relevant)

Research on Termius, JuiceSSH, and Blink Shell reveals a consistent pattern: mobile
keyboards cannot produce the special keys that terminal workflows require (Ctrl+C,
Ctrl+D, ESC, arrow keys, Tab). Every major SSH app solves this the same way:

- A persistent supplemental key row above the keyboard (Blink "Smart Keys")
- A popup special-character keyboard (JuiceSSH)
- A collapsible accessory panel (Termius)

For claude-pilot, the collapsible bottom sheet panel is the correct solution. It does
not consume vertical real estate when not needed, and it has enough space to group
commands by intent (control signals, slash commands, navigation, session).

---

## MVP Recommendation — v2.0

Build all four features. Priority if time runs out:

1. **Multi-session tabs** — core feature; everything else is additive
2. **Robust reconnection** — highest reliability value; frequent use case
3. **Session start picker** — quality-of-life feature; absent = user types `cd` manually
4. **Biometric lock** — security feature; absent = app opens without auth (acceptable for a personal LAN tool)

Defer from v2.0 into v3:
- Tab reorder by long-press drag (high complexity, low frequency)
- Git branch display in session picker (high complexity, high value — good v3 candidate)
- Swipe left/right on terminal body to switch tabs (conflicts with xterm scroll)

---

## Sources

### v1.0 Sources
- SPEC.md and PROJECT.md (primary spec, defines scope boundaries)
- Blink Shell: https://blink.sh/ (Smart Keys pattern for mobile keyboard)
- Termius feature set: https://termius.com (multi-tab, collapsible panel)
- xterm.dart: https://github.com/TerminalStudio/xterm.dart
- speech_to_text: https://pub.dev/packages/speech_to_text
- Claude Code permission format: https://github.com/anthropics/claude-code/issues/32973
- Mobile approval system: https://dev.to/coa00/how-i-built-a-mobile-approval-system-for-claude-code-so-i-can-finally-leave-my-desk-1ida

### v2.0 Sources
- Chrome mobile tab management: [Android](https://support.google.com/chrome/answer/2391819?hl=en&co=GENIE.Platform%3DAndroid) | [iOS](https://support.google.com/chrome/answer/2391819?hl=en&co=GENIE.Platform%3DiOS)
- Termius multi-tab iOS: [Termius iOS SFTP blog](https://termius.com/blog/termius-for-ios-new-navigation-and-sftp)
- TabSSH open-source SSH tab client: https://tabssh.github.io/
- local_auth Flutter package: https://pub.dev/packages/local_auth — verified version 3.0.1, publisher flutter.dev
- Android biometric auth docs: https://developer.android.com/identity/sign-in/biometric-auth
- Biometric grace period — Molly IM (5 s / 60 s): https://github.com/mollyim/mollyim-android/pull/104
- Biometric grace period — Blackthorn 15 min default: https://docs.blackthorn.io/docs/mobile-checkin-app-biometric-authentication
- Biometric grace period — Oracle CX 10 min default: https://docs.oracle.com/en/cloud/saas/readiness/sales/25b/sfau-25b/25B-sf-automation-wn-f36964.htm
- local_auth no-biometric-hardware issue: https://github.com/flutter/flutter/issues/105005
- Exponential backoff mobile pattern: https://yaircarreno.medium.com/exponential-backoff-and-retry-patterns-in-mobile-80232107c22
- Reconnection UX state events: https://github.com/appwrite/appwrite/issues/11939
- Session folder picker UX pitfalls (Claude Desktop): https://github.com/anthropics/claude-code/issues/30642 | https://github.com/anthropics/claude-code/issues/56688
- Flutter tab state preservation (AutomaticKeepAlive): https://medium.com/@punnyarthabanerjee/flutter-hold-your-tab-bar-state-while-navigating-or-building-f51ef9b93082
