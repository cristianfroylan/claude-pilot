# Technology Stack — claude-pilot

**Project:** Flutter SSH remote control for Claude Code
**Researched:** 2026-06-19
**Overall confidence:** HIGH (all major packages verified via Context7 + official pub.dev)

---

## Core Packages

### SSH Transport — dartssh2

| Field | Value |
|-------|-------|
| Package | `dartssh2` |
| Current version | **2.18.0** (published ~5 days ago as of research date) |
| Publisher | terminal.studio (verified) |
| Confidence | HIGH — verified via Context7 + pub.dev |

**Why:** Pure Dart SSH client with no native code — works on iOS and Android without JNI/FFI. The
`SSHClient.shell()` API opens a PTY-backed interactive shell and returns an `SSHSession` whose
`.stdout` is a Dart `Stream<Uint8List>` and `.stdin` accepts `Uint8List` via `.write()`. PTY type
`xterm-256color` passes through ANSI codes exactly as Claude Code emits them. Written by the same
team (TerminalStudio) that wrote xterm.dart — the two packages are designed to work together, with
an official working example in the xterm.dart repo (`example/lib/ssh.dart`).

**Shell session wiring (verified API):**
```dart
final shell = await client.shell(
  pty: const SSHPtyConfig(type: 'xterm-256color', width: 220, height: 50),
  environment: {'LANG': 'en_US.UTF-8'},
);
// stdout → xterm.dart
shell.stdout.cast<List<int>>().transform(Utf8Decoder()).listen(terminal.write);
// xterm.dart input → stdin
terminal.onOutput = (data) => shell.write(utf8.encode(data));
```

**Do NOT use instead:**
- `ssh2` (older, less maintained, no active pub.dev presence)
- `ssh` (pub.dev package — abandoned, last release 2019)
- WebSocket bridge on the desktop — adds an extra process and defeats the "minimal infra" goal
- `dart:io` raw sockets — would require implementing SSH handshake from scratch

---

### Terminal Renderer — xterm

| Field | Value |
|-------|-------|
| Package | `xterm` |
| Current version | **4.0.0** (published ~2 years ago; no newer release) |
| Publisher | terminal.studio (verified) |
| Flutter constraint | `>=3.0.0` |
| Confidence | HIGH — Context7 + official GitHub README + pub.dev |

**Why:** Full VT100/xterm-256color emulator as a Flutter widget. Handles every ANSI escape sequence
Claude Code emits: bold, italic, underline, 256-color palette, cursor positioning, clear-screen, and
scrollback buffer. The `TerminalView` widget renders the stateful `Terminal` object with a Canvas
painter — no `Text` widget tree rebuilds per character. It is purpose-built for Flutter mobile (touch
scroll, zoom). xterm and dartssh2 share the same author and the integration is one stream listener
and one callback (see wiring above).

**Do NOT use instead:**

- Custom ANSI parser + RichText: Claude Code output includes cursor movement, in-place rewrites
  (progress bars, spinners), and bracketed paste mode. A naive regex-based ANSI stripper or basic
  color parser will render these incorrectly or crash. Building a correct VT100 state machine is
  weeks of work that xterm already provides.
- `ansi_styles` / `flutter_ansi_parser` (pub.dev) — strip color for display only, no PTY model,
  no scrollback, no cursor state. Unsuitable for a real terminal session.
- `flutter_pty` alone — provides PTY plumbing but not a rendering widget.

**Note on version currency:** 4.0.0 is two years old but actively used by production SSH apps. No
known breaking pub issues. The package has 1.5k+ GitHub stars. Check pub.dev score before adding
— it scores 140/160 (high pub points). If a 4.x or 5.x release appears at project start, prefer it.

---

### State Management — flutter_riverpod

| Field | Value |
|-------|-------|
| Package | `flutter_riverpod` |
| Current version | **3.3.2** (published ~9 days ago as of research date) |
| Publisher | dash-overflow.net / Remi Rousselet (verified) |
| Confidence | HIGH — Context7 + pub.dev |

**Why:** The SSH session lifecycle maps directly onto Riverpod primitives:
- `StreamNotifierProvider.autoDispose` holds the SSH session and exposes `shell.stdout` as a stream.
  `autoDispose` ensures the SSH connection is cleanly closed when the Terminal screen is popped.
- `ref.onDispose()` closes the SSH socket — no manual lifecycle management needed.
- `StreamProvider` handles the loading/connected/error states (connecting, connected, disconnected)
  as `AsyncValue` — avoids writing a custom state enum.
- Compile-time safety: provider references are typed, no `context.read<X>()` casting errors at
  runtime.
- Machine list (name, IP, credentials key reference) lives in a `NotifierProvider` — simple CRUD,
  automatically reactive.

**Do NOT use instead:**

- `provider` package: `ChangeNotifier` + `StreamBuilder` works but requires manual `dispose()`
  calls on SSH sessions. High risk of connection leaks when navigating. Provider is officially
  deprecated in favor of Riverpod by its own author.
- `bloc` / `flutter_bloc`: Excellent for large teams needing enforced event→state flows, but for a
  single-developer app the boilerplate (event classes, state classes, `BlocBuilder`) adds friction
  without benefit. SSH streaming is a `Stream<Uint8List>` — Riverpod handles it with one line.
- `setState` + `StatefulWidget`: Fine for simple widgets, unacceptable for SSH session state that
  must outlive widget lifecycle changes (screen rotation, background/foreground).

---

### Credential Storage — flutter_secure_storage

| Field | Value |
|-------|-------|
| Package | `flutter_secure_storage` |
| Current version | **10.3.1** stable (11.0.0-beta.1 also available — do not use in v1) |
| Publisher | juliansteenbakker (verified) |
| Confidence | HIGH — Context7 + pub.dev changelog |

**Why:** OS-native encrypted storage. On iOS uses Keychain. On Android v10+ uses RSA OAEP + AES-GCM
via Android KeyStore (not deprecated EncryptedSharedPreferences). SSH passwords must never appear in
`SharedPreferences`, which is plaintext on rooted devices.

**Android setup requirements (mandatory):**
1. `minSdkVersion 23` in `android/app/build.gradle` — enforced by v10, no workaround.
2. Disable Google Drive auto-backup to prevent `InvalidKeyException: Failed to unwrap key` on
   restore. Add to `AndroidManifest.xml`:
   ```xml
   <application android:allowBackup="false" ...>
   ```
   Or add a backup rules file that excludes `FlutterSecureStorage` shared preferences.
3. `USE_BIOMETRIC` permission is optional — not needed for this app (no biometric auth in v1).

**iOS setup requirements:**
- Minimum iOS deployment target: **13.0** (darwin subpackage v0.4.0 raised it from 12 to 13 for
  CryptoKit / Secure Enclave support).

**Storage schema for this app:**
- Key SSH password by machine UUID: `ssh_password_<uuid>`.
- Machine metadata (name, IP, port, username) goes in `shared_preferences` — not sensitive, no
  encryption needed, simpler API.

**Do NOT use instead:**
- `shared_preferences` for passwords: plaintext on device, readable without root on some Android
  versions via ADB backup.
- `hive` with encryption: heavier dependency, same outcome as flutter_secure_storage but more setup.
- Hardcoding credentials: obvious.

---

### Voice Dictation — speech_to_text

| Field | Value |
|-------|-------|
| Package | `speech_to_text` |
| Current version | **7.4.0** (published ~30 days ago as of research date) |
| Publisher | csdcorp.com (verified) |
| Confidence | HIGH — Context7 + pub.dev |

**Why:** On-device speech recognition via the OS native recognizer (Android SpeechRecognizer API,
iOS SFSpeechRecognizer). No cloud round-trip, no API key, works on LAN-only devices. The recognized
text lands in a text field for review before sending — which matches the spec requirement that voice
"does not send automatically." This package is the de facto standard for Flutter STT.

**Android setup requirements (mandatory):**
1. `minSdkVersion 21` — lower than flutter_secure_storage's 23, so 23 becomes the effective floor.
2. `compileSdkVersion 31` minimum (required since speech_to_text 5.2.0).
3. Permissions in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
   Note: The `INTERNET` permission is required even for on-device recognition because Android's
   SpeechRecognizer may route through Google services depending on device configuration.

**Critical Android gotchas:**
- **Short pause timeout:** Android SpeechRecognizer auto-stops when the speaker pauses for ~3-5
  seconds (varies by OEM and Android version). This cannot be overridden via the package API. For
  short prompts this is acceptable. For long dictation, users must speak continuously.
- **Device beep:** Android plays an audible beep on start and stop of recognition. This is an OS
  behavior — the package cannot suppress it.
- **SpeechRecognizer unavailability:** On some Android devices (mainly stripped AOSP ROMs), the
  Google app must be installed and speech settings enabled. The package returns
  `SpeechToTextStatus.notAvailable` via `initialize()`. Handle this gracefully — show "Voice not
  available on this device" and hide the mic button rather than crashing.
- **Emulator:** Google app must have microphone permission granted separately in the emulator
  settings. Test on a physical device first.

**iOS notes:** Works out of the box with standard permissions. Add to `Info.plist`:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Voice input for Claude prompts</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access for voice dictation</string>
```

**Do NOT use instead:**
- Whisper via `flutter_whisper` or similar: heavier model download, higher latency, overkill for
  short CLI prompts. On-device OS STT is faster for this use case.
- Google Cloud Speech-to-Text API: requires internet, API key, billing, and breaks the LAN-only
  constraint.
- `record` + custom cloud STT: two packages where one suffices.

---

### Machine Metadata Storage — shared_preferences

| Field | Value |
|-------|-------|
| Package | `shared_preferences` |
| Current version | **2.5.5** (published ~2 months ago as of research date) |
| Publisher | flutter.dev (official Flutter team, verified) |
| Confidence | HIGH — pub.dev official |

**Why:** Machine list metadata (name, display label, IP, port, username, UUID) is non-sensitive. It
needs simple persistence across app restarts. `SharedPreferences` is the minimal-overhead solution
from the Flutter team — no setup, no schema, works offline. Serialize the machine list as JSON under
a single key (e.g. `machines_v1`).

**Do NOT use instead:**
- `flutter_secure_storage` for metadata: adds encryption overhead where none is needed. Reserve
  encrypted storage for the actual SSH password only.
- SQLite / `sqflite`: the data model is a flat list of <10 machines. A relational DB is
  overengineered. Add it only if the data model grows to need relations or queries.
- `hive`: valid alternative but an extra dependency. `shared_preferences` covers this use case with
  zero configuration.

---

## Effective Android SDK Floor

The binding constraint is `flutter_secure_storage` at **minSdkVersion 23**. All other packages
require 21 or less. Set `minSdkVersion 23` in `android/app/build.gradle` and `compileSdkVersion 34`
(or 35 to match flutter_secure_storage's updated target).

## iOS Deployment Target

Set **iOS 13.0** as the minimum deployment target in `ios/Podfile` and Xcode project settings.
This satisfies `flutter_secure_storage`'s darwin subpackage requirement (CryptoKit).

---

## Complete pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # SSH transport
  dartssh2: ^2.18.0

  # Terminal rendering (ANSI-faithful)
  xterm: ^4.0.0

  # State management
  flutter_riverpod: ^3.3.2

  # Credential storage (encrypted)
  flutter_secure_storage: ^10.3.1

  # Voice dictation (on-device)
  speech_to_text: ^7.4.0

  # Machine metadata (non-sensitive)
  shared_preferences: ^2.5.5
```

---

## Alternatives Considered

| Category | Chosen | Rejected | Reason Rejected |
|----------|--------|----------|-----------------|
| SSH | dartssh2 | ssh (pub.dev) | Abandoned since 2019 |
| SSH | dartssh2 | WebSocket bridge | Extra desktop process, more infra |
| Terminal | xterm | Custom ANSI parser | VT100 state machine is weeks of work; Claude Code uses cursor movement, not just colors |
| Terminal | xterm | ansi_styles | Color-strip only, no PTY model or scrollback |
| State | flutter_riverpod | provider | `provider` deprecated by same author; no autoDispose |
| State | flutter_riverpod | bloc | Excessive boilerplate for a single-dev streaming app |
| State | flutter_riverpod | setState | SSH session must outlive widget lifecycle |
| Credentials | flutter_secure_storage | shared_preferences (for passwords) | SharedPreferences is plaintext |
| Credentials | flutter_secure_storage | hive+encryption | More setup, same result |
| Voice | speech_to_text | Whisper | Larger model, higher latency, overkill for short prompts |
| Voice | speech_to_text | Google Cloud STT | Requires internet, breaks LAN-only constraint |
| Metadata | shared_preferences | sqflite | Flat list of <10 items needs no relational DB |

---

## Sources

- dartssh2: [pub.dev](https://pub.dev/packages/dartssh2) · [GitHub](https://github.com/TerminalStudio/dartssh2) · Context7 `/terminalstudio/dartssh2`
- xterm.dart: [pub.dev](https://pub.dev/packages/xterm) · [SSH example](https://github.com/TerminalStudio/xterm.dart/blob/master/example/lib/ssh.dart) · Context7 `/terminalstudio/xterm.dart`
- flutter_riverpod: [pub.dev](https://pub.dev/packages/flutter_riverpod) · Context7 `/rrousselgit/riverpod`
- flutter_secure_storage: [pub.dev](https://pub.dev/packages/flutter_secure_storage) · [GitHub](https://github.com/juliansteenbakker/flutter_secure_storage) · Context7 `/juliansteenbakker/flutter_secure_storage`
- speech_to_text: [pub.dev](https://pub.dev/packages/speech_to_text) · [GitHub](https://github.com/csdcorp/speech_to_text) · Context7 `/csdcorp/speech_to_text`
- shared_preferences: [pub.dev](https://pub.dev/packages/shared_preferences)
