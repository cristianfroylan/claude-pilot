# Architecture Patterns

**Domain:** Flutter SSH mobile terminal (claude-pilot)
**Researched:** 2026-06-19
**Confidence:** HIGH (dartssh2 and xterm.dart APIs verified via Context7 + official docs)

---

## Recommended Architecture

### Component Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────┐
│                          Flutter UI Layer                        │
│                                                                  │
│  ┌──────────────────┐        ┌────────────────────────────────┐  │
│  │  MachineListScreen│        │       SessionScreen             │  │
│  │  (home / CRUD)   │        │  ┌──────────────────────────┐  │  │
│  │                  │        │  │   TerminalView (xterm)   │  │  │
│  │  MachineCard     │        │  │   (handles ANSI, scroll, │  │  │
│  │  MachineFormSheet│        │  │    resize, 60fps render)  │  │  │
│  └──────┬───────────┘        │  └──────────────────────────┘  │  │
│         │                   │  ┌──────────────────────────┐  │  │
│         │                   │  │   InputBar               │  │  │
│         │                   │  │   (TextField + send btn) │  │  │
│         │                   │  └──────────────────────────┘  │  │
│         │                   │  ┌──────────────────────────┐  │  │
│         │                   │  │   QuickCommandPanel       │  │  │
│         │                   │  │   (collapsible sheet)     │  │  │
│         │                   │  └──────────────────────────┘  │  │
│         │                   └────────────────────────────────┘  │
└─────────┼──────────────────────────────────────┼────────────────┘
          │  watches                             │  watches
          ▼                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Riverpod Providers                         │
│                                                                  │
│  machineRepositoryProvider         sshSessionProvider(machineId)│
│  (StateNotifier<List<Machine>>)    (AsyncNotifier<SessionState>) │
│                                                                  │
│  voiceDictationProvider            quickCommandsProvider        │
│  (Notifier<DictationState>)        (StateNotifier<List<Cmd>>)   │
└─────────────────────────────────────────────────────────────────┘
          │  reads/writes                        │  owns
          ▼                                      ▼
┌─────────────────────┐              ┌───────────────────────────┐
│    MachineRepo      │              │       SshService           │
│                     │              │                            │
│  flutter_secure_    │              │  SSHClient (dartssh2)      │
│  storage (persist)  │              │  SSHSession + PTY          │
│  + in-memory list   │              │  Terminal (xterm model)    │
│                     │              │  StreamSubscriptions       │
└─────────────────────┘              └───────────────────────────┘
                                               │
                                     ┌─────────┴──────────┐
                                     │  SSH byte streams   │
                                     │  (stdout / stderr)  │
                                     │  → UTF-8 decode     │
                                     │  → terminal.write() │
                                     └────────────────────┘
```

---

## Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `MachineListScreen` | Display list of saved machines, trigger connect | `machineRepositoryProvider`, `sshSessionProvider` |
| `MachineFormSheet` | Add / edit machine form (bottom sheet) | `machineRepositoryProvider` |
| `SessionScreen` | Root container for active session | `sshSessionProvider` |
| `TerminalView` (xterm widget) | Render ANSI output at 60fps, scroll, cursor | `Terminal` model (held by `SshService`) |
| `InputBar` | Text field + mic button + send | `sshSessionProvider` (write to stdin), `voiceDictationProvider` |
| `QuickCommandPanel` | Collapsible sheet of tap-to-send commands | `sshSessionProvider` (write to stdin) |
| `SshService` | Own `SSHClient`, `SSHSession`, `Terminal`; wire streams | `sshSessionProvider` |
| `MachineRepository` | CRUD machines, persist with `flutter_secure_storage` | `machineRepositoryProvider` |
| `VoiceService` | Wrap `speech_to_text`, expose state stream | `voiceDictationProvider` |

---

## Data Flow

### SSH Bytes → ANSI → Terminal Widget

```
SSHSession.stdout (Stream<Uint8List>)
    │
    ▼  .cast<List<int>>().transform(Utf8Decoder())
    │
    ▼  terminal.write(string)          ← xterm Terminal model parses ANSI inline
    │                                    (no separate ANSI parser needed;
    │                                     xterm.dart handles all escape sequences)
    ▼
TerminalView widget                    ← repaints at 60fps via ChangeNotifier
    │
    └─ scrollback buffer (maxLines: 2000, configurable)
```

**Critical insight:** xterm.dart's `Terminal` class is the ANSI parser. Do not build a separate one. `terminal.write(utf8String)` accepts raw terminal output including all escape sequences — colors, cursor movement, bold, etc. — and updates internal state. `TerminalView` listens and redraws.

### User Input → SSH stdin

```
InputBar / QuickCommandPanel
    │
    │  session.stdin.add(utf8.encode(text + '\n'))
    ▼
SSHSession.stdin (StreamSink)
    │
    ▼
Remote shell process (bash → Claude Code)
```

### Voice Dictation Flow

```
InputBar (mic GestureDetector: onLongPressStart / onLongPressEnd)
    │
    ├── onLongPressStart → voiceDictationProvider.startListening()
    │       SpeechToText.listen(onResult: callback)
    │       callback updates DictationState.transcript
    │
    └── onLongPressEnd → voiceDictationProvider.stopListening()
            final transcript placed into InputBar's TextEditingController
            user reviews text → taps send
            sends via SSH stdin (same path as typed input)
```

The voice service does NOT auto-send. `finalResult` flag in `SpeechRecognitionResult` marks completion, but the transcript only populates the text field — the user explicitly taps send. This matches the SPEC requirement.

---

## Q&A: Architecture Decisions

### 1. SSH Service Structure: Singleton vs Provider vs Isolate?

**Use a Riverpod `AsyncNotifier` scoped per machine, NOT a global singleton.**

Rationale:
- `sshSessionProvider` takes a `machineId` as a family argument: `sshSessionProvider(machineId)`
- It is `.autoDispose`: when the session screen closes, Riverpod disposes the notifier, which calls `client.close()` and `session.close()` via `ref.onDispose`
- This gives you correct lifecycle: one SSHClient per active session, automatically cleaned up
- No isolate needed for stream processing — dartssh2 is pure Dart and the IO is non-blocking; xterm.dart's `write()` is synchronous but fast (designed for 60fps)

```dart
// Provider definition sketch
@riverpod
class SshSession extends _$SshSession {
  SSHClient? _client;
  SSHSession? _session;

  @override
  Future<Terminal> build(String machineId) async {
    ref.onDispose(() {
      _session?.close();
      _client?.close();
    });
    final machine = await ref.read(machineRepositoryProvider.notifier).get(machineId);
    _client = SSHClient(
      await SSHSocket.connect(machine.host, machine.port),
      username: machine.username,
      onPasswordRequest: () => machine.password,
      keepAliveInterval: const Duration(seconds: 30),
    );
    await _client!.authenticated;
    final terminal = Terminal(maxLines: 2000);
    _session = await _client!.shell(
      pty: SSHPtyConfig(type: 'xterm-256color', width: 80, height: 24),
    );
    _session!.stdout
      .cast<List<int>>()
      .transform(const Utf8Decoder())
      .listen(terminal.write);
    _session!.stderr
      .cast<List<int>>()
      .transform(const Utf8Decoder())
      .listen(terminal.write);
    terminal.onOutput = (data) => _session!.write(utf8.encode(data));
    return terminal;
  }

  void sendInput(String text) => _session?.write(utf8.encode(text));
  void sendBytes(List<int> bytes) => _session?.write(Uint8List.fromList(bytes));
}
```

### 2. Buffering Strategy for High-Frequency Output?

**Let xterm.dart do the buffering. No custom ring buffer needed.**

- xterm.dart's `Terminal` model has a built-in scrollback buffer (`maxLines`, default 1000, recommend 2000 for Claude Code)
- `terminal.write()` is synchronous — it processes the string and updates the model atomically
- `TerminalView` uses Flutter's standard rasterization pipeline (60fps); it does not re-render on every `write()` call but rather on the next frame tick
- The stdout stream is a `Stream<Uint8List>` — Dart's async stream scheduler naturally batches events that arrive in the same microtask queue flush

**The only buffer concern:** if Claude Code produces extremely dense output (thousands of lines/sec), you may see frame drops. Mitigation: set a `StreamTransformer` that groups chunks arriving within a single event loop turn:

```dart
// Optional: batch rapid writes into one terminal.write() call
// to reduce ChangeNotifier notification frequency
stream
  .transform(const Utf8Decoder())
  .bufferTime(Duration(milliseconds: 16)) // ~1 frame
  .map((chunks) => chunks.join())
  .listen(terminal.write);
// Requires rxdart: bufferTime operator
```

For MVP, skip the batching — connect directly. Add `rxdart` batching in Phase 3 if frame drops are observed.

### 3. Terminal State: ChangeNotifier, Riverpod Notifier, or Other?

**The `Terminal` object from xterm.dart IS the state. Do not wrap it.**

- `Terminal` internally extends `ChangeNotifier` (verified in xterm.dart source)
- `TerminalView` listens to it directly via `addListener`
- The Riverpod provider holds the `Terminal` instance and exposes it as `AsyncValue<Terminal>`
- Session screen reads the terminal via `ref.watch(sshSessionProvider(id))` and passes the `Terminal` to `TerminalView`

This means:
- No `TerminalController` wrapping needed for basic use
- No separate state object for terminal lines — the `Terminal` object owns everything
- Use `TerminalController` only if you need programmatic selection or text copy-to-clipboard later (Phase 3 polish)

### 4. Voice Dictation Integration?

**`VoiceService` wraps `SpeechToText`, provider holds `DictationState`, InputBar drives it.**

```
DictationState {
  isListening: bool,
  transcript: String,    // intermediate partial result
  isFinal: bool,         // true when recognition completed
}
```

Key constraint: `SpeechToText` must be initialized once per app lifecycle (not per listen session). Initialize in `VoiceService` constructor or on first use. The mic button uses `GestureDetector.onLongPressStart / onLongPressEnd` for push-to-talk UX matching the ALIA mental model the user already has.

`SpeechToText.listen()` provides intermediate results as the user speaks. Partial results update the transcript in real-time (displayed in the text field). When the user releases the mic, `speech.stop()` is called and the final transcript remains in the text field for review. `isFinal: true` in the callback confirms the final result.

### 5. Folder Structure for lib/

Feature-first organization (by screen/feature, not by layer) is recommended for this app size. The app has two major features: machine management and SSH session.

```
lib/
├── main.dart
├── app.dart                       # MaterialApp, Riverpod ProviderScope, routing
│
├── core/
│   ├── models/
│   │   ├── machine.dart           # Machine data class (id, name, host, port, user, password)
│   │   └── quick_command.dart     # QuickCommand data class
│   ├── services/
│   │   ├── machine_repository.dart  # CRUD + flutter_secure_storage persistence
│   │   └── voice_service.dart       # SpeechToText wrapper
│   └── theme/
│       └── terminal_theme.dart    # Dark theme, monospace font config
│
├── features/
│   ├── machines/
│   │   ├── providers/
│   │   │   └── machines_provider.dart   # machineRepositoryProvider (StateNotifier)
│   │   ├── screens/
│   │   │   └── machine_list_screen.dart
│   │   └── widgets/
│   │       ├── machine_card.dart
│   │       └── machine_form_sheet.dart  # Add/edit bottom sheet
│   │
│   └── session/
│       ├── providers/
│       │   ├── ssh_session_provider.dart   # AsyncNotifier, owns SSHClient+Terminal
│       │   └── voice_dictation_provider.dart
│       ├── screens/
│       │   └── session_screen.dart
│       └── widgets/
│           ├── terminal_view_wrapper.dart  # Wraps xterm TerminalView with resize logic
│           ├── input_bar.dart
│           ├── quick_command_panel.dart    # DraggableScrollableSheet
│           └── permission_card.dart        # Approval/rejection card overlay
```

**Why this structure:**
- `core/models` and `core/services` are shared — not feature-specific
- Features are self-contained: adding Phase 2 features (voice, quick commands) stays inside `session/`
- Provider files live next to the screens that consume them — easy to navigate

### 6. Build Order for Phase 1 MVP?

Dependencies must be respected. Build from the bottom up.

```
Step 1: Data model
  └── Machine model (Dart class, no UI)

Step 2: Persistence layer
  └── MachineRepository (flutter_secure_storage read/write/delete)

Step 3: Machine state provider
  └── machineRepositoryProvider (StateNotifier wrapping MachineRepository)

Step 4: Machine list UI (no SSH yet)
  └── MachineListScreen + MachineCard + MachineFormSheet
      Verifiable: add/list/delete machines work

Step 5: SSH connection
  └── SshService / sshSessionProvider (connect, PTY, stream wiring)
      Verifiable: can connect and see raw stdout

Step 6: Terminal display
  └── terminal_view_wrapper.dart (xterm TerminalView with auto-resize)
      Verifiable: colors render, scroll works

Step 7: Input bar (text only)
  └── InputBar widget → sshSessionProvider.sendInput()
      Verifiable: can type and send commands, see response

Step 8: Ctrl+C and basic quick commands
  └── QuickCommandPanel (just Ctrl+C, Ctrl+D, ESC initially)
      Verifiable: can interrupt Claude Code

Phase 1 DONE — ship and validate
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Custom ANSI Parser
**What:** Building your own ANSI escape sequence parser on top of raw SSH bytes
**Why bad:** ANSI has 100+ escape sequences; Claude Code uses many (colors, cursor, title). You will miss sequences and get broken rendering.
**Instead:** Use xterm.dart — it handles the full VT100/VT220/xterm-256color spec. Pass raw UTF-8 strings directly to `terminal.write()`.

### Anti-Pattern 2: Global SSHClient Singleton
**What:** `static final SSHClient _instance = ...` at app level
**Why bad:** Lifecycle issues — the client persists across navigation, no clean disposal, reconnect logic becomes global state
**Instead:** Riverpod `.autoDispose` `AsyncNotifier` scoped to the session screen. Riverpod calls `ref.onDispose` when the screen is popped.

### Anti-Pattern 3: Storing SSH Password in SharedPreferences or Hive
**What:** Using non-encrypted storage for credentials
**Why bad:** On unrooted Android, SharedPreferences is readable by other apps with physical device access; fails app store security reviews
**Instead:** `flutter_secure_storage` — uses Android Keystore / iOS Keychain. Single key per credential field, prefixed by machine ID.

### Anti-Pattern 4: Sending Voice Transcript Automatically on finalResult
**What:** Auto-submitting as soon as `SpeechRecognitionResult.finalResult == true`
**Why bad:** Breaks the SPEC requirement ("el texto queda editable antes de enviar"). Prompts to Claude Code need review — an accidental mis-transcription could send bad commands.
**Instead:** Always populate the `TextEditingController` and wait for explicit send button tap.

### Anti-Pattern 5: Building QuickCommandPanel Before SSH Works
**What:** Building UI features before the SSH connection layer is stable
**Why bad:** Quick commands write to SSH stdin — if the stdin write path is not verified end-to-end, you are building on an unknown foundation
**Instead:** Follow the build order above: SSH + Terminal + basic input, then quick commands.

---

## Scalability Considerations

| Concern | Phase 1 | Phase 3 | Notes |
|---------|---------|---------|-------|
| Multiple simultaneous sessions | Not supported (1 session) | Per-machine provider via `.family` already supports N sessions | The `sshSessionProvider(machineId)` pattern naturally enables this |
| Scrollback memory | 2000 lines (~fine for 1 session) | Reduce maxLines if memory pressure | xterm.dart removes oldest lines at limit |
| PTY column width on resize | `autoResize: true` on TerminalView handles it | Same | xterm.dart sends `resizeTerminal()` automatically |
| Reconnect | Not in MVP | `ref.invalidate(sshSessionProvider(id))` triggers reconnect | Riverpod makes this trivial |
| Custom quick commands | Hardcoded list in Phase 1 | Store custom commands in `flutter_secure_storage` or Hive | `quickCommandsProvider` StateNotifier already positioned for this |

---

## Sources

- dartssh2 API (Context7 / GitHub TerminalStudio/dartssh2) — HIGH confidence
  - `SSHClient.shell()` PTY pattern verified
  - `SSHSession.stdout` stream wiring verified
  - `keepAliveInterval`, `onVerifyHostKey` parameters verified
- xterm.dart pub.dev documentation — HIGH confidence
  - `Terminal.write()`, `Terminal.maxLines`, `Terminal.onOutput` verified
  - `TerminalView` `autoResize`, `ScrollController`, `TerminalController` parameters verified
- Riverpod documentation (Context7 / rrousselgit/riverpod) — HIGH confidence
  - `AsyncNotifier`, `.autoDispose`, `ref.onDispose`, `StreamNotifier` patterns verified
- speech_to_text package (Context7 / csdcorp/speech_to_text) — HIGH confidence
  - `initialize()`, `listen(onResult:)`, `stop()`, `SpeechRecognitionResult.finalResult` verified
- flutter_secure_storage (Context7 / juliansteenbakker) — HIGH confidence
  - `read()`, `write()`, `delete()` API verified
- Linxr Part 3 SSH Terminal article (dev.to/ai2th) — MEDIUM confidence
  - Confirmed SSH shell + PTY + reconnect pattern in real Flutter app
- Flutter isolates documentation (docs.flutter.dev) — MEDIUM confidence
  - Confirmed isolate overhead tradeoffs; informed decision NOT to use isolates for stream processing
