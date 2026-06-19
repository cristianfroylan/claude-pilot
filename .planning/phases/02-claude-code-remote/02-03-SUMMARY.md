---
phase: 02-claude-code-remote
plan: "03"
subsystem: terminal/voice
tags: [flutter, voice, speech-to-text, input-bar, bottom-sheet, android]
dependency_graph:
  requires: [02-01]
  provides: [voice-dictation, mic-button, voice-review-sheet]
  affects:
    - pubspec.yaml
    - android/app/src/main/AndroidManifest.xml
    - lib/features/terminal/widgets/voice_bottom_sheet.dart
    - lib/features/terminal/widgets/input_bar.dart
tech_stack:
  added: [speech_to_text ^7.4.0]
  patterns: [SpeechToText-initState-lifecycle, SpeechListenOptions, showModalBottomSheet-isScrollControlled, Semantics-mic-button, VoiceBottomSheet-onSend-callback]
key_files:
  created:
    - lib/features/terminal/widgets/voice_bottom_sheet.dart
  modified:
    - pubspec.yaml
    - android/app/src/main/AndroidManifest.xml
    - lib/features/terminal/widgets/input_bar.dart
decisions:
  - "speech_to_text substituted for android_intent_plus (pre-approved by user) — android_intent_plus has no launchForResult; speech_to_text returns transcripts via onResult callback"
  - "SpeechListenOptions used instead of deprecated top-level listen() params (listenFor/pauseFor/localeId) — A2 assumption from plan applied"
  - "withValues(alpha:) used instead of deprecated withOpacity() in VoiceBottomSheet drag handle"
  - "localeId: null passed in SpeechListenOptions — device default locale, per Open Question 1 Claude's Discretion"
metrics:
  duration: "~8m"
  completed: "2026-06-19"
  tasks_completed: 3
  tasks_total: 5
  files_modified: 4
---

# Phase 2 Plan 03: Voice Dictation Summary

Voice dictation end-to-end: mic button in InputBar captures speech via `speech_to_text` 7.4.0, presents final transcript in a review bottom sheet (VoiceBottomSheet), and sends `transcript + '\n'` to the PTY only on explicit "Send message" tap — never auto-sends.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Approve android_intent_plus → speech_to_text substitution | (pre-approved by user — no commit) | none |
| 2 | Verify speech_to_text legitimacy before install | (pre-approved by user — no commit) | none |
| 3 | Add speech_to_text dependency and AndroidManifest permissions | f430f42 | pubspec.yaml, pubspec.lock, AndroidManifest.xml |
| 4 | Create VoiceBottomSheet review widget | 5fe0b3f | voice_bottom_sheet.dart |
| 5 | Wire mic button + speech_to_text lifecycle into InputBar | 9054c76 | input_bar.dart |

## What Was Built

**Task 3** added `speech_to_text ^7.4.0` (resolved 7.4.0, publisher csdcorp.com) to pubspec.yaml via `flutter pub add`. Updated AndroidManifest.xml with `RECORD_AUDIO` permission and merged `android.speech.RecognitionService` intent into the existing single `<queries>` block.

**Task 4** created `lib/features/terminal/widgets/voice_bottom_sheet.dart` — a `StatelessWidget` with `transcript` (displayed as `SelectableText` in a read-only container) and `onSend` callback. Layout: drag handle, "Review your message" heading (bodyMedium w600), transcript container (surfaceContainerHighest, radius 8, padding 12), then an action Row with Discard `TextButton` and "Send message" `FilledButton`. Discard calls `Navigator.of(context).pop()` only; Send calls `onSend()`. Padding respects `MediaQuery.viewInsets.bottom` for keyboard insets.

**Task 5** wired `SpeechToText` into `_InputBarState`: added `_speech` field and `_voiceAvailable` bool, `initState`/`dispose` lifecycle, `_launchVoiceRecognition()` (gates on `finalResult`, calls `_speech.stop()` before showing the sheet), and `_showReviewSheet()` (uses `showModalBottomSheet` with `isScrollControlled: true`). Mic `IconButton` (Icons.mic, size 20, 36x36) inserted between `Spacer` and arrow keys, wrapped in `Semantics(label: 'Start voice input')`, hidden via `if (_voiceAvailable)` when unavailable.

## Requirements Delivered

| Requirement | Delivered |
|-------------|-----------|
| VOZ-01 | Mic button triggers speech recognition; transcript captured and displayed |
| VOZ-02 | Send button explicitly sends transcript + newline to PTY |
| VOZ-03 | Discard button dismisses sheet without sending anything |
| VOZ-04 | Mic button hidden when speech_to_text.initialize() returns false; no error shown |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] SpeechListenOptions instead of deprecated top-level params**
- **Found during:** Task 5
- **Issue:** The plan's `_speech.listen(listenFor:, pauseFor:, localeId:)` call uses top-level params deprecated in speech_to_text 7.4.0. `flutter analyze` reported 3 deprecation infos. This matches the plan's own A2 assumption: "If `listen(listenFor:/pauseFor:)` top-level params fail to compile, wrap them in SpeechListenOptions(...)".
- **Fix:** Replaced with `listenOptions: SpeechListenOptions(listenFor: ..., pauseFor: ..., localeId: null)`.
- **Files modified:** lib/features/terminal/widgets/input_bar.dart
- **Commit:** 9054c76

**2. [Rule 2 - Missing functionality] withValues() instead of deprecated withOpacity()**
- **Found during:** Task 4
- **Issue:** `colorScheme.onSurfaceVariant.withOpacity(0.4)` is deprecated in recent Flutter SDK. `flutter analyze` reported an info warning.
- **Fix:** Replaced with `.withValues(alpha: 0.4)`.
- **Files modified:** lib/features/terminal/widgets/voice_bottom_sheet.dart
- **Commit:** 5fe0b3f

## Known Stubs

None — the mic button wires directly to `SpeechToText` and `sshSessionProvider.notifier.sendText`. VoiceBottomSheet accepts and renders the transcript as received. No hardcoded empty values or placeholder text.

## Threat Flags

No new threat surface beyond what the plan's threat model covers. All new network/permission surface (RECORD_AUDIO, RecognitionService query) is declared in AndroidManifest.xml and managed by the OS speech dialog — consistent with T-02-08. No new endpoints or auth paths introduced.

## Self-Check: PASSED

- [x] pubspec.yaml contains `speech_to_text: ^7.4.0`
- [x] AndroidManifest.xml contains exactly one `<queries>` block
- [x] AndroidManifest.xml contains RECORD_AUDIO
- [x] AndroidManifest.xml contains android.speech.RecognitionService
- [x] lib/features/terminal/widgets/voice_bottom_sheet.dart exists with `class VoiceBottomSheet`
- [x] lib/features/terminal/widgets/input_bar.dart contains `_voiceAvailable`, `_speech.initialize`, `_speech.cancel`, `Semantics`, `Start voice input`
- [x] Commit f430f42 exists (Task 3)
- [x] Commit 5fe0b3f exists (Task 4)
- [x] Commit 9054c76 exists (Task 5)
- [x] `flutter analyze lib/features/terminal/widgets/voice_bottom_sheet.dart` — No issues found
- [x] `flutter analyze lib/features/terminal/widgets/input_bar.dart` — No issues found
