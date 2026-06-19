---
phase: 02-claude-code-remote
verified: 2026-06-19T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification: false
human_verification:
  - test: "Open command panel on device, tap /clear, verify it echoes in terminal and panel stays open"
    expected: "/clear command appears in terminal output; the command panel remains visible for further taps"
    why_human: "Cannot verify PTY write round-trip, terminal rendering, or panel-open behavior without a running device"
  - test: "Tap mic button, speak a short phrase, review transcript in bottom sheet, tap Send message"
    expected: "Transcript appears in the review sheet read-only; tapping Send message sends transcript + newline to terminal; tapping Discard sends nothing"
    why_human: "Voice recognition requires physical device (or emulator with Google app), runtime microphone permission, and live SSH session"
  - test: "Trigger a Claude Code permission prompt (e.g. by running a tool that requests approval), observe the card"
    expected: "A card slides in above InputBar showing the matched permission line with Approve and Reject buttons"
    why_human: "Requires live Claude Code session outputting a permission prompt — cannot simulate stdout chunk via grep"
  - test: "Tap Approve on the permission card"
    expected: "'y' is sent to the terminal, the card dismisses immediately with no flicker or re-appearance"
    why_human: "Requires live Claude Code session to observe correct y/n echo behavior and card dismissal timing"
  - test: "On a device without speech recognition (or deny microphone permission), observe InputBar"
    expected: "The mic button is absent from the row; no error message or visible placeholder is shown"
    why_human: "Requires a device or emulator without the Google speech service installed"
---

# Phase 2: Claude Code Remote — Verification Report

**Phase Goal:** Users can control Claude Code from the phone without typing — quick commands, voice, and permission approvals
**Verified:** 2026-06-19
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can open the quick commands panel and execute any slash command, navigation command, or session command with a single tap — including navigating shell history with up/down arrows | VERIFIED | `input_bar.dart` lines 194–237: four labeled sections (Control/Claude/Shell/Session) with `ActionChip` `textChip()` calling `sendText('${c.command}\n')` via `sshSessionProvider.notifier.sendText`. Arrow keys at lines 289–292 send bytes `_arrowUp`/`_arrowDown` via `arrowBtn()`. Panel stays open (`_commandsVisible` never set false in text chip handlers). |
| 2 | User can hold the microphone button, dictate a prompt, release, review the transcribed text in the input field, and explicitly tap send — voice never auto-submits | VERIFIED | `input_bar.dart` lines 94–125: `_launchVoiceRecognition()` gates on `result.finalResult`, calls `_showReviewSheet()` which opens `VoiceBottomSheet` via `showModalBottomSheet(isScrollControlled: true)`. `VoiceBottomSheet` shows `SelectableText` read-only, Discard calls `Navigator.pop()` only, Send calls `onSend()` which calls `sendText('$transcript\n')`. Auto-submit is structurally impossible. |
| 3 | When Claude Code displays a permission prompt, a card appears automatically with Approve and Reject buttons that send the correct response to the terminal | VERIFIED | Full pipeline wired: `ssh_session_provider.dart` line 112 feeds all stdout to `_permissionController.add(data)`; `permission_detector_provider.dart` maps stream via `_detect()` (regex scan, returns matched line or null); `terminal_screen.dart` lines 150–159 drives `AnimatedSwitcher` with `PermissionCard`; `permission_card.dart` lines 25–35: Approve sends `'y\n'`, Reject sends `'n\n'`, both call `ref.invalidate(permissionDetectorProvider(machineId))` immediately after. |
| 4 | If voice recognition is unavailable on the device, the microphone button is hidden with no visible error | VERIFIED | `input_bar.dart` lines 273–286: mic `IconButton` is wrapped in `if (_voiceAvailable)`. `_initSpeech()` (lines 80–86) sets `_voiceAvailable = available` where `available` is the return value of `_speech.initialize()` — false when no service or permission denied. No error widget, no placeholder, no visible indication when false. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/features/terminal/widgets/input_bar.dart` | Sectioned command panel with text-command ActionChips calling sendText | VERIFIED | Contains `_TextCmd`, `_claudeCommands`, `_shellCommands`, `_sessionCommands`, `textChip()`, `sectionHeader()`, `SingleChildScrollView` + `ConstrainedBox(maxHeight:240)`, arrow buttons in main row, mic button guarded by `if (_voiceAvailable)`, `SpeechToText` lifecycle |
| `lib/features/terminal/models/permission_detector.dart` | kPermissionPattern regex constant | VERIFIED | Contains `const kPermissionPattern = r'(Do you want to|Allow .+ to|Approve .+|\(y\/n\)|\[y\/n\]|✓ Yes|yes\/no)'` |
| `lib/features/terminal/providers/permission_detector_provider.dart` | @riverpod StreamNotifier emitting matched permission line or null | VERIFIED | `@riverpod class PermissionDetector extends _$PermissionDetector` with `Stream<String?> build(String machineId)`, gates on session state, maps `permissionStream` via `_detect()`, truncates to 80 chars, returns null on no match |
| `lib/features/terminal/providers/permission_detector_provider.g.dart` | Generated Riverpod code | VERIFIED | File exists; `permissionDetectorProvider = PermissionDetectorFamily._()` present |
| `lib/features/terminal/widgets/permission_card.dart` | Card with Approve (FilledButton) / Reject (OutlinedButton) actions | VERIFIED | `class PermissionCard extends ConsumerWidget` with `machineId`/`line`; Approve sends `'y\n'`, Reject sends `'n\n'`, both `ref.invalidate(permissionDetectorProvider(machineId))`; uses `Icons.lock_outline`, `colorScheme.error` on Reject |
| `lib/features/terminal/widgets/voice_bottom_sheet.dart` | Read-only transcript review sheet with Send/Discard | VERIFIED | `class VoiceBottomSheet extends StatelessWidget` with `transcript`/`onSend`; `SelectableText` read-only; Discard calls `Navigator.of(context).pop()` only; Send calls `onSend()` |
| `lib/features/terminal/screens/terminal_screen.dart` | AnimatedSwitcher driven by permissionDetectorProvider | VERIFIED | Imports `permission_detector_provider.dart` and `permission_card.dart`; watches `permissionDetectorProvider(machineId).asData?.value`; `AnimatedSwitcher(200ms)` with `ValueKey('permission-card')` and `ValueKey('no-card')` |
| `lib/features/terminal/providers/ssh_session_provider.dart` | Broadcast StreamController feeding stdout to detector | VERIFIED | `final _permissionController = StreamController<String>.broadcast()` (line 35); `get permissionStream` (line 38); `_permissionController.add(data)` in `safeWrite` (line 112); `_permissionController.close()` in `ref.onDispose` (line 49); no debug `print()` |
| `pubspec.yaml` | speech_to_text dependency | VERIFIED | `speech_to_text: ^7.4.0` at line 20 |
| `android/app/src/main/AndroidManifest.xml` | RECORD_AUDIO permission + RecognitionService query | VERIFIED | `RECORD_AUDIO` at line 5; `android.speech.RecognitionService` at line 52; exactly one `<queries>` block |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `input_bar.dart` | `sshSessionProvider.notifier.sendText` | `textChip()` `onPressed` closure calling local `sendText()` | WIRED | `sendText()` closure lines 142–147 calls `ref.read(sshSessionProvider(widget.machineId).notifier).sendText(text)`; text chips call `sendText('${c.command}\n')` |
| `ssh_session_provider.dart` | `_permissionController.add` | `safeWrite` interception | WIRED | Line 112: `_permissionController.add(data)` inside `safeWrite` after `terminal.write(data)` |
| `permission_detector_provider.dart` | `permissionStream` | `ref.read(sshSessionProvider(machineId).notifier).permissionStream` | WIRED | Lines 25–26: `final notifier = ref.read(...notifier); return notifier.permissionStream.map(_detect)` |
| `terminal_screen.dart` | `PermissionCard` | `AnimatedSwitcher` driven by `permissionDetectorProvider` | WIRED | Lines 150–159: `AnimatedSwitcher` child is `PermissionCard(...)` when `permissionLine != null` |
| `permission_card.dart` | `sshSessionProvider.notifier.sendText` | Approve/Reject button `onPressed` | WIRED | Lines 25 and 32: `ref.read(sshSessionProvider(machineId).notifier).sendText('y\n'/'n\n')` |
| `input_bar.dart` | `SpeechToText.initialize` | `initState` → `_initSpeech()` | WIRED | Lines 80–86: `await _speech.initialize(...)` sets `_voiceAvailable` |
| `input_bar.dart` | `VoiceBottomSheet` | `showModalBottomSheet` on `finalResult` | WIRED | Lines 111–125: `_showReviewSheet()` calls `showModalBottomSheet` with `VoiceBottomSheet` |
| `voice_bottom_sheet.dart` | `sshSessionProvider.notifier.sendText` | `onSend` callback | WIRED | `onSend` defined in `_showReviewSheet` (line 117–122): calls `.sendText('$transcript\n')` then `Navigator.pop()` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `PermissionCard` | `line` (permission text) | `permissionDetectorProvider` → `_detect()` scanning stdout chunks from `permissionStream` → SSH session stdout | Yes — raw PTY stdout decoded via `Utf8Decoder`, fed into broadcaster, regex-scanned per chunk | FLOWING |
| `VoiceBottomSheet` | `transcript` | `SpeechToText.listen()` `onResult.recognizedWords` (OS speech recognizer) | Yes — `recognizedWords` is populated by the system speech service, not hardcoded | FLOWING |
| `InputBar` (commands panel) | `_claudeCommands`, `_shellCommands`, `_sessionCommands` | Compile-time constants | N/A — constant data is correct for this use case (chips are static commands) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `flutter analyze` — no issues across full project | `flutter analyze` | No issues found (ran in 2.3s) | PASS |
| `speech_to_text` in pubspec | `grep "speech_to_text:" pubspec.yaml` | `speech_to_text: ^7.4.0` | PASS |
| `RECORD_AUDIO` in manifest | `grep "RECORD_AUDIO" AndroidManifest.xml` | Found at line 5 | PASS |
| Single `<queries>` block (not duplicated) | `grep -c "<queries>" AndroidManifest.xml` | 1 | PASS |
| `android.speech.RecognitionService` in manifest | `grep "RecognitionService" AndroidManifest.xml` | Found at line 52 | PASS |
| `permission_detector_provider.g.dart` exists | `ls` check | EXISTS | PASS |
| Commits exist for all three plans | `git log --oneline` | `01afd70`, `5c40075`, `fec09b6`, `01afd70`, `93c48a6`, `9f46c09`, `2831e0e`, `f430f42`, `5fe0b3f`, `9054c76` | PASS |
| `_commandsVisible` never set false in text chip handlers | grep | Only set in Command toggle `onPressed` (setState toggle); never in `textChip()` `onPressed` | PASS |

### Probe Execution

No conventional probe scripts found (`scripts/*/tests/probe-*.sh` not present). Step 7c: SKIPPED (no probe scripts for this phase).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|------------|------------|-------------|--------|---------|
| CMD-01 | 02-01 | Panel has /clear, /compact, /gsd, /help, /cost as tappable chips | SATISFIED | `_claudeCommands` (lines 32–38): all five chips present |
| CMD-02 | 02-01 | Panel has cd ~, cd .., ls, pwd chips | SATISFIED | `_shellCommands` (lines 40–45): all four chips present |
| CMD-03 | 02-01 | Panel has \q and q chips | SATISFIED | `_sessionCommands` (lines 47–53): `_TextCmd('q', 'q')` and `_TextCmd('\\q', '\\q')` both present |
| CMD-04 | 02-01 | Panel has claude, claude ., exit chips | SATISFIED | `_sessionCommands`: `claude`, `claude .`, `exit` present |
| CMD-05 | 02-01 | Up/Down arrow keys still present in main InputBar row | SATISFIED | `arrowBtn(Icons.arrow_upward, _arrowUp)` and `arrowBtn(Icons.arrow_downward, _arrowDown)` at lines 290–291 |
| VOZ-01 | 02-03 | Mic button visible in InputBar (when voice available) | SATISFIED | `if (_voiceAvailable)` block lines 273–286: `IconButton` with `Icons.mic` |
| VOZ-02 | 02-03 | Tapping mic → dictate → transcription appears in bottom sheet for review | SATISFIED | `_showReviewSheet()` (lines 111–125) opens `VoiceBottomSheet(transcript: ...)` |
| VOZ-03 | 02-03 | Voice never auto-submits — user must tap Send explicitly | SATISFIED | `VoiceBottomSheet.onSend` is only triggered by `FilledButton('Send message').onPressed`; Discard calls `pop()` only |
| VOZ-04 | 02-03 | Mic button hidden if voice recognition unavailable | SATISFIED | `if (_voiceAvailable)` guard — no fallback widget rendered when false |
| APRO-01 | 02-02 | When Claude Code shows a permission prompt, a card appears above InputBar | SATISFIED | Full stdout → detector → `AnimatedSwitcher` → `PermissionCard` pipeline wired |
| APRO-02 | 02-02 | Tapping Approve sends y + newline to terminal | SATISFIED | `_approve()` line 25: `sendText('y\n')` |
| APRO-03 | 02-02 | Tapping Reject sends n + newline to terminal | SATISFIED | `_reject()` line 32: `sendText('n\n')` |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `input_bar.dart` | 55 | Stale doc comment: "mic placeholder" — the mic is fully implemented; doc comment predates Plan 02-03 | INFO | No functional impact; doc comment is cosmetically stale |

No debt markers (`TBD`, `FIXME`, `XXX`) found in any phase-modified file.

The `return null` at `permission_detector_provider.dart:48` is the correct sentinel value in the `_detect()` method signaling no permission prompt matched — not a stub.

### Human Verification Required

#### 1. Quick Commands Panel — Live Device Tap

**Test:** Connect to an SSH machine, open the command panel by tapping "Command", then tap the `/clear` chip. Observe the terminal and the panel.
**Expected:** The `/clear` command (with newline) echoes in the terminal; Claude Code processes it; the command panel remains open for additional taps.
**Why human:** PTY write round-trip, terminal ANSI rendering, and panel-open state are not verifiable without a running device and live SSH session.

#### 2. Session Chips — \q and q

**Test:** Open command panel, navigate to Session section, verify both `q` and `\q` chips are visible, tap `\q`.
**Expected:** The literal two-character string `\q` (backslash + q) is sent to the PTY, not a tab or escape sequence.
**Why human:** Requires visual confirmation that the chip label renders as `\q` and the correct bytes reach the PTY.

#### 3. Voice Dictation — Full Flow

**Test:** On a physical Android device with Google app installed, tap the mic button, speak a short prompt (e.g., "list my files"), release.
**Expected:** A bottom sheet appears with heading "Review your message", the recognized transcript displayed read-only in a container, and two buttons: "Discard" and "Send message". Tapping "Send message" sends the transcript + newline to the terminal. Tapping "Discard" dismisses the sheet without sending anything.
**Why human:** Requires physical device with speech recognition service and live microphone.

#### 4. Permission Approval Card — Live Claude Code Prompt

**Test:** In a Claude Code session, trigger an action requiring permission (e.g., file write). Observe the terminal screen.
**Expected:** A card appears above InputBar showing the permission line (truncated to 80 chars if long) with a lock icon, "Reject" (outlined, red) button, and "Approve" (filled) button.
**Why human:** Requires live Claude Code output containing a permission pattern matching `kPermissionPattern` regex.

#### 5. Permission Card Dismissal — No Flicker

**Test:** Tap "Approve" on the permission card.
**Expected:** `y` is sent to the terminal, the card dismisses instantly (no re-appearance or flicker after the `y` echo).
**Why human:** The race condition mitigation (via `ref.invalidate`) needs visual confirmation that the card does not re-appear when the echoed `y` arrives.

#### 6. Voice Unavailability — Hidden Mic

**Test:** On a device without a speech recognition service (or after denying microphone permission), open the terminal screen.
**Expected:** The mic button is absent from the InputBar row; no error message, placeholder icon, or greyed-out button is visible.
**Why human:** Requires a device or emulator configuration without the Google speech service, or ability to deny the runtime permission.

### Gaps Summary

No technical gaps. All artifacts are fully implemented and wired. All 4 phase success criteria are structurally satisfied in the codebase:

1. Quick commands panel with 4 labeled sections sends commands via `sendText(command + '\n')` with arrow keys intact and panel staying open.
2. Voice pipeline is complete: `SpeechToText.listen()` → `finalResult` gate → `_showReviewSheet()` → `VoiceBottomSheet` (read-only, explicit Send only).
3. Permission approval pipeline is complete: stdout → broadcaster → `PermissionDetector` → `AnimatedSwitcher` → `PermissionCard` (Approve/Reject with immediate `ref.invalidate` dismissal).
4. Voice unavailability is handled by `if (_voiceAvailable)` guard with no fallback widget.

Human verification is required for behavioral confirmation on a live device.

---

_Verified: 2026-06-19T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
