# Phase 2: Claude Code Remote - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 extends the terminal screen with three layers of control-without-typing:

1. **Quick Commands Panel** — the existing expandable Command panel gains labeled sections of text commands (slash commands, shell navigation, session commands) alongside the existing control signals (Ctrl+C/D/ESC/Tab). One tap sends any command immediately with a newline.

2. **Voice Dictation** — a mic button in InputBar launches `ACTION_RECOGNIZE_SPEECH` (Android system ASR intent). The transcribed text is presented in a bottom sheet for user review. The user taps Send to pipe the text to the terminal PTY, or Cancel to discard. If voice recognition is unavailable the button is hidden with no error.

3. **Permission Approval Card** — the terminal screen monitors stdout for Claude Code permission patterns (regex). When detected, a sticky card pins above InputBar showing the last matching line and [Approve ✓] / [Reject ✗] buttons that send `y\n` or `n\n` to the PTY. The card auto-dismisses when the user taps a button or when the pattern clears from terminal output.

Requirements in scope: CMD-01, CMD-02, CMD-03, CMD-04, CMD-05, VOZ-01, VOZ-02, VOZ-03, VOZ-04, APRO-01, APRO-02, APRO-03

</domain>

<decisions>
## Implementation Decisions

### Quick Commands Panel
- Organized inside the existing expandable panel (`InputBar`) as labeled sections below the control signals
- Section labels: **Claude** (/clear, /compact, /help, /cost, /gsd), **Shell** (cd ~, cd .., ls, pwd), **Session** (claude, claude ., exit, q)
- Arrow keys (↑↓←→) remain in the main InputBar row — they are the most frequent navigation action
- Tapping any text command sends it immediately with `\n` appended (one-tap execution)
- Panel is a vertically scrollable `Wrap` with small `Text` section headers above each group — same `ActionChip` style as existing control signal chips
- Panel stays open after a tap (consistent with Phase 1 decision — double Ctrl+C use case)

### Voice Input
- Implementation: `ACTION_RECOGNIZE_SPEECH` Android intent via `android_intent_plus` package (or equivalent) — no speech_to_text package needed; system ASR handles all platform concerns
- Trigger: `IconButton(Icons.mic)` placed in the main InputBar row between the Command toggle and the arrow keys
- Listening UX: intent launches the system speech dialog (Android handles the visual feedback and timeout)
- Review UX: on recognition result, show a `ModalBottomSheet` with the transcribed text (read-only `Text` widget), a **Send** `FilledButton` (pipes text + `\n` to PTY), and a **Cancel** `TextButton` — user always confirms before sending
- Unavailability (VOZ-04): wrap `startActivityForResult` in try-catch; if unavailable (ActivityNotFoundException or empty result on first check), hide the mic button entirely using a `_voiceAvailable` bool checked at widget init; no error shown

### Permission Approval Card
- Detection: monitor terminal output via a `StreamProvider` that scans the xterm Terminal's buffer string or intercepts `safeWrite` calls in `SshSession`; match against regex constant:
  ```dart
  static const permissionPattern = r'(Do you want to|Allow .+ to|Approve .+|\(y\/n\)|\[y\/n\]|✓ Yes|yes\/no)';
  ```
  The regex is a top-level constant in `permission_detector.dart` for easy version-specific updates (flagged in STATE.md as version-sensitive to Claude Code output format)
- Card position: `Column` child in `TerminalScreen` — between `TerminalViewWrapper` and `InputBar`; slides in via `AnimatedSwitcher`
- Card content: one-line excerpt of the last matched terminal line (truncated to 80 chars) + `[Approve ✓]` (FilledButton, sends `y\n`) + `[Reject ✗]` (OutlinedButton, sends `n\n`)
- Dismiss: button tap sends response and hides card; card also hides if the permission pattern is no longer present in the terminal buffer (e.g., Claude already responded)

### Claude's Discretion
- Exact regex tuning — start with the constant above, adjust if Claude Code output format differs
- `android_intent_plus` vs alternative package for ACTION_RECOGNIZE_SPEECH
- Exact padding/sizing of the permission card and bottom sheet layout
- Whether to debounce the permission pattern check (avoid flickering on rapid output)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `InputBar` (`lib/features/terminal/widgets/input_bar.dart`) — `ConsumerStatefulWidget` with `_commandsVisible` bool state, expandable chip panel, `sendBytes()` call via `sshSessionProvider`; extend by adding text-command sections and mic button
- `SshSession.sendBytes()` (`lib/features/terminal/providers/ssh_session_provider.dart`) — already accepts `List<int>`; add `sendText(String)` variant (or use existing one) for text commands + `\n`
- `SshSession.sendText()` — already exists at line 126; sends `utf8.encode(text)` to PTY
- `terminal_screen.dart` — has `ref.listen(sshSessionProvider)` for error handling; can add a `ref.watch(permissionDetectorProvider)` to drive the approval card
- `TerminalViewWrapper` + `TerminalScreen` — `Column` layout already established; permission card slots in naturally

### Established Patterns
- State management: Riverpod `@riverpod` code generation — all new providers follow this pattern
- Error feedback: `showDialog` for connection failures, `SnackBar` for mid-session drops — permission card is a new in-screen widget (not dialog)
- Bytes: `sendBytes([0x03])` for Ctrl+C — text commands use `sendText('cd ~\n')` pattern
- Theming: `Theme.of(context).colorScheme` for all colors — no hardcoded values

### Integration Points
- `android/app/src/main/AndroidManifest.xml` — needs `<queries>` intent block for `ACTION_RECOGNIZE_SPEECH` (Android 11+ requirement)
- `pubspec.yaml` — add `android_intent_plus` (or equivalent) for `ACTION_RECOGNIZE_SPEECH`
- `InputBar` layout: current `Row` is `[Command toggle][Spacer][←↑↓→]` — insert mic `IconButton` between Spacer and first arrow: `[Command toggle][Spacer][🎤][←↑↓→]`

</code_context>

<specifics>
## Specific Ideas

- The permission regex constant must be easy to update — Claude Code output format may change across versions. Name it `kPermissionPattern` and document in a comment that it targets Claude Code vX.Y format.
- Voice: do not implement push-to-talk (hold to record) — `ACTION_RECOGNIZE_SPEECH` launches system dialog which manages its own hold/tap model. The mic button is a simple tap (not hold).
- Quick command tap feedback: brief chip highlight (already built into `ActionChip`) is sufficient — no toast/snackbar needed since the terminal shows the echo.
- `android_intent_plus` package is already in the Flutter ecosystem and well maintained. If the user prefers a different approach, the isolation is in a single method.

</specifics>

<deferred>
## Deferred Ideas

- Custom user-defined quick commands (PERS-01) — v2
- iOS voice support — ACTION_RECOGNIZE_SPEECH is Android-only; iOS equivalent (SFSpeechRecognizer) deferred to v2
- Push notifications when Claude finishes — v2
- Permission card timeout auto-dismiss — decided to keep manual-only for now (no timer logic)

</deferred>
