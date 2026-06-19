# Phase 2: Claude Code Remote - Research

**Researched:** 2026-06-19
**Domain:** Flutter Android — voice input (speech_to_text), terminal stdout interception (Riverpod StreamNotifier), quick command panel (InputBar extension), AndroidManifest integration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Quick Commands Panel**
- Organized inside the existing expandable panel (`InputBar`) as labeled sections below the control signals
- Section labels: **Claude** (/clear, /compact, /help, /cost, /gsd), **Shell** (cd ~, cd .., ls, pwd), **Session** (claude, claude ., exit, q)
- Arrow keys (↑↓←→) remain in the main InputBar row
- Tapping any text command sends it immediately with `\n` appended (one-tap execution)
- Panel is a vertically scrollable `Wrap` with small `Text` section headers above each group — same `ActionChip` style as existing control signal chips
- Panel stays open after a tap

**Voice Input**
- Implementation: `ACTION_RECOGNIZE_SPEECH` Android intent via `android_intent_plus` package (or equivalent) — no speech_to_text package needed; system ASR handles all platform concerns
- Trigger: `IconButton(Icons.mic)` placed in the main InputBar row between the Command toggle and the arrow keys
- Review UX: on recognition result, show a `ModalBottomSheet` with the transcribed text, a **Send** `FilledButton`, and a **Cancel** `TextButton`
- Unavailability (VOZ-04): wrap `startActivityForResult` in try-catch; if unavailable, hide mic button using a `_voiceAvailable` bool; no error shown

**Permission Approval Card**
- Detection: monitor terminal output via a `StreamProvider` that scans the xterm Terminal buffer or intercepts `safeWrite` calls in `SshSession`; match against regex constant `kPermissionPattern` in `permission_detector.dart`
- Card position: `Column` child in `TerminalScreen` between `TerminalViewWrapper` and `InputBar`; slides in via `AnimatedSwitcher`
- Card content: last matched terminal line (truncated 80 chars) + [Approve] (FilledButton, sends `y\n`) + [Reject] (OutlinedButton, sends `n\n`)
- Dismiss: button tap or pattern cleared from buffer

### Claude's Discretion
- Exact regex tuning — start with `kPermissionPattern` constant, adjust if Claude Code output format differs
- `android_intent_plus` vs alternative package for ACTION_RECOGNIZE_SPEECH
- Exact padding/sizing of the permission card and bottom sheet layout
- Whether to debounce the permission pattern check (avoid flickering on rapid output)

### Deferred Ideas (OUT OF SCOPE)
- Custom user-defined quick commands (PERS-01) — v2
- iOS voice support — ACTION_RECOGNIZE_SPEECH is Android-only; iOS equivalent deferred to v2
- Push notifications when Claude finishes — v2
- Permission card timeout auto-dismiss — manual-only for now

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CMD-01 | Panel colapsable con slash commands de Claude Code (/clear, /compact, /gsd, /help, /cost) | InputBar extension pattern — add labeled `ActionChip` sections inside existing expandable `Wrap` |
| CMD-02 | Panel incluye comandos de navegación (cd ~, cd .., ls, pwd) | Same chip pattern; `sendText('cd ~\n')` via existing `SshSession.sendText()` |
| CMD-03 | Panel incluye señales de salida (\q, q) | Chips sending `'q\n'` — no new bytes API needed |
| CMD-04 | Panel incluye comandos de sesión (claude, claude ., exit) | Same chip + sendText pattern |
| CMD-05 | Usuario puede navegar el historial de comandos (↑ y ↓ del shell) | Already implemented in Phase 1 via arrow bytes; arrow keys remain in main row |
| VOZ-01 | Usuario puede mantener presionado el botón de micrófono para dictar un prompt | `speech_to_text.listen()` triggered by mic tap — system handles visual, timeout, and press model |
| VOZ-02 | Al soltar, el texto transcrito aparece en el campo de input para revisión | `SpeechRecognitionResult.recognizedWords` fed into ModalBottomSheet on `finalResult` |
| VOZ-03 | El texto transcrito no se envía automáticamente — el usuario revisa y toca enviar | ModalBottomSheet with explicit Send/Discard buttons — never auto-sends |
| VOZ-04 | Si el reconocimiento de voz no está disponible, el botón se oculta gracefully | `speech.initialize()` returns `false` → `_voiceAvailable = false` → `if (_voiceAvailable) IconButton(...)` |
| APRO-01 | Cuando Claude Code muestra un prompt de permiso, aparece una card con [Aprobar] y [Rechazar] | `StreamController` in `SshSession.safeWrite` interceptor → Riverpod `StreamNotifier` → `ref.watch` in TerminalScreen |
| APRO-02 | Tap en Aprobar envía "y" + Enter a la terminal | `sshSessionProvider.notifier.sendText('y\n')` |
| APRO-03 | Tap en Rechazar envía "n" + Enter a la terminal | `sshSessionProvider.notifier.sendText('n\n')` |

</phase_requirements>

---

## Summary

Phase 2 adds three Android-only features on top of the Phase 1 SSH terminal: quick command chips, voice dictation, and a permission approval card. The codebase is already well-structured for extension — `SshSession.sendText()` exists, `InputBar` uses the right widget model, and `TerminalScreen` has the `Column` slot for the permission card.

**Critical finding:** The CONTEXT.md decision to use `android_intent_plus` for `ACTION_RECOGNIZE_SPEECH` cannot be implemented as written. `android_intent_plus` (v6.0.0) does not support returning results from launched activities — it has only `launch()`, `canResolveActivity()`, and `getResolvedActivity()`. `ACTION_RECOGNIZE_SPEECH` requires `startActivityForResult` to receive transcription data. The CONTEXT.md explicitly says "or equivalent" in the locked decision. The correct equivalent is `speech_to_text` (v7.4.0, publisher: csdcorp.com), which is already researched and documented in `CLAUDE.md`. The UX produced by `speech_to_text` matches VOZ-01 through VOZ-04: it handles availability detection via `initialize()`, delivers final recognized text via callback (no auto-send), and `initialize()` returning `false` maps directly to the `_voiceAvailable = false` hide-button pattern.

**Permission detection approach:** `Terminal` (xterm) extends `ChangeNotifier` but does not expose new-content events — only layout/title events. The clean approach is to add a `StreamController<String>` to `SshSession` and emit from inside `safeWrite`. A Riverpod `@riverpod` `StreamNotifier` watches `sshSessionProvider` and exposes a `Stream<String?>` (the last matched permission line, or null). `TerminalScreen` uses `ref.watch` on this provider to drive the `AnimatedSwitcher` card slot — no polling, no timer, reactive.

**Primary recommendation:** Use `speech_to_text` (not `android_intent_plus`) for voice; intercept `safeWrite` in `SshSession` for permission detection; extend `InputBar._commands` into a sectioned chip layout.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Quick commands execution | Client (Flutter widget state) | SSH layer (SshSession.sendText) | Command is a UI action that calls an existing PTY write method; no new state layer needed |
| Voice capture | Android OS (SpeechRecognizer API via speech_to_text) | Flutter widget (InputBar) | Platform handles recording, timeout, and error; Flutter only manages initiation and result display |
| Voice review/send decision | Flutter widget (ModalBottomSheet) | SSH layer (sendText) | User decision point; review happens in Flutter, transmission uses existing PTY method |
| Permission pattern detection | Riverpod StreamNotifier (permissionDetectorProvider) | SSH layer (SshSession safeWrite) | Detection logic is reactive state, not view state; lives in provider to allow multiple consumers |
| Permission card display | Flutter widget (TerminalScreen column slot) | Riverpod (ref.watch) | TerminalScreen owns the layout; driven by provider state |
| Permission response | SSH layer (SshSession.sendText) | Flutter widget (tap handler) | Response is a PTY write; widget calls the notifier method |

---

## Standard Stack

### Core (unchanged from Phase 1)
| Library | Version | Purpose | Phase 2 Usage |
|---------|---------|---------|---------------|
| `flutter_riverpod` | 3.3.2 | State management | New `@riverpod` StreamNotifier for permission detection |
| `riverpod_annotation` | 4.0.2 | Code generation annotations | `@riverpod` on new `PermissionDetector` class |
| `riverpod_generator` | 4.0.3 | Build-time code gen | `dart run build_runner build` after new provider |
| `dartssh2` | 2.18.0 | SSH transport + PTY | No change — `safeWrite` intercepted inside existing method |
| `xterm` | 4.0.0 | Terminal rendering | No change — Terminal.write() still called, listener added |

### New Dependency
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| `speech_to_text` | ^7.4.0 | Android ASR — microphone capture, result callback, availability check | `android_intent_plus` cannot return activity results; `speech_to_text` provides the same UX with a simpler Dart API and no platform channel authoring. Publisher: csdcorp.com (verified). [CITED: pub.dev/packages/speech_to_text] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `speech_to_text` | `android_intent_plus` + custom platform channel | `android_intent_plus` has no `launchForResult` — would require writing Kotlin `registerForActivityResult` + `MethodChannel` boilerplate and changing `MainActivity` base class to `FlutterFragmentActivity`. More code, same UX, higher risk. |
| `speech_to_text` | Custom platform channel (bare Kotlin) | Maximum control but same boilerplate as above; `speech_to_text` already wraps this correctly |
| `safeWrite` stream interception | Polling Terminal buffer via timer | Polling adds latency (100-500ms delay) and wastes CPU. Stream interception is zero-latency and idiomatic Dart |
| `safeWrite` stream interception | xterm `Terminal.addListener()` (ChangeNotifier) | `addListener` fires on any Terminal state change (resize, title, etc.), not just new content. Filtering required; `safeWrite` interception is precise |

**Installation:**
```bash
flutter pub add speech_to_text
dart run build_runner build --delete-conflicting-outputs
```

---

## Package Legitimacy Audit

> slopcheck was not available at research time. All packages below are tagged `[ASSUMED]` for the new dependency. The planner must gate the install behind a `checkpoint:human-verify` task.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `speech_to_text` | pub.dev | 6+ years | High (established Flutter ecosystem) | github.com/csdcorp/speech_to_text | not run | [ASSUMED] — planner adds checkpoint |
| `flutter_riverpod` | pub.dev | 4+ years | Very high | github.com/rrousselGit/riverpod | [OK in Phase 1] | Approved (previously verified) |
| `dartssh2` | pub.dev | 3+ years | High | github.com/TerminalStudio/dartssh2 | [OK in Phase 1] | Approved (previously verified) |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none (slopcheck unavailable — all new packages are `[ASSUMED]`)

*`speech_to_text` is published by csdcorp.com, has 6+ years of pub.dev history, and is documented in the project's CLAUDE.md (prior research). Risk is LOW but planner must confirm before install.*

---

## Architecture Patterns

### System Architecture Diagram

```
Mic tap (InputBar)
    │
    ▼
speech_to_text.listen()  ──────────────────────────────────────────┐
    │ onResult callback                                              │
    ▼                                                               │
_SpeechResult (recognizedWords, isFinal=true)                       │ if initialize()
    │                                                               │ returns false:
    ▼                                                               │ _voiceAvailable=false
ModalBottomSheet (read-only transcript)                             │ mic button hidden
    │ Send tap                  │ Discard tap                       │
    ▼                           ▼                                   │
SshSession.sendText             sheet dismissed                     │
(transcript + '\n')             nothing sent                       ──┘

─────────────────────────────────────────────────────────────

SSH stdout stream (dartssh2)
    │
    ▼
SshSession._safeWrite(data)
    │ (1) terminal.write(data)  ← xterm rendering (unchanged)
    │ (2) _permissionController.add(data)  ← NEW: feed StreamController
    │
    ▼
permissionDetectorProvider (StreamNotifier, family(machineId))
    │ listens to _permissionController.stream
    │ regex match → emit last matched line (String?)
    │ no match → emit null
    ▼
TerminalScreen (ref.watch(permissionDetectorProvider(machineId)))
    │
    ▼
AnimatedSwitcher
    ├─ child: PermissionCard(matchedLine)  ← when state != null
    └─ child: SizedBox.shrink()           ← when state == null

PermissionCard buttons:
    [Approve] → SshSession.sendText('y\n') + provider.reset()
    [Reject]  → SshSession.sendText('n\n') + provider.reset()

─────────────────────────────────────────────────────────────

InputBar Command panel (expanded)
    │
    ├─ [Control section] — existing chips (Ctrl+C, Ctrl+D, ESC, Tab)
    │   onPressed: sendBytes([...])
    │
    ├─ [Claude section]  — new chips (/clear, /compact, /help, /cost, /gsd)
    │   onPressed: sendText('/clear\n')
    │
    ├─ [Shell section]   — new chips (cd ~, cd .., ls, pwd)
    │   onPressed: sendText('cd ~\n')
    │
    └─ [Session section] — new chips (claude, claude ., exit, q)
        onPressed: sendText('claude\n')
```

### Recommended Project Structure

```
lib/features/terminal/
├── providers/
│   ├── ssh_session_provider.dart       # MODIFY: add StreamController, expose stream
│   ├── ssh_session_provider.g.dart     # regenerated
│   ├── permission_detector_provider.dart   # NEW: StreamNotifier consuming safeWrite stream
│   └── permission_detector_provider.g.dart # NEW: generated
├── screens/
│   └── terminal_screen.dart            # MODIFY: add ref.watch(permissionDetectorProvider)
│                                       #         add AnimatedSwitcher + PermissionCard slot
├── widgets/
│   ├── input_bar.dart                  # MODIFY: add mic button + sectioned command chips
│   ├── permission_card.dart            # NEW: card widget with Approve/Reject buttons
│   ├── voice_bottom_sheet.dart         # NEW: ModalBottomSheet for transcript review
│   └── terminal_view_wrapper.dart      # unchanged
└── models/
    └── permission_detector.dart        # NEW: kPermissionPattern constant

android/app/src/main/AndroidManifest.xml  # MODIFY: add RECORD_AUDIO + RecognitionService query
pubspec.yaml                              # MODIFY: add speech_to_text
```

### Pattern 1: SshSession StreamController for stdout interception

**What:** Add a `StreamController<String>` to `SshSession`; emit from inside `safeWrite`; expose a getter so the `permissionDetectorProvider` can `ref.watch(sshSessionProvider).when(data: (t) => ...)` — but actually, since the stream is on the notifier (not the Terminal), the detector watches the notifier directly.

**When to use:** Whenever a downstream provider needs to react to raw SSH output without duplicating the stdout subscription.

```dart
// Source: project pattern (SshSession is @riverpod AsyncNotifier<Terminal>)

// Inside SshSession (ssh_session_provider.dart):
final _permissionController = StreamController<String>.broadcast();
Stream<String> get permissionStream => _permissionController.stream;

void _safeWrite(String data) {
  try {
    terminal.write(data);
  } catch (_) {}
  _permissionController.add(data);   // feed ALL stdout chunks to detector
}

// Change both stdout and stderr listeners:
_sshSession!.stdout
    .cast<List<int>>()
    .transform(const Utf8Decoder(allowMalformed: true))
    .listen(_safeWrite);   // was: .listen(safeWrite)

// In ref.onDispose():
_permissionController.close();
```

**Note:** The `SshSession` class exposes `permissionStream` as a public getter. The `permissionDetectorProvider` accesses it via `ref.read(sshSessionProvider(machineId).notifier).permissionStream`.

### Pattern 2: permissionDetectorProvider as StreamNotifier

**What:** A `@riverpod` `StreamNotifier` that subscribes to `SshSession.permissionStream`, applies regex, and emits `String?` (matched line or null).

```dart
// Source: Riverpod 3.x code generation pattern [ASSUMED pattern from riverpod docs]
// File: permission_detector_provider.dart

part 'permission_detector_provider.g.dart';

@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) {
    // Wait for session to be available
    final sessionAsync = ref.watch(sshSessionProvider(machineId));
    return sessionAsync.when(
      loading: () => const Stream.empty(),
      error: (_, __) => const Stream.empty(),
      data: (_) {
        final notifier = ref.read(sshSessionProvider(machineId).notifier);
        return notifier.permissionStream
            .map((chunk) => _detect(chunk))
            .where((line) => true); // emit all — null means "no match"
      },
    );
  }

  String? _detect(String chunk) {
    final lines = chunk.split('\n');
    for (final line in lines.reversed) {
      if (RegExp(kPermissionPattern).hasMatch(line)) {
        final trimmed = line.trim();
        return trimmed.length > 80
            ? '${trimmed.substring(0, 77)}...'
            : trimmed;
      }
    }
    return null;
  }
}
```

**Note:** The `Stream.empty()` pattern means no rebuild is triggered while connecting. The `where` clause is intentionally absent for null — the provider emits `null` to clear the card.

**Alternative (simpler):** If `Stream<String?> build()` in StreamNotifier is complex to wire with `ref.watch`, use a `@riverpod` function provider instead (plain Riverpod `StreamProvider` via function annotation). The planner should decide which is more natural in the existing `@riverpod` codegen style.

### Pattern 3: speech_to_text integration in InputBar

**What:** `SpeechToText` instance managed in `_InputBarState` (`ConsumerStatefulWidget`). Initialize once in `initState`, listen on mic tap, deliver result to ModalBottomSheet.

```dart
// Source: pub.dev/packages/speech_to_text usage example [CITED: pub.dev/packages/speech_to_text]
import 'package:speech_to_text/speech_to_text.dart';

class _InputBarState extends ConsumerState<InputBar> {
  final _speech = SpeechToText();
  bool _voiceAvailable = false;
  bool _commandsVisible = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (mounted) setState(() => _voiceAvailable = available);
  }

  Future<void> _launchVoiceRecognition() async {
    if (!_voiceAvailable || !_speech.isNotListening) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _speech.stop();
          _showReviewSheet(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: 'es_MX',   // or null for device default
    );
  }

  void _showReviewSheet(String transcript) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoiceBottomSheet(
        transcript: transcript,
        onSend: () {
          ref.read(sshSessionProvider(widget.machineId).notifier)
              .sendText('$transcript\n');
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}
```

### Pattern 4: TerminalScreen with permission card slot

**What:** `ref.watch(permissionDetectorProvider(machineId))` in the `Column`; `AnimatedSwitcher` wraps the card slot.

```dart
// Source: CONTEXT.md + UI-SPEC.md design contract [CITED: 02-CONTEXT.md]
// In TerminalScreen.build():
final permissionLine = ref.watch(
  permissionDetectorProvider(machineId),
).valueOrNull ?? ref.watch(permissionDetectorProvider(machineId)).asData?.value;

// Column children:
Expanded(child: TerminalViewWrapper(...)),
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: (latestMatchedLine != null)
    ? PermissionCard(
        key: const ValueKey('permission-card'),
        line: latestMatchedLine,
        machineId: machineId,
      )
    : const SizedBox.shrink(key: ValueKey('no-card')),
),
InputBar(machineId: machineId),
```

**Note:** `AnimatedSwitcher` requires different `Key` values on its children to trigger the transition animation. Use `ValueKey` on both children.

### Anti-Patterns to Avoid

- **`android_intent_plus.launch()` for voice:** This launches ACTION_RECOGNIZE_SPEECH but cannot receive the result. The app would freeze waiting for data that never arrives. Do not use `android_intent_plus` for any result-returning intent.
- **Polling terminal buffer for permissions:** `Timer.periodic` checking `terminal.buffer` adds ~200ms latency minimum and wastes battery. Use the `safeWrite` stream instead.
- **`SpeechToText` instance in Provider:** `SpeechToText` holds Android callbacks and must be disposed with `cancel()`. It belongs in `_InputBarState` (StatefulWidget) where `dispose()` is guaranteed to fire, not in a provider that might be garbage-collected.
- **Auto-advancing `finalResult`:** Calling `sendText` directly in the `listen` callback skips the user review step and breaks VOZ-03. Always route through the ModalBottomSheet.
- **Forgetting `isScrollControlled: true` on ModalBottomSheet:** Without it, the keyboard inset is not respected and the Send/Discard buttons are hidden behind the keyboard when the user taps the transcript area.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Android speech recognition | Custom platform channel (Kotlin + MethodChannel) | `speech_to_text` 7.4.0 | The platform channel version requires: MainActivity base class change to `FlutterFragmentActivity`, `registerForActivityResult` in Kotlin, channel wiring in both Dart and Kotlin. `speech_to_text` provides the same result with a Dart-only API |
| Regex-only terminal content detection | Re-implementing stdout subscription in detector | StreamController in existing `safeWrite` | Don't create a second subscriber to `_sshSession!.stdout` — dartssh2 stream semantics make multiple listeners fragile. One `StreamController.broadcast()` in `SshSession` is the right single source of truth |
| ANSI color stripping before regex | Custom ANSI parser | Apply regex to raw UTF-8 chunks BEFORE `terminal.write()` — OR strip ANSI escapes with a simple regex `r'\x1b\[[0-9;]*[mGKHF]'` first | xterm stores data in a VT100 model; reading back from the buffer introduces encoding complexity. The raw chunk from stdout is plain UTF-8 (ANSI codes included but regexp still works) |

**Key insight:** The SSH stream is already flowing through one subscriber (`safeWrite`). Tapping into it at that point (StreamController) is the minimal-risk way to add detection without touching dartssh2 internals.

---

## Common Pitfalls

### Pitfall 1: android_intent_plus ACTION_RECOGNIZE_SPEECH returns no result
**What goes wrong:** `AndroidIntent(action: 'android.speech.action.RECOGNIZE_SPEECH').launch()` returns a `Future<void>` — the transcribed text never arrives in Dart.
**Why it happens:** `android_intent_plus` is a fire-and-forget launcher. `ACTION_RECOGNIZE_SPEECH` is documented to require `startActivityForResult` on Android. The package explicitly documents this limitation ("It does not support returning the result of the launched activity").
**How to avoid:** Use `speech_to_text` instead. Do not add `android_intent_plus` to `pubspec.yaml` for this phase.
**Warning signs:** `_launchVoiceRecognition()` completes instantly with no callback; ModalBottomSheet never appears.

### Pitfall 2: speech_to_text Android — missing RECORD_AUDIO permission → initialize() returns false silently
**What goes wrong:** `initialize()` returns `false`, mic button is hidden, no error surfaced — but the root cause is a missing `<uses-permission>` in AndroidManifest.xml, not device unavailability.
**Why it happens:** The permission must be declared even before the runtime request. On Android 6+, the package triggers a runtime request only if the permission is declared in the manifest. Missing declaration → OS never shows the dialog → returns `false`.
**How to avoid:** Add to `AndroidManifest.xml` before running:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
And the queries block:
```xml
<queries>
  <intent>
    <action android:name="android.speech.RecognitionService" />
  </intent>
</queries>
```
**Warning signs:** `initialize()` returns `false` on a physical device that normally has Google Assistant working; mic button never appears even on capable devices.

### Pitfall 3: StreamController in SshSession not closed on dispose
**What goes wrong:** Memory leak — the `StreamController` subscription stays open after the SSH session ends, and the `permissionDetectorProvider` continues to listen on a dead stream.
**Why it happens:** `ref.onDispose()` in `SshSession` must explicitly call `_permissionController.close()`.
**How to avoid:** Add `_permissionController.close()` inside `ref.onDispose()`, after `_sshSession?.close()` and `_client?.close()`.
**Warning signs:** Dart VM reports stream subscription leak warnings in debug mode; provider keeps old data after reconnect.

### Pitfall 4: AnimatedSwitcher not animating because Key values are identical
**What goes wrong:** The permission card appears/disappears with no animation — the SizeTransition/FadeTransition never plays.
**Why it happens:** `AnimatedSwitcher` uses `Key` equality to decide whether to animate. If both the card and `SizedBox.shrink()` have the same key (or no key), Flutter treats them as the same widget and skips the transition.
**How to avoid:** Use distinct `ValueKey` values: `ValueKey('permission-card')` on the card, `ValueKey('no-card')` on `SizedBox.shrink()`.
**Warning signs:** Card appears/disappears instantly with no 200ms fade+size animation.

### Pitfall 5: Permission regex fires on its own output (y/n echo in terminal)
**What goes wrong:** After the user taps Approve and `y\n` is sent, the terminal echoes the `y` back. If the regex is too broad, it re-triggers the permission card for the echo.
**Why it happens:** `kPermissionPattern` matches against all stdout chunks including what the shell echoes back.
**How to avoid:** After sending `y\n` or `n\n`, reset the provider state immediately (emit null) so even if the regex matches the echo, the state is already null and the `AnimatedSwitcher` has already dismissed. The brief window where the echo might re-trigger is suppressed by the provider's null state.
**Warning signs:** Permission card reappears immediately after tapping Approve; enters a dismiss-reappear loop.

### Pitfall 6: speech_to_text onResult called multiple times (partialResults)
**What goes wrong:** `_showReviewSheet` is called multiple times as partial results arrive — multiple ModalBottomSheets stack up.
**Why it happens:** By default, `speech.listen()` delivers partial results before the final one. Each triggers `onResult`.
**How to avoid:** Gate the `_showReviewSheet` call on `result.finalResult == true` only. Stop listening when the sheet is shown:
```dart
onResult: (result) {
  if (result.finalResult && result.recognizedWords.isNotEmpty) {
    _speech.stop();
    if (mounted) _showReviewSheet(result.recognizedWords);
  }
},
```
**Warning signs:** Multiple bottom sheets appearing on one voice recording; `Navigator.pop()` required multiple times.

### Pitfall 7: build_runner not run after adding permissionDetectorProvider
**What goes wrong:** `permission_detector_provider.g.dart` does not exist → compilation error referencing `_$PermissionDetector`.
**Why it happens:** Riverpod code generation requires `dart run build_runner build` after every new `@riverpod` class.
**How to avoid:** Include a Wave 0 task that runs `dart run build_runner build --delete-conflicting-outputs` after scaffold files are created and before any widget references the provider.
**Warning signs:** `Error: 'permissionDetectorProvider' isn't defined` or `Can't open file: permission_detector_provider.g.dart`.

---

## Code Examples

### AndroidManifest.xml additions

```xml
<!-- Source: pub.dev/packages/speech_to_text Android setup [CITED: pub.dev/packages/speech_to_text] -->
<!-- Add inside <manifest> before <application> -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Add inside <queries> block (merge with existing block if present) -->
<queries>
    <!-- Existing: text processing -->
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
    <!-- New: speech recognition service -->
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

### kPermissionPattern constant

```dart
// Source: 02-CONTEXT.md locked decision [CITED: 02-CONTEXT.md]
// File: lib/features/terminal/models/permission_detector.dart

/// Regex targeting Claude Code permission prompts.
/// Version-sensitive: Claude Code output format may change across releases.
/// Update this constant when Claude Code changes its permission message format.
const kPermissionPattern =
    r'(Do you want to|Allow .+ to|Approve .+|\(y\/n\)|\[y\/n\]|✓ Yes|yes\/no)';
```

### Section header widget (for command panel)

```dart
// Source: 02-UI-SPEC.md design contract [CITED: 02-UI-SPEC.md]
Widget _sectionHeader(String label, ColorScheme cs) => Padding(
  padding: const EdgeInsets.only(top: 8, bottom: 2),
  child: Text(
    label,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
    ),
  ),
);
```

### Text command chip

```dart
// Source: project convention (matches existing ActionChip pattern) [ASSUMED]
ActionChip(
  label: Text('/clear', style: const TextStyle(fontSize: 12)),
  onPressed: isConnected
      ? () => ref
            .read(sshSessionProvider(widget.machineId).notifier)
            .sendText('/clear\n')
      : null,
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `startActivityForResult` (Android) | `registerForActivityResult` (AndroidX Activity Result API) | Android API 29 / AndroidX 1.2.0 | `startActivityForResult` is deprecated; `speech_to_text` uses the new API internally — no action needed in Dart code |
| `StateNotifierProvider` (Riverpod 1.x) | `@riverpod` class extending `_$ClassName` (Riverpod 2+/3) | Riverpod 2.0 (2022), enforced in 3.x | Project already uses codegen — all new providers must follow `@riverpod` annotation pattern |
| `SpeechToText.listen(listenOptions:)` (stt <6.x) | `SpeechToText.listen(listenFor:, pauseFor:)` as named params (7.x) | speech_to_text 6.0.0 | API cleanup — use top-level named params, not `SpeechListenOptions` wrapper |

**Deprecated/outdated:**
- `android.permission.BLUETOOTH` / `BLUETOOTH_ADMIN`: Required in older docs; current `speech_to_text` 7.x docs only require `RECORD_AUDIO` and `INTERNET` for voice-over-Bluetooth scenarios. Include `BLUETOOTH_CONNECT` only if supporting Bluetooth headset input explicitly (not required for v1). [ASSUMED — confirm against speech_to_text 7.4.0 CHANGELOG]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `speech_to_text` handles RECORD_AUDIO runtime permission request automatically via `initialize()` (the OS dialog appears without `permission_handler`) | Standard Stack / Pattern 3 | Developer must add `permission_handler` dependency and explicit permission request step — one extra task in Wave 1 |
| A2 | `SpeechToText.listen()` in v7.4.0 accepts `listenFor` and `pauseFor` as top-level named params (not inside `SpeechListenOptions`) | Code Examples / Pattern 3 | Compilation error on the `listen()` call — fix by wrapping in `SpeechListenOptions(listenFor:, pauseFor:)` |
| A3 | The `PermissionDetector.build()` method returning `Stream<String?>` with a `ref.watch(sshSessionProvider)` inside the StreamNotifier is valid in Riverpod 3.3.2 codegen | Architecture Patterns / Pattern 2 | Provider compilation failure — fallback: use a plain `@riverpod` function returning `Stream<String?>` by watching the session provider and merging with the stream |
| A4 | BLUETOOTH permissions are NOT required for `speech_to_text` 7.4.0 on Android when only using device microphone (no Bluetooth headset) | Standard Stack | Android build warning or microphone unavailable on Bluetooth devices — fix by adding BLUETOOTH_CONNECT |
| A5 | `speech_to_text` 7.4.0 is compatible with the project's `compileSdk = 36` and `minSdk = flutter.minSdkVersion` (which resolves to 21) | Standard Stack | Build failure — likely fixable by raising minSdk, which the package requires to be >= 21 |

---

## Open Questions

1. **`speech_to_text` locale**
   - What we know: `listen(localeId: 'es_MX')` sets the recognition language; passing `null` uses the device default
   - What's unclear: The user's device locale — if the device is set to Spanish, passing null works fine; if English, Spanish commands to Claude won't transcribe well
   - Recommendation: Pass `null` initially (device default); the user's device is likely already in the preferred locale. This is a Claude's Discretion item.

2. **Partial-results-only mode vs final-only**
   - What we know: `speech_to_text` delivers partial updates during recognition before a final result
   - What's unclear: Whether showing partial text in the bottom sheet (live update) provides value given the small prompt size
   - Recommendation: Final-only (`if (result.finalResult)`) for v1 simplicity. Avoids the stateful sheet complexity of live-updating transcript text.

3. **`kPermissionPattern` accuracy for current Claude Code version**
   - What we know: The regex covers common patterns; Claude Code output format is version-sensitive (noted in STATE.md blockers)
   - What's unclear: The exact strings Claude Code uses in its current release for tool approval prompts
   - Recommendation: The CONTEXT.md acknowledges this — maintain the constant in a dedicated file for easy update. Do not expand the pattern without testing against real Claude Code output.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Dart/Flutter code | ✓ | 3.41.9 (stable) | — |
| Android build toolchain | Android APK build | ✓ (build.gradle.kts exists with compileSdk 36) | compileSdk 36 / minSdk 21 | — |
| `build_runner` | Riverpod codegen (`@riverpod`) | ✓ (in dev_dependencies) | current | — |
| Physical Android device or emulator | Testing voice input | Unknown | — | Emulator: Google app needed with mic permission |
| Google app / GMS speech service | `speech_to_text` ASR on Android | Unknown | — | If unavailable: `initialize()` returns `false`, mic button hidden — feature gracefully absent |

**Missing dependencies with no fallback:** None — all build dependencies confirmed present.

**Missing dependencies with fallback:**
- Google speech service on test device: If test device lacks GMS (e.g., stripped AOSP), voice feature self-disables. This is correct VOZ-04 behavior, not a test failure.

---

## Validation Architecture

> `nyquist_validation` is `false` in `.planning/config.json` — validation architecture section SKIPPED.

---

## Security Domain

> This phase adds microphone access (RECORD_AUDIO). No new network connections, no new credential handling, no new authentication flows.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | unchanged from Phase 1 |
| V3 Session Management | no | unchanged from Phase 1 |
| V4 Access Control | no | unchanged from Phase 1 |
| V5 Input Validation | yes — voice transcript sent to PTY | No sanitization needed: transcript is user-authored intent sent directly to their own SSH session. Same threat model as typed input. |
| V6 Cryptography | no | unchanged |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Voice transcript injection (malformed shell command) | Tampering | User reviews transcript in ModalBottomSheet before send — explicit Send tap required. User is authenticated to their own machine. Acceptable for v1. |
| Permission card spoofing (adversarial terminal output) | Spoofing | The SSH session is authenticated and LAN-only. An attacker who can write to the PTY already has SSH access — the card is a UX aid, not a security gate. Acceptable for v1. |

---

## Sources

### Primary (HIGH confidence)
- `pub.dev/packages/android_intent_plus` — confirmed version 6.0.0 (2025-09-11), `launch()` only, no result support [CITED: pub.dev/packages/android_intent_plus]
- `pub.dev/packages/speech_to_text` — confirmed version 7.4.0 (2026-05-19), `initialize()` + `listen()` + `stop()` API, publisher csdcorp.com [CITED: pub.dev/packages/speech_to_text]
- `pub.dev/packages/flutter_riverpod` — confirmed version 3.3.2 (2026-06-10) [CITED: pub.dev/packages/flutter_riverpod]
- Project codebase — `SshSession.safeWrite()` (line 103-108), `Terminal` object lifecycle, `sendText()`/`sendBytes()` signatures, `InputBar` Wrap pattern, `TerminalScreen` Column layout [VERIFIED: codebase grep]
- `pub.dev/documentation/xterm/latest/xterm/Terminal-class.html` — Terminal extends ChangeNotifier, buffer/lines API, onOutput callback [CITED: pub.dev/documentation/xterm/]
- `android/app/src/main/AndroidManifest.xml` — existing queries block, no RECORD_AUDIO declared [VERIFIED: codebase read]
- `android/app/build.gradle.kts` — compileSdk 36, minSdk = flutter.minSdkVersion, targetSdk 34 [VERIFIED: codebase read]
- `android/app/src/main/kotlin/.../MainActivity.kt` — extends `FlutterActivity` (not FlutterFragmentActivity) [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- android_intent_plus GitHub README: no launchForResult API exists in any released version [CITED: github.com/fluttercommunity/plus_plugins]
- speech_to_text GitHub README: AndroidManifest requirements, queries block for RecognitionService [CITED: github.com/csdcorp/speech_to_text]
- Flutter platform channels official docs: MethodChannel pattern, FlutterFragmentActivity for registerForActivityResult [CITED: docs.flutter.dev/platform-integration/platform-channels]

### Tertiary (LOW confidence / [ASSUMED])
- Riverpod 3.x `StreamNotifier.build()` returning `Stream<String?>` with `ref.watch` inside — based on training knowledge of Riverpod codegen patterns; not verified against live Context7 docs this session [ASSUMED]
- `speech_to_text` runtime permission auto-request behavior — multiple sources suggest `initialize()` triggers OS dialog without `permission_handler`, but not confirmed from official source [ASSUMED]
- BLUETOOTH permissions not required for device microphone in speech_to_text 7.4.0 [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — packages verified on pub.dev API; critical `android_intent_plus` limitation confirmed via official package docs
- Architecture: HIGH — based on verified codebase structure; `safeWrite` interception pattern is straightforward Dart stream composition
- Pitfalls: HIGH for android_intent_plus/voice (verified), MEDIUM for regex edge cases (runtime behavior, not verifiable statically)
- Validation: SKIPPED (`nyquist_validation: false`)

**Research date:** 2026-06-19
**Valid until:** 2026-07-19 (speech_to_text and riverpod are active; check for minor version bumps before install)
