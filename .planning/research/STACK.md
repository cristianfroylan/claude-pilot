# Technology Stack — claude-pilot

**Project:** Flutter SSH remote control for Claude Code
**Researched:** 2026-06-19 (v1.0) · Updated 2026-06-20 (v2.0 additions)
**Overall confidence:** HIGH (all major packages verified via Context7 + official pub.dev)

---

## v1.0 Core Packages (Validated — Do Not Re-research)

### SSH Transport — dartssh2

| Field | Value |
|-------|-------|
| Package | `dartssh2` |
| Current version | **2.18.0** |
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
| Current version | **3.3.2** (as of v1.0 research) |
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

**v2.0 multi-session extension:** Each session tab gets its own provider family instance:
`sessionProvider(tabId)`. The tab list itself is a `NotifierProvider<List<TabSession>>`. No new
package needed — this is standard Riverpod `.family` usage already in the codebase.

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
| Current version | **10.3.1** stable |
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
| Current version | **7.4.0** |
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
| Current version | **2.5.5** |
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

## v2.0 New Package Additions

### Biometric Authentication — local_auth

| Field | Value |
|-------|-------|
| Package | `local_auth` |
| Version to use | **3.0.1** |
| Publisher | flutter.dev (official Flutter team, verified) |
| Pub.dev | https://pub.dev/packages/local_auth |
| Confidence | HIGH — verified via pub.dev + platform package changelogs |

**Why over alternatives:**
- `local_auth` is the official Flutter team package. It delegates to `local_auth_android` and
  `local_auth_darwin`, both maintained by the same verified publisher.
- `biometric_storage` (codeux.design, v5.0.1) is designed for *encrypted key storage protected by
  biometric*, not authentication gating. It conflates two concerns. For this app, biometric is a
  door lock at app launch and before editing credentials — `local_auth` is the right tool for that
  job.
- No third-party biometric package should be preferred when the official Flutter team package covers
  the need. Third-party packages in this space are often abandoned.

**What it does:** Calls the device's OS-level authentication dialog (Face ID on iPhone, fingerprint
on Android, PIN as fallback). Returns `bool` — authenticated or not. No credentials stored in this
package. The existing `flutter_secure_storage` still holds SSH passwords.

**API (3.0.x — verified):**
```dart
final auth = LocalAuthentication();
final bool canAuth = await auth.canCheckBiometrics;
final bool didAuth = await auth.authenticate(
  localizedReason: 'Authenticate to access claude-pilot',
  options: const AuthenticationOptions(
    biometricOnly: false,  // false = allow PIN/pattern fallback
    persistAcrossBackgrounding: false,
  ),
);
```

**Breaking change in 3.0.0 vs 2.x:** `AuthenticationOptions` parameter shape changed.
`stickyAuth` renamed to `persistAcrossBackgrounding`. `useErrorDialogs` removed — the app must
handle `LocalAuthException` with structured `LocalAuthExceptionCode` values instead of
`PlatformException`. If reading v2.x tutorials, their error handling code is wrong for 3.x.

**Android setup (mandatory):**
1. `minSdkVersion`: local_auth requires **API 24** (Android 7.0). Current `build.gradle.kts`
   uses `flutter.minSdkVersion` which maps to Flutter's default floor — verify this resolves to
   ≥ 24. If not, set `minSdk = 24` explicitly. This raises the effective SDK floor from 23
   (flutter_secure_storage) to **24** (local_auth).
2. Permission in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
   ```
3. `MainActivity.kt` must extend `FlutterFragmentActivity` (not `FlutterActivity`):
   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity
   class MainActivity : FlutterFragmentActivity()
   ```
   This is a one-line change but it is mandatory — `local_auth` uses `BiometricPrompt` which
   requires a `FragmentActivity` context. Without this change the dialog silently fails to appear.
4. The `LaunchTheme` in `styles.xml` must inherit from `Theme.AppCompat` (not `Theme.Material3`
   directly). The existing `FlutterDefault` themes usually satisfy this, but verify — crashes on
   Android 8 and below otherwise.

**iOS setup (mandatory):**
1. Add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSFaceIDUsageDescription</key>
   <string>Use Face ID to unlock claude-pilot</string>
   ```
   Without this entry, the app crashes on iPhones with Face ID when `authenticate()` is called.
2. No additional deployment target change needed — iOS 13.0 (already required by
   `flutter_secure_storage`) satisfies local_auth 3.0.x.

**Do NOT use instead:**
- `biometric_storage`: conflates storage + biometric into one concept. This app already uses
  `flutter_secure_storage` for encrypted storage — adding a second encrypted storage layer
  creates key-management confusion.
- `flutter_local_auth_invisible` (GitHub only, unverified): experimental, no pub.dev presence.
- Any package that hasn't been updated to use `BiometricPrompt` on Android — older packages
  still using the deprecated `FingerprintManager` API fail on Android 11+.

**Effective new Android floor: minSdk 24**

---

### Multi-Session Tab Management — No New Package Required

**Decision: Use Flutter's native `TabBar` + `TabController` + `IndexedStack`, NOT a package.**

**Confidence:** HIGH — verified through Flutter documentation and community patterns.

**Rationale:**

The v2.0 tab behavior is a dynamic list of SSH sessions (add on connect, close via X button),
styled like Chrome mobile tabs. The two package candidates evaluated were rejected:

- **`go_router` `StatefulShellRoute`:** Branches are defined statically at compile time. There is
  no supported API to add or remove branches at runtime. SSH sessions are created and destroyed
  by user action at runtime — a static branch list is architecturally incompatible. Using
  `StatefulShellRoute` for this would require rebuilding the entire router on every session open/
  close, which defeats the purpose.
- **`dynamic_tabbar` (pub.dev v1.0.9):** Published 18 months ago, unverified publisher, 120 likes.
  Low maintenance signal. The package wraps `TabController` internally but adds constraints and
  a layer of indirection that is not worth the risk for core session management.

**Pattern to use:**
```
SessionListNotifier (Riverpod NotifierProvider)
  └── List<SessionEntry> (each has: id, machineId, TabEntry data)

UI:
  TabBar (scrollable)  ← driven by sessionList.length
  IndexedStack         ← one TerminalScreen per session, keyed by id
  TabController        ← recreated with vsync when length changes
```

`TabController` does require recreation when tab count changes. The correct Flutter pattern is to
dispose and recreate the controller in a `StatefulWidget` that `didUpdateWidget` when the list
length changes, or use a `TickerProviderStateMixin` widget that watches the Riverpod session list.
This is well-established Flutter practice (the Flutter team's own examples use this pattern).

The tab bar lives *outside* go_router's navigation — it is the main scaffold content after the
user has authenticated and selected a machine. go_router handles navigation *to* the session
scaffold; `TabController` handles navigation *within* it between open sessions.

**Working directories per session:** Each `SessionEntry` carries an optional `startingPath`
(nullable `String`). This is set from the session start picker (folder config) at connection time
and passed as the first command (`cd <path>\n`) to the SSH shell after the PTY is established.
No new package needed — it is a field on an existing data class.

**Do NOT use:**
- `go_router` `StatefulShellRoute` for SSH session tabs — static branch count incompatible with
  dynamic session creation.
- `dynamic_tabbar` — low maintenance, unverified, not worth the dependency for wrapping what
  Flutter provides natively.
- `persistent_bottom_nav_bar_v2` — oriented toward fixed navigation, not dynamic session tabs.

---

### Reconnection Backoff — `retry` package OR pure Dart (recommendation below)

| Field | Value |
|-------|-------|
| Package | `retry` |
| Version | **3.1.2** (published 3 years ago — stable) |
| Publisher | google.dev (verified) |
| Pub.dev | https://pub.dev/packages/retry |
| Confidence | HIGH — verified via pub.dev |

**Decision: Use pure Dart `Timer` + `dart:async` — do NOT add the `retry` package.**

**Rationale:**

The `retry` package (google.dev, 1.92M downloads) is excellent for HTTP request retries but has
a key limitation for SSH reconnection: it provides no mechanism to expose intermediate state
(attempt number, next retry delay) to the UI. It runs the retry loop internally and returns only
the final result or throws after all attempts. The v2.0 spec requires:
- A progress UI showing "Reconnecting... attempt 2/5, next retry in 8s"
- A cancel button that aborts the retry loop mid-flight
- A manual retry button after exhausting attempts

These three requirements need external control of the retry state. Implementing them on top of
`retry`'s black-box API requires wrapping it in another abstraction that ends up duplicating the
backoff logic anyway.

**Pattern to implement:**
```dart
// In SshSessionNotifier (Riverpod AsyncNotifier)
Future<void> _reconnectWithBackoff() async {
  const delays = [2, 4, 8, 16, 30]; // seconds, clamped
  for (int attempt = 0; attempt < delays.length; attempt++) {
    if (_cancelRequested) break;
    state = AsyncValue.data(SessionState.reconnecting(
      attempt: attempt + 1,
      maxAttempts: delays.length,
      nextRetryIn: delays[attempt],
    ));
    await Future.delayed(Duration(seconds: delays[attempt]));
    if (_cancelRequested) break;
    try {
      await _connect();
      return; // success
    } catch (_) {
      // continue loop
    }
  }
  state = AsyncValue.data(SessionState.failed());
}
```

The `_cancelRequested` flag is set by the cancel button. The `SessionState` sealed class carries
enough information for the progress UI widget to render "Attempt 2/5 · retry in 8s". No package
needed — this is 20 lines of Dart.

**When to use `retry` instead:** If a future phase adds HTTP/REST calls (e.g., a status endpoint),
use `retry` for those. It is well-suited to fire-and-forget network requests where intermediate
state doesn't need surfacing.

**Do NOT use:**
- `exponential_back_off` (GitHub only, Nidal-Bakir) — no pub.dev presence, unverified.
- `dio` retry interceptor — not applicable to SSH connections.
- Any WebSocket reconnection library — this is SSH, not WebSocket.

---

### Folder Picker for Working Directories — No New Package Required

**Decision: Roll a custom bottom sheet powered by `dartssh2` `ls` commands.**

**Confidence:** MEDIUM-HIGH — based on dartssh2 API capability and Flutter UI primitives.

**Rationale:**

The "session start picker" shows a list of configured working directories per machine. There are
two sub-cases:

1. **Configured folders list:** The user pre-configures a list of favorite directories per
   machine (e.g., `~/projects/claude-pilot`, `~/work`). These are stored as
   `List<String>` in `shared_preferences` under key `working_dirs_<machineUUID>`. A settings
   screen lets the user add/remove entries with a text field. This is pure Flutter UI — no package.

2. **Live `ls` browsing at connect time:** Optionally, the picker runs `ls -la <path>` over SSH
   and shows the result as a selectable list. This uses the same `dartssh2` `SSHClient.execute()`
   for a one-shot command, parses stdout, and presents it in a `ListView`. No package needed —
   `execute()` returns a `Future<SSHSession>` whose stdout can be read as a string.

**File picker packages are NOT appropriate here:**
- `file_picker`, `flutter_file_picker` — opens the device's local file system. The folders we
  need are on the *remote SSH host*, not the phone. These packages have no SSH awareness.
- `path_provider` — returns device-local paths (Documents, temp, etc.). Same mismatch.

**The correct approach is:** SSH `execute('ls -la ~/projects')` → parse output → show as
`ListView` → on select, store the path → at next connection, send `cd <path>\n` as the first
shell command. All components already exist in the app (dartssh2, shared_preferences, Flutter
ListView). No new package needed.

---

## Effective Platform Requirements After v2.0

### Android

| Constraint | Floor | Reason |
|------------|-------|--------|
| `minSdk` | **24** | `local_auth` 3.0.x requires API 24 (raised from 23) |
| `compileSdk` | **36** | Already set in `build.gradle.kts` — no change needed |
| `targetSdk` | **34** | Already set — no change needed |

**Action required in `build.gradle.kts`:** Change `minSdk = flutter.minSdkVersion` to
`minSdk = 24` (or verify `flutter.minSdkVersion` resolves to ≥ 24, which it currently does not
by default — Flutter's default minSdk is 21).

**Additional Android manifest entries required:**
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

**Additional MainActivity.kt change required:**
```kotlin
// Before:
class MainActivity : FlutterActivity()
// After:
class MainActivity : FlutterFragmentActivity()
```

### iOS

| Constraint | Value | Reason |
|------------|-------|--------|
| Deployment target | **13.0** | Already required by `flutter_secure_storage` — no change |

**Additional Info.plist key required:**
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock claude-pilot</string>
```

---

## v2.0 pubspec.yaml Delta

**Add one package:**
```yaml
dependencies:
  # ... existing packages unchanged ...

  # Biometric authentication (app lock + credential guard)
  local_auth: ^3.0.1
```

**No other packages needed for v2.0 features.** Multi-session tabs, reconnection backoff, and
folder picker are built with existing stack primitives (Flutter TabController, Dart async, dartssh2,
shared_preferences).

---

## Complete v2.0 pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # SSH transport
  dartssh2: ^2.18.0

  # Terminal rendering (ANSI-faithful)
  xterm: ^4.0.0

  # State management
  flutter_riverpod: ^3.3.1
  riverpod_annotation: 4.0.2

  # Navigation
  go_router: ^17.3.0

  # Credential storage (encrypted)
  flutter_secure_storage: ^10.3.1

  # Voice dictation (on-device)
  speech_to_text: ^7.4.0

  # Machine metadata (non-sensitive)
  shared_preferences: ^2.5.5

  # Biometric authentication (NEW in v2.0)
  local_auth: ^3.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: 4.0.3
  build_runner:
```

---

## Alternatives Considered (v2.0)

| Category | Chosen | Rejected | Reason Rejected |
|----------|--------|----------|-----------------|
| Biometric | local_auth 3.0.1 | biometric_storage | Conflates auth + storage; we already have flutter_secure_storage for storage |
| Biometric | local_auth 3.0.1 | flutter_local_auth_invisible | No pub.dev presence, experimental |
| Tab management | Native TabController + IndexedStack | go_router StatefulShellRoute | Branches are static at compile time; SSH sessions are dynamic |
| Tab management | Native TabController + IndexedStack | dynamic_tabbar | 18 months stale, unverified publisher, thin abstraction over what Flutter already provides |
| Reconnect backoff | Pure Dart Timer loop | retry (google.dev) | retry hides internal state; UI needs attempt count, delay countdown, and cancel signal — all require external state control |
| Reconnect backoff | Pure Dart Timer loop | exponential_back_off | No pub.dev presence, unverified |
| Folder picker | SSH ls + shared_preferences | file_picker | file_picker accesses device local FS; folders are on remote SSH host |
| Folder picker | SSH ls + shared_preferences | path_provider | Same mismatch — returns device paths, not remote paths |

---

## Sources

**v1.0 sources:**
- dartssh2: [pub.dev](https://pub.dev/packages/dartssh2) · [GitHub](https://github.com/TerminalStudio/dartssh2) · Context7 `/terminalstudio/dartssh2`
- xterm.dart: [pub.dev](https://pub.dev/packages/xterm) · [SSH example](https://github.com/TerminalStudio/xterm.dart/blob/master/example/lib/ssh.dart) · Context7 `/terminalstudio/xterm.dart`
- flutter_riverpod: [pub.dev](https://pub.dev/packages/flutter_riverpod) · Context7 `/rrousselgit/riverpod`
- flutter_secure_storage: [pub.dev](https://pub.dev/packages/flutter_secure_storage) · Context7 `/juliansteenbakker/flutter_secure_storage`
- speech_to_text: [pub.dev](https://pub.dev/packages/speech_to_text) · Context7 `/csdcorp/speech_to_text`
- shared_preferences: [pub.dev](https://pub.dev/packages/shared_preferences)

**v2.0 sources:**
- local_auth: [pub.dev](https://pub.dev/packages/local_auth) · [local_auth_android](https://pub.dev/packages/local_auth_android) · [local_auth_darwin](https://pub.dev/packages/local_auth_darwin)
- go_router StatefulShellRoute: [pub.dev](https://pub.dev/packages/go_router) · [codewithandrea.com article](https://codewithandrea.com/articles/flutter-bottom-navigation-bar-nested-routes-gorouter/)
- dynamic_tabbar: [pub.dev](https://pub.dev/packages/dynamic_tabbar) (rejected)
- retry: [pub.dev](https://pub.dev/packages/retry) (rejected for this use case)
