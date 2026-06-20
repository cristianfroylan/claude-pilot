# Domain Pitfalls

**Domain:** Flutter mobile SSH terminal (dartssh2 + ANSI rendering + voice dictation)
**Researched:** 2026-06-19
**Project:** claude-pilot

---

## Critical Pitfalls

Mistakes that cause rewrites or major debugging sessions.

---

### Pitfall 1: Unhandled SSHStateError When Transport Closes Abruptly

**What goes wrong:**
When the desktop reboots, the Wi-Fi drops, or the SSH daemon is killed, dartssh2 raises `SSHStateError(Transport is closed)` as an unhandled exception. This happens because the transport shuts down first, then Flutter code still awaiting `session.done` or calling `client.close()` tries to send an EOF packet over the already-dead transport. Without a try-catch wrapper the app crashes with an unhandled exception rather than showing a clean "Disconnected" state.

**Root cause:** The xterm.dart reference example wires streams with no error handling at all. Developers copy that pattern and miss that `session.done` can throw rather than just complete.

**Warning signs:**
- App crashes when desktop sleeps or loses power
- "Unhandled Exception: SSHStateError" in logcat/console
- Users report the app "freezes" rather than showing a reconnect prompt

**Prevention:**
Wrap all SSH lifecycle calls in try-catch. Treat `client.done` as a supervision future — attach `.catchError()` to it at connection time to funnel all transport errors to a single disconnect handler. Never await `session.done` or `client.close()` without a surrounding try-catch. Example guard:
```dart
client.done.catchError((e) => _handleDisconnect(e));
```

**Phase to address:** Phase 1 (MVP) — connection establishment. Do not ship Phase 1 without this guard.

---

### Pitfall 2: PTY Dimensions Not Dynamically Updated — Claude Code Layout Breaks

**What goes wrong:**
dartssh2's `client.shell()` takes a fixed `SSHPtyConfig(width, height)` at session creation time. If the app later rotates, the keyboard appears (shrinking the visible area), or the quick-commands panel expands, the PTY columns and rows stay at the original values. Claude Code's Ink renderer uses the reported terminal width to line-wrap its output and position its UI (diff blocks, spinners, permission cards). When PTY columns mismatch the visible widget width, line wrapping breaks — a 220-column PTY on a 40-column screen produces horizontally scrolling garbage.

**Root cause:** Terminal apps on desktop call `ioctl TIOCSWINSZ` when the window resizes. In Flutter, the layout changes are widget events, and there is no automatic bridge to `session.resizeTerminal()`. The xterm.dart reference implementation shows the correct pattern (`terminal.onResize = (w, h, pw, ph) { session.resizeTerminal(w, h, pw, ph); }`) but it is not wired automatically.

**Warning signs:**
- Diff output truncated or wrapped at wrong column
- Spinner/progress line partially overwriting previous output
- Claude Code permission card text wrapping mid-word

**Prevention:**
1. Compute PTY columns from actual widget width divided by monospace character width at session start.
2. Hook into the widget's `LayoutBuilder` or listen to `MediaQuery` to detect size changes (keyboard appear/disappear, rotation).
3. Call `session.resizeTerminal(cols, rows, 0, 0)` whenever dimensions change.
4. Use a minimum of 80 columns as a floor; never hard-code a value.

**Phase to address:** Phase 1 (terminal view). Must be correct from the start — fixing it later requires re-testing all Claude Code output formatting.

---

### Pitfall 3: ANSI Cursor-Up + Erase-in-Line Sequences Break Naively Appended Text

**What goes wrong:**
Claude Code uses the Ink renderer which emits in-place update sequences — notably `\x1b[A` (cursor up), `\x1b[K` (erase to end of line), and `\x1b[2K` (erase whole line) — to animate spinners and update progress indicators without scrolling. A naively implemented terminal that only appends new text to a list of lines will show every intermediate spinner frame as a separate new line instead of updating in place. The output becomes a waterfall of duplicated spinner frames instead of a clean animated indicator.

**Root cause:** Claude Code's Ink renderer explicitly uses EL (erase-in-line) sequences instead of space-padding to improve performance over SSH. Any terminal widget that does not implement a 2D cell buffer and cursor tracking will break here.

**Warning signs:**
- Spinner shows as dozens of lines: `⠋ Thinking...`, `⠙ Thinking...`, `⠹ Thinking...` stacked vertically
- Diff output shows ANSI SGR codes as literal text (`\x1b[32m+ import...`)
- Progress bars overprint onto adjacent lines

**Prevention:**
Use `xterm.dart` as the terminal rendering layer rather than a custom `RichText`/`SelectableText` approach. xterm.dart implements a proper VT100/xterm-256color cell buffer with cursor tracking, EL, ED, and SGR handling. It renders at 60fps and was specifically designed for SSH terminal use in Flutter. Do not attempt to build a custom ANSI parser for this project.

**Phase to address:** Phase 1 (terminal view). Choosing xterm.dart vs custom widget is the foundational decision — pick xterm.dart from day one.

---

### Pitfall 4: App Backgrounding Kills the SSH Connection on iOS

**What goes wrong:**
On iOS, when the user switches to another app or locks the screen, the OS suspends the Flutter process. TCP sockets get no CPU time and the SSH transport silently times out on the server side (or the kernel drops the connection). When the user returns to claude-pilot, the session appears active but all writes go into a void and no data comes back. The app shows no error because the stream simply stops delivering events — it neither closes nor errors while suspended.

**Root cause:** Apple's iOS process model aggressively suspends background apps. Unlike Android where `onDone` fires when a socket closes, iOS may not call any stream callback until the app resumes. By that point the server has already cleaned up the SSH session.

**Warning signs:**
- No error shown after returning from background, but the terminal is silently dead
- Ctrl+C, commands sent after resume produce no visible response
- The SSH session on the server is gone (`who` / `ss` show no client connection)

**Prevention:**
1. **App lifecycle listener:** Use `WidgetsBindingObserver` and listen for `AppLifecycleState.paused` / `AppLifecycleState.resumed`.
2. **On pause:** Record the timestamp and optionally send a no-op to test liveness.
3. **On resume:** Send a keepalive probe (write a NUL byte or use `client.ping()` if available). If it fails or times out within 2 seconds, tear down cleanly and show a "Connection lost — reconnect?" prompt.
4. **Proactive keepalive:** Set `keepAliveInterval: const Duration(seconds: 30)` on `SSHClient` — this is a built-in dartssh2 parameter that sends SSH keepalive packets over the encrypted channel, keeping NAT entries alive and giving early warning of dead connections.
5. Do not attempt iOS VoIP background mode — it requires App Store justification and is not appropriate for this use case.

**Phase to address:** Phase 1 (connection layer) for keepalive setup; Phase 3 (polish) for smooth reconnect UX.

---

### Pitfall 5: flutter_secure_storage Auto-Backup Destroys Encryption Keys

**What goes wrong:**
Android by default backs up app data (including SharedPreferences) to Google Drive via Auto Backup. flutter_secure_storage encrypts data with a keystore-backed key that is device-specific and never backed up. However, the encrypted blob IS backed up. When the user restores the app on a new device or after a factory reset, the encrypted SSH credentials exist but the decryption key does not. Every read throws `java.security.InvalidKeyException: Failed to unwrap key`, which surfaces in Flutter as a `PlatformException`. All stored machine credentials are permanently lost.

**Root cause:** Google's Auto Backup captures `shared_prefs/` by default but does not capture the Android Keystore. The encryption key and the ciphertext live in different storage locations with different backup policies.

**Warning signs:**
- `PlatformException` on first credential read after app reinstall or restore
- All saved machines disappear after restoring from a backup
- No error during write — only appears on read after the key is gone

**Prevention:**
Add a backup exclusion rule in `AndroidManifest.xml` before shipping Phase 1. Either disable Auto Backup entirely or exclude the FlutterSecureStorage shared preferences:

```xml
<!-- Option A: disable backup entirely -->
<application android:allowBackup="false" ...>

<!-- Option B: exclude only the secure storage prefs -->
<application
  android:fullBackupContent="@xml/backup_rules"
  android:dataExtractionRules="@xml/data_extraction_rules" ...>
```

With a `backup_rules.xml` that excludes `sharedPreferences` named `FlutterSecureStorage`.

Also set `migrateWithBackup: true` in `AndroidOptions` as a crash-resistant migration guard for algorithm upgrades.

**Phase to address:** Phase 1 (machine manager / credential storage). This is a manifest configuration — ship it correctly from the start.

---

### Pitfall 6: flutter_secure_storage minSdkVersion Conflict

**What goes wrong:**
flutter_secure_storage v10+ documents minSdkVersion 23 (Android 6.0) but the package's Gradle configuration has at times enforced 24. If the app's `build.gradle` sets `minSdkVersion 21` or `22`, the build fails or the package silently raises compatibility issues at runtime. The biometric authentication path requires API 28+.

**Root cause:** A mismatch between documented and enforced minimum SDK in the package (issue #1037 in the package repo). The package is actively maintained and this may be resolved, but the app must explicitly set a compatible floor.

**Warning signs:**
- Gradle build error: `uses-sdk:minSdkVersion X cannot be smaller than version Y`
- `PlatformException` on older Android 6 devices

**Prevention:**
Explicitly set `minSdkVersion 23` (or 24 to be safe) in `android/app/build.gradle`. Do not rely on the Flutter default. Do not use biometric features in v1 — credentials are password-protected only. Check the package changelog when upgrading.

**Phase to address:** Phase 1 project setup — set the correct minSdkVersion before writing any code.

---

## Moderate Pitfalls

---

### Pitfall 7: High-Frequency SSH Stream Updates Cause Frame Drops

**What goes wrong:**
Claude Code's Ink renderer emits output at high frequency during active tasks — diff lines, spinner frames, tool output. If each SSH data chunk triggers a `setState()` on the terminal widget's parent, Flutter rebuilds the entire subtree on every chunk. On a mid-range Android phone this produces dropped frames and visible jank, particularly when Claude is doing file operations that emit rapid output.

**Warning signs:**
- Terminal output feels choppy when Claude is actively running
- Flutter Performance overlay shows red frames during heavy output
- `setState` called dozens of times per second visible in DevTools

**Prevention:**
Use `xterm.dart` directly — it uses an internal buffer and renders via a custom `RenderObject`, not a widget subtree rebuild. It updates at 60fps without triggering the Flutter widget reconciler on every byte. If building a custom solution, batch SSH stream chunks with a 16ms timer before applying to state. Use `StreamBuilder` scoped tightly to the terminal widget only, never wrap the full screen in it.

**Phase to address:** Phase 1 (terminal view). Inherently solved by choosing xterm.dart correctly.

---

### Pitfall 8: Soft Keyboard Covers Input Bar and Conflicts with Terminal Scroll

**What goes wrong:**
When the user taps the text field to type a prompt, the soft keyboard slides up and the `Scaffold` resizes. If `resizeToAvoidBottomInset: true` (the default), the terminal viewport shrinks and the user's scroll position jumps. If set to `false`, the keyboard covers the input bar. Neither default behavior is correct for a terminal-style layout where the terminal should scroll independently of the keyboard.

**Warning signs:**
- Tapping the input field causes the terminal to scroll to bottom unexpectedly
- Input bar hidden behind keyboard
- Terminal content jumps when keyboard appears/disappears

**Prevention:**
Use `resizeToAvoidBottomInset: false` on the Scaffold. Manage bottom padding manually using `MediaQuery.of(context).viewInsets.bottom`. Keep the terminal viewport using a `Flexible`/`Expanded` widget and adjust only the input bar's bottom padding. Animate the padding change with `AnimatedPadding` or listen to `WidgetsBinding.instance.addObserver` to smooth the transition.

**Phase to address:** Phase 1 (terminal view layout).

---

### Pitfall 9: speech_to_text Stops After a Short Silence — Prompt Appears Incomplete

**What goes wrong:**
The `speech_to_text` plugin on Android wraps the system speech recognizer, which has a device-dependent silence timeout (typically 2-5 seconds). If the user pauses mid-sentence while dictating a long Claude prompt — common for technical prompts — recognition auto-stops and delivers a partial result. The user does not realize recognition stopped and continues speaking to silence. The dictated text is truncated.

**Root cause:** Android's built-in recognizer enforces its own silence timeout. The `speech_to_text` README explicitly states: "there is currently no supported method to adjust this behavior." The timeout varies by device and Android version.

**Warning signs:**
- Dictated prompts end abruptly mid-sentence
- The transcription field stops updating while the user is still speaking

**Prevention:**
1. Show a clear visual indicator of recognition state (listening / paused / stopped) — never leave the user wondering if the mic is still on.
2. Do not auto-send on recognition stop — always require the user to explicitly tap Send after reviewing the text. (This is already in the spec: "El texto queda editable antes de enviar.")
3. Implement a "tap to extend" pattern: if recognition stops, the user can tap the mic button again to append to the existing transcript.
4. Display the in-progress partial result as the user speaks so they see it is updating.

**Phase to address:** Phase 2 (voice dictation).

---

### Pitfall 10: speech_to_text Android SDK 30+ Intent Query Missing

**What goes wrong:**
On Android 11 (API 30) and later, package visibility restrictions require apps to declare which intents they query. `speech_to_text` needs to query `android.speech.RecognitionService`. Without the `<queries>` block in `AndroidManifest.xml`, `speech.initialize()` may return `false` silently on SDK 30+ devices even with `RECORD_AUDIO` permission granted.

**Warning signs:**
- `speech.initialize()` returns `false` on Android 11+ physical devices
- Works on emulator but not on real phone
- No crash, just silent failure to initialize

**Prevention:**
Add to `AndroidManifest.xml` before the `<application>` tag:
```xml
<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```
Also add `<uses-permission android:name="android.permission.RECORD_AUDIO" />`. Test on a physical Android 11+ device, not just an emulator (emulators may not exhibit this failure).

**Phase to address:** Phase 2 (voice dictation) — do this before writing any recognition code.

---

### Pitfall 11: SSH Input Latency from Naive Character-by-Character Sending

**What goes wrong:**
Each tap on a quick-command button (e.g., Ctrl+C) needs to send raw bytes through the SSH channel. If the app writes one character at a time with `session.write()` in a loop and awaits each write, latency compounds over a LAN connection. For multi-byte sequences like `\x03` (Ctrl+C) this is fine, but for full command strings like `/compact\n`, naive character iteration causes unnecessary round-trips.

**Warning signs:**
- Commands appear character-by-character in the terminal with visible delay
- Large paste operations are noticeably slow

**Prevention:**
Always send complete command strings as single `session.write(utf8.encode(command))` calls. Never iterate characters. For Ctrl sequences, send the control byte directly: `session.write(Uint8List.fromList([0x03]))` for Ctrl+C. Use `session.stdin.addStream()` only for large data; for interactive keystrokes, `session.write()` is appropriate.

**Phase to address:** Phase 1 (input handling) and Phase 2 (quick commands panel).

---

## Minor Pitfalls

---

### Pitfall 12: dartssh2 AES-GCM Not Enabled by Default

**What goes wrong:**
dartssh2 does not enable AES-GCM cipher by default. If the desktop's SSH server (`/etc/ssh/sshd_config`) restricts ciphers to AES-GCM only (a common hardened configuration), the handshake fails with a cipher negotiation error that surfaces as a generic connection failure with no user-facing explanation.

**Warning signs:**
- Connection fails immediately after TCP connect, before password prompt
- Error message does not clearly say "cipher mismatch"

**Prevention:**
In Phase 1, test against the actual CachyOS/OpenSSH server config at `192.168.1.x`. If cipher negotiation fails, enable AES-GCM explicitly in `SSHClient`. Document which algorithms the target server uses. Since this is a controlled LAN setup (one user, one server), the fix is straightforward once identified.

**Phase to address:** Phase 1 (connection) — discovered during initial integration test.

---

### Pitfall 13: LAN-Only Network Assumption Breaks on Mobile Data Fallback

**What goes wrong:**
When the phone switches from Wi-Fi to mobile data (e.g., the router is restarted), Android may fall back to the cellular interface. The app still shows "Connected" because the socket was not closed — the TCP connection just went dead. The user's prompt is silently dropped.

**Warning signs:**
- User sends a prompt, nothing happens, no error
- The OS switched networks while the app was open

**Prevention:**
The keepalive interval (Pitfall 4's prevention) catches this within 30 seconds. Additionally, show network quality in the connection status indicator. Consider listening to `connectivity_plus` package events to proactively prompt reconnection when the network interface changes.

**Phase to address:** Phase 3 (reconnection polish).

---

### Pitfall 14: Hard-Coded TERM Environment Variable

**What goes wrong:**
If `TERM` is not set or is set to a value the desktop SSH server does not recognize (e.g., `xterm-256color` when the server is not configured with that terminfo), commands like `clear`, `less`, and `vim` may behave oddly. Claude Code itself queries `TERM` to decide how much color to emit.

**Warning signs:**
- `less` or `man` output is garbled
- Claude Code emits no colors even when the connection works

**Prevention:**
When calling `client.shell()`, always set `environment: {'TERM': 'xterm-256color', 'LANG': 'en_US.UTF-8'}`. These are the standard values Claude Code and most Linux servers expect. Since the target is a controlled CachyOS desktop, `xterm-256color` is the correct choice.

**Phase to address:** Phase 1 (shell session setup).

---

---

# V2.0 MILESTONE PITFALLS

*Added: 2026-06-20. Specific to adding multi-session tabs, session start picker, biometric lock, and robust reconnection to the existing codebase.*

---

## Feature 1: Multi-Session Tabs

---

### Pitfall T1-01: autoDispose Kills Sessions When Tab Is Not Visible (CRITICAL)

**What goes wrong:**
`SshSession` is declared `@riverpod` which generates an `autoDispose.family` provider. Riverpod destroys an autoDispose provider one frame after its last listener is removed. When using a `TabBar` with standard `TabBarView` (not `IndexedStack`), the widget for the non-visible tab is unmounted. The `Consumer`/`ref.watch(sshSessionProvider(id))` inside that tab widget loses its listener. One frame later, Riverpod calls `ref.onDispose`, which fires `_disposed = true`, `_sshSession.close()`, `_client.close()`. The SSH session is terminated while the tab is just hidden.

**Why it happens in this codebase specifically:**
The existing `SshSession` provider already has `_disposed = true` set in `onDispose` and immediately calls `_sshSession?.close()`. There is no keepAlive call anywhere. Adding a second tab will reproduce this silently on the first tab switch.

**Consequences:** Every tab switch terminates the SSH connection to the inactive tab. The user returns to find the terminal dead and must reconnect manually.

**Prevention:**
Two-part solution:

1. **Navigator structure:** Use `StatefulShellRoute.indexedStack` from go_router (not plain `TabBarView`). This keeps all branch widgets in the widget tree even when not visible, preserving their `ref.watch` listeners and preventing autoDispose from firing. This is the correct architectural solution — do not use PageView or standard TabBarView.

2. **Explicit keepAlive as defense-in-depth:** Inside `SshSession.build()`, after the connection succeeds, call `ref.keepAlive()`. This prevents disposal even if a listener is accidentally dropped:
   ```dart
   @override
   Future<Terminal> build(String machineId) async {
     ref.onDispose(() { ... }); // existing cleanup
     final link = ref.keepAlive(); // ADD THIS
     // ... rest of build
   }
   ```
   Call `link.close()` only when the user explicitly closes a tab. This gives explicit control rather than relying on widget lifecycle alone.

**Phase to address:** Multi-session tabs phase. The `StatefulShellRoute.indexedStack` navigation structure must be decided before writing any tab UI code — it affects the entire routing architecture in `app.dart`.

---

### Pitfall T1-02: Riverpod 3 TickerMode Pausing Streams on Hidden Tabs

**What goes wrong:**
Riverpod 3 uses `TickerMode` to pause provider listeners when the widget hosting them is invisible. For a `StreamProvider` or a `Consumer` watching `sshSessionProvider`, this means the stdout stream listener may be paused when the tab is in the background. SSH data arriving while the tab is hidden is not consumed from the stream buffer. If the buffer fills (unlikely but possible with large Claude Code output bursts), the SSH channel can block.

**Why this is different from T1-01:** TickerMode pausing does NOT dispose the provider — the `SSHClient` stays connected and keepalive packets still fire. The problem is only that stdout bytes queue up unread. When the user returns to the tab, xterm receives a burst of buffered data and replays it correctly. This is acceptable behavior for this app.

**Prevention:**
Accept the buffering behavior — it is correct. The user will see a brief "catch-up" burst of output when returning to a tab. Do not try to work around TickerMode pausing. If the xterm terminal feels sluggish on tab return, increase `Terminal(maxLines: 5000)` to ensure the buffer holds more history without dropping lines.

**Phase to address:** Multi-session tabs phase. Note in implementation docs that this behavior is intentional.

---

### Pitfall T1-03: SSHClient Not Closed When Tab Is Explicitly Removed (Resource Leak)

**What goes wrong:**
When using `ref.keepAlive()` (from T1-01 prevention), autoDispose no longer closes the session automatically. If the user closes a tab (removes the session), the app must explicitly call `ref.invalidate(sshSessionProvider(machineId))` or close the keepAlive link to let autoDispose fire. Forgetting this leaves `SSHClient` open, the TCP socket open, and the remote shell running indefinitely. With 3-4 tabs opened and closed over time, the server accumulates zombie sessions.

**Prevention:**
Maintain a tab list in a separate `@Riverpod(keepAlive: true)` notifier (e.g., `activeTabsProvider`). When removing a tab from this list, explicitly invalidate the corresponding session provider:
```dart
ref.invalidate(sshSessionProvider(machineId));
```
This triggers onDispose, which closes `_sshSession` and `_client`. Test this by checking `who` on the server after closing tabs — zombie sessions are visible there.

**Phase to address:** Multi-session tabs phase. Add a tab close test case: open 3 tabs, close 2, verify server shows only 1 active session.

---

### Pitfall T1-04: go_router Route Change Disposes TerminalScreen When Navigating Away

**What goes wrong:**
The current routing in `app.dart` uses a nested `GoRoute` at `/machines/:id/terminal`. This is a push-based route — navigating to `/machines` pops TerminalScreen off the stack and disposes it. When adding multi-session tabs, if the tab implementation uses the existing push route instead of a shell route, navigating back to the machine list destroys all active terminal sessions.

**Prevention:**
Migrate the terminal feature to a `StatefulShellRoute` with separate branches for each active session. The machine list becomes a separate branch or a modal overlay, not a route that replaces the terminal stack. This is an architectural change to `app.dart` — design it once at the start of the multi-session phase, not as a retrofit.

**Phase to address:** Multi-session tabs phase, first task. Audit `app.dart` routing before adding any tab UI.

---

## Feature 2: Session Start Picker (ls + cd over SSH)

---

### Pitfall T2-01: Running ls Before SSH Session Is Fully Authenticated

**What goes wrong:**
The dartssh2 `SSHClient` constructor returns immediately after the TCP handshake begins, but authentication (password exchange, key verification) happens asynchronously. If the directory picker calls `client.run('ls')` immediately after `SSHClient(...)`, it may execute before the SSH handshake completes and throw `SSHStateError` or return empty output.

**Prevention:**
Always await `client.authenticated` before issuing any commands. The dartssh2 `SSHClient` exposes this future:
```dart
await client.authenticated;
final result = await client.run('ls -1ap');
```
In the existing codebase, `SshSession.build()` already awaits `client.shell()` which implicitly completes after authentication. For the directory picker, use a separate `client.run()` call (not the shell PTY) and await `client.authenticated` first.

**Phase to address:** Session start picker phase.

---

### Pitfall T2-02: Using ls Text Output Parsing Instead of SFTP listdir

**What goes wrong:**
Parsing `ls` output for a directory picker is brittle:
- Filenames with spaces: `ls -l` splits on spaces, breaking filenames like `my project/`
- Symlinks: `ls -l` shows `link -> target`, which requires special parsing to distinguish from regular files
- Localization: `ls` output format (date format, column order) differs by `LANG` setting
- Color codes: if TERM/COLORTERM is set, `ls` may emit ANSI color codes that pollute the parsed output
- Dotfiles: `ls` without `-a` hides them; `ls -a` includes `.` and `..` which must be filtered

The correct alternative is dartssh2's SFTP `listdir`:
```dart
final sftp = await client.sftp();
final items = await sftp.listdir(path);
```
SFTP `listdir` returns structured `SftpName` objects with `.filename`, `.attr.type` (file/dir/symlink), and `.longname` — no text parsing required.

**Prevention:**
Use `client.sftp()` + `sftp.listdir(path)` for the directory picker. Filter by `attr.type == SftpFileType.directory`. This eliminates all parsing edge cases.

**Phase to address:** Session start picker phase.

---

### Pitfall T2-03: Session Drop Between ls and cd — User Left Stranded

**What goes wrong:**
The session start picker shows directories from `sftp.listdir()`. The user selects one. Between the SFTP list call and the `cd` command being sent to the shell PTY, the SSH session could drop (Wi-Fi hiccup, server restart). The `cd` is sent to a dead session, the reconnection logic fires, and reconnection starts a fresh shell in the home directory — not the directory the user selected. The selected directory context is silently lost.

**Prevention:**
Store the selected directory path in the Riverpod notifier or pass it as a parameter to the reconnection logic:
```dart
// After user selects directory, store in session state
_selectedStartDirectory = selectedPath;

// During reconnection/shell init, send cd as first command
if (_selectedStartDirectory != null) {
  _sshSession!.write(utf8.encode('cd ${shellEscape(_selectedStartDirectory!)}\n'));
}
```
Always shell-escape the path before sending it as a command (`path.replaceAll("'", "'\\''")` for single-quote escaping). Test with paths containing spaces.

**Phase to address:** Session start picker phase. Also inform the reconnection phase (Feature 4) so reconnection logic knows to re-apply the start directory.

---

### Pitfall T2-04: SFTP Client Left Open After Directory Picker Closes

**What goes wrong:**
`client.sftp()` opens an SFTP subsystem channel over the existing SSH transport. If the SFTP client is not explicitly closed after the directory listing completes, the channel remains open for the lifetime of the SSH session. With multiple tab sessions each opening an SFTP channel for the picker, the server accumulates open SFTP channels. Some SSH server configurations limit simultaneous channels per connection.

**Prevention:**
Always close the SFTP client after the listing completes:
```dart
final sftp = await client.sftp();
try {
  final items = await sftp.listdir(path);
  return items;
} finally {
  sftp.close();
}
```

**Phase to address:** Session start picker phase.

---

## Feature 3: Biometric App Lock

---

### Pitfall T3-01: NSFaceIDUsageDescription Missing Causes Silent Crash on iOS (CRITICAL)

**What goes wrong:**
iOS requires `NSFaceIDUsageDescription` in `ios/Runner/Info.plist` before any app can use Face ID. Without this key, the app crashes silently when `authenticate()` is called on a Face ID-capable device. The crash happens at the OS level before any Dart code can catch it. The user sees the app disappear with no error message.

**Prevention:**
Add to `ios/Runner/Info.plist` before writing any `local_auth` code:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Claude Pilot uses Face ID to protect access to your SSH credentials.</string>
```
This must be done even if biometricOnly is false — the OS checks for this key whenever Face ID hardware is present, regardless of whether Face ID was actually used.

**Phase to address:** Biometric lock phase, first task before any local_auth integration.

---

### Pitfall T3-02: Android MainActivity Must Extend FlutterFragmentActivity

**What goes wrong:**
`local_auth` on Android uses `BiometricPrompt`, which requires a `FragmentActivity` to display its system overlay. If `MainActivity` extends `FlutterActivity` (the Flutter default), `local_auth` throws `PlatformException: Activity is not a FragmentActivity` at runtime. The biometric prompt never appears.

**Prevention:**
Change `android/app/src/main/kotlin/.../MainActivity.kt`:
```kotlin
// Change from:
class MainActivity: FlutterActivity()
// To:
class MainActivity: FlutterFragmentActivity()
```
Also add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

**Phase to address:** Biometric lock phase, first task alongside T3-01.

---

### Pitfall T3-03: biometricOnly: true Locks Out Users Without Enrolled Biometrics

**What goes wrong:**
Using `authenticate(options: AuthenticationOptions(biometricOnly: true))` on a device with no enrolled biometrics (or on emulators) throws `LocalAuthException` with code `noBiometricHardware` or `notEnrolled`. With `biometricOnly: true`, there is no fallback to device PIN/passcode. The user is completely locked out of the app. This is a particularly bad failure for an SSH remote control — the user is locked out of their Claude Code session.

**Prevention:**
Use `biometricOnly: false` (the default). This allows the OS biometric UI to fall back to device PIN/password if biometrics fail or are unavailable. Before calling `authenticate()`, call `isDeviceSupported()` — if it returns `false`, the device has no authentication hardware at all; in that case, show a settings prompt or allow access without biometric (the app does not store sensitive data beyond SSH credentials already protected by flutter_secure_storage).

**Phase to address:** Biometric lock phase.

---

### Pitfall T3-04: App Re-Lock on Background Is Not Automatic — Must Be Implemented Manually

**What goes wrong:**
`local_auth` provides authentication at a single call point. It does not track whether the app has been backgrounded and re-foregrounded. If the developer calls `authenticate()` only at app launch and does nothing else, a user can authenticate once, background the app, and return to it days later with full access — the biometric lock is bypassed. This is a common misunderstanding of what `local_auth` does.

**Prevention:**
Implement a `@Riverpod(keepAlive: true)` auth state notifier:
```dart
@Riverpod(keepAlive: true)
class BiometricLock extends _$BiometricLock {
  @override
  bool build() => false; // false = locked
  
  void unlock() => state = true;
  void lock() => state = false;
}
```
Use `WidgetsBindingObserver` (in a root widget or in a `ref.listen`) to monitor `AppLifecycleState`. When the app transitions to `hidden` or `paused`, call `lock()`. When it transitions back to `resumed`, if `state == false` (locked), show the biometric prompt. The `AppLifecycleState.hidden` state fires consistently on both iOS and Android before `paused` — use it as the lock trigger.

**Why `keepAlive: true`:** The auth state must survive navigation, tab switches, and any other provider disposal. Using `@riverpod` (autoDispose) here would silently reset the auth state to `false` (locked) any time no widget was watching it, which could cause spurious re-authentication prompts.

**Phase to address:** Biometric lock phase.

---

### Pitfall T3-05: Auth State Stored in an autoDispose Provider — Accidentally Resets

**What goes wrong:**
If the biometric auth state is stored in a provider that uses `@riverpod` (autoDispose), the state resets to "locked" the moment no widget is watching it. This happens during navigation transitions, during the loading state of the machine list, or any time the auth UI widget unmounts briefly. The user is shown the biometric prompt again even though they just authenticated.

**Prevention:**
Declare the biometric lock provider with `@Riverpod(keepAlive: true)` (or `keepAlive: true` in annotation form). The auth state should live as long as the app process — it is global singleton state. This is one of the few valid uses of keepAlive: true in this codebase. Do not mix this with the SSH session providers (which correctly use autoDispose).

**Phase to address:** Biometric lock phase.

---

### Pitfall T3-06: stickyAuth: false (Default) Cancels Auth on iOS Phone Calls

**What goes wrong:**
By default, `authenticate()` has `stickyAuth: false`. If the user receives a phone call while the Face ID prompt is displayed, iOS backgrounds the app. With `stickyAuth: false`, the authentication call returns `false` (failure) immediately. The app locks itself out and the user must tap the biometric button again after their call. Worse, if the app interprets a `false` return as a security failure and shows an error state, the user is confused.

**Prevention:**
Use `stickyAuth: true`:
```dart
await auth.authenticate(
  localizedReason: '...',
  options: const AuthenticationOptions(stickyAuth: true),
);
```
With `stickyAuth: true`, if the app is backgrounded during authentication, the plugin retries authentication when the app resumes. This is the correct behavior for an app-lock feature.

**Phase to address:** Biometric lock phase.

---

## Feature 4: Robust Reconnection

---

### Pitfall T4-01: Timer.periodic in Retry Loop Not Cancelled on Dispose — Causes Crash (CRITICAL)

**What goes wrong:**
The current `SshSession.build()` uses `await Future.delayed(const Duration(seconds: 1))` for retry delays (line 71). For robust reconnection, the temptation is to replace this with a `Timer.periodic` or a series of `Timer` calls for exponential backoff. If the `Timer` is created inside `build()` or a method called from `build()`, and `ref.onDispose` does not cancel it, the timer fires after the provider is disposed. The timer callback calls `state = AsyncLoading()` or attempts to reconnect on a disposed notifier, causing a `StateError: Notifier disposed` crash or a "setState called after dispose" equivalent.

**Why this is especially dangerous in this codebase:**
`SshSession.build()` is `async` and the disposal guard `_disposed = true` only prevents new connection attempts via the `for` loop. A separate `Timer` created outside that loop would bypass the `_disposed` check entirely.

**Prevention:**
Always register timer cancellation in `ref.onDispose` BEFORE creating the timer, using the pattern:
```dart
Timer? _retryTimer;

// In ref.onDispose (registered at top of build):
ref.onDispose(() {
  _disposed = true;
  _retryTimer?.cancel();
  _sshSession?.close();
  _client?.close();
  _permissionController.close();
});

// When creating a retry timer:
_retryTimer = Timer(delay, _attemptReconnect);
```
Alternatively, keep using `Future.delayed` with `_disposed` checks (the current pattern) extended with exponential backoff via a loop variable:
```dart
final delay = Duration(seconds: min(pow(2, attempt).toInt(), 30));
await Future.delayed(delay);
if (_disposed) break;
```
This is safer than a standalone Timer because `Future.delayed` is cancelled implicitly when the Dart isolate no longer holds a reference to the completer. However, explicitly checking `_disposed` after every `await` remains essential.

**Phase to address:** Robust reconnection phase. Audit every `await` in `SshSession.build()` and any methods it calls — each one needs a `if (_disposed) return;` guard after it.

---

### Pitfall T4-02: Retry Loop Fires After ref.onDispose — Race Condition with Async Gap

**What goes wrong:**
`ref.onDispose` is synchronous, but the retry loop in `build()` is `async`. There is a window between when `onDispose` sets `_disposed = true` and when the currently-awaited `Future.delayed` or `_connectOnce` call completes. During this window, the code after the `await` runs and may call `state = AsyncError(...)` or attempt to write to `_permissionController` after it has been closed. In the existing code (line 91), `_client!.done.catchError` calls `state = AsyncError(e, StackTrace.current)` without checking `_disposed` first.

**Prevention:**
Wrap every state mutation after an await with the `_disposed` guard:
```dart
_client!.done.catchError((Object e) {
  if (!_disposed) state = AsyncError(e, StackTrace.current); // already done in existing code
});
```
For the new reconnection logic, add the guard after every `await`:
```dart
await Future.delayed(delay);
if (_disposed) return; // guard every await point
```
This pattern is already partially present in the existing code — extend it consistently to all new awaits added during the reconnection refactor.

**Phase to address:** Robust reconnection phase.

---

### Pitfall T4-03: Emitting AsyncLoading During Retry Clears Terminal State

**What goes wrong:**
The temptation during reconnection is to emit `state = AsyncLoading()` to show a spinner. However, `SshSession` returns `AsyncValue<Terminal>`. When `state` becomes `AsyncLoading`, any widget doing `ref.watch(sshSessionProvider(id)).when(data: (terminal) => TerminalView(terminal))` re-renders the loading state, which unmounts `TerminalView`. The `xterm` `Terminal` object is the in-memory buffer holding all the scrollback history. If `TerminalView` is unmounted and the `Terminal` object is recreated on the next connection, the user loses all terminal history.

**Prevention:**
Use a separate reconnection state — do not reuse `AsyncLoading`. Options:
1. Keep `state` as `AsyncData(terminal)` with the existing `Terminal` object during reconnection. Add a separate `bool _reconnecting` field to the notifier and expose it via a second provider or a custom data class.
2. Use `AsyncValue.data` with a custom `SessionState` class that includes both the `Terminal` and a `ReconnectionStatus` enum.

The second option is cleaner but requires changing the provider type. Option 1 (separate field with a separate small provider) is lower risk during the reconnection phase:
```dart
// Separate provider for reconnection UI state
@riverpod
class SshReconnecting extends _$SshReconnecting { ... }
```
The `Terminal` object must survive reconnection — do not recreate it. Pass the existing `Terminal` back to the new `SSHSession` stdout listener on successful reconnect.

**Phase to address:** Robust reconnection phase.

---

### Pitfall T4-04: iOS Suspends Background Timers — Reconnection Never Fires While Backgrounded

**What goes wrong:**
iOS suspends Dart isolates when the app goes to background. All timers, `Future.delayed`, and `Timer.periodic` stop executing. If the SSH connection drops while the app is backgrounded, the reconnection timer never fires until the user brings the app to the foreground. This is expected iOS behavior, but it means the app cannot proactively reconnect in the background — it must reconnect reactively when the user returns.

**What not to do:** Do not attempt to use `flutter_background_service` or iOS background modes for reconnection. Background fetch runs at most every 15 minutes and is allowed only ~30 seconds of execution. It is not suitable for maintaining SSH connections.

**Prevention:**
Design reconnection as a foreground-only operation:
1. On `AppLifecycleState.resumed`, detect that the connection is dead (via `_disposed`, `_client?.isClosed`, or a liveness probe).
2. Trigger reconnection immediately on resume, before the user interacts.
3. Show a reconnecting UI overlay on the terminal screen on resume if connection is lost.

Do not design reconnection to "run in the background." Design it to "reconnect instantly on foreground." This matches user expectations: the user opens the app and sees "Reconnecting..." for 1-2 seconds, which is acceptable.

**Phase to address:** Robust reconnection phase. Coordinate with `WidgetsBindingObserver` from T3-04 — the same lifecycle observer handles both biometric re-lock and reconnection trigger.

---

### Pitfall T4-05: Riverpod 3 Built-In Auto-Retry May Conflict With Custom Retry Logic

**What goes wrong:**
Riverpod 3.0 introduced automatic retry for providers that fail during initialization with exponential backoff (starting at 200ms, doubling to max 6.4s). If `SshSession.build()` throws during connection, Riverpod 3 may automatically retry the `build()` method. This interacts with the custom retry loop already in `build()` — the result could be nested retries: 3 inner retry attempts per outer Riverpod-triggered build retry, creating up to 9 connection attempts per reconnection event.

**Prevention:**
Disable Riverpod 3's auto-retry for `SshSession` explicitly:
```dart
@Riverpod(retry: false) // or equivalent annotation
class SshSession extends _$SshSession { ... }
```
Use only the custom retry logic already present in `build()`, extended with exponential backoff. This gives full control over retry timing, maximum attempts, and error state transitions.

Check the Riverpod 3 documentation/changelog for the exact annotation or configuration API for disabling auto-retry — this was introduced in 3.0 and the API may differ from the snippet above.

**Phase to address:** Robust reconnection phase. Verify Riverpod 3 retry behavior before implementing custom backoff.

---

## Integration Pitfalls (Cross-Feature)

---

### Pitfall I-01: Biometric Lock Prompt Races With SSH Reconnection on App Resume

**What goes wrong:**
On app resume after backgrounding, two things must happen: biometric re-authentication (Feature 3) and SSH session liveness check/reconnection (Feature 4). If implemented independently, they race each other. The SSH reconnection attempt may complete (or fail and show an error dialog) while the biometric prompt is still on screen, resulting in an error dialog appearing behind the biometric overlay, or a reconnection completing that the user cannot see because they are still authenticating.

**Prevention:**
Sequence these operations explicitly on `AppLifecycleState.resumed`:
1. Set `BiometricLock.state = locked` (synchronous).
2. Show biometric prompt and await result.
3. Only if authentication succeeds: trigger SSH liveness check and reconnection.

Use a single `AppLifecycleObserver` at the root widget level (not inside each tab) to coordinate both operations. A Riverpod `ref.listen(biometricLockProvider, ...)` in the reconnection logic can trigger reconnection only after the lock is cleared.

**Phase to address:** Implement in the later of biometric lock and robust reconnection phases. If implementing reconnection first, add a placeholder check (`if (isLocked) return`) for the biometric gate.

---

### Pitfall I-02: Session Start Picker State Lost on Reconnection

**What goes wrong:**
The session start picker selects an initial working directory. After reconnection, the shell starts in the SSH user's home directory. The selected working directory is not re-applied. The user sees the terminal reconnected but `pwd` returns `~` instead of the previously selected project directory.

**Prevention:**
Store the selected start directory in the `SshSession` notifier as a field (`String? _startDirectory`). In the `_connectOnce` method, after the PTY shell is established, send `cd` as the first command if `_startDirectory != null`. This must also work during Riverpod's retry and during the explicit reconnection triggered by Feature 4.

**Phase to address:** Ensure this is handed off between the session picker phase and the reconnection phase in the implementation plan.

---

### Pitfall I-03: Multiple Active SSH Clients Saturate LAN Connection or Server Session Limit

**What goes wrong:**
With multi-session tabs, each tab opens a separate `SSHClient` (TCP connection + SSH transport) to the same server. Claude Code on the server may also open its own sub-processes. The server's SSH daemon has a configurable `MaxSessions` limit (default 10 in OpenSSH). With 3-4 tabs open, plus a session picker's SFTP channel (if not closed, see T2-04), the limit can be reached. New connection attempts fail with `too many sessions` or `connection refused`.

**Prevention:**
Close SFTP clients after use (T2-04). Limit the number of concurrent sessions to a reasonable maximum (e.g., 4) in the tab manager UI. Validate that SFTP channels are torn down before the tab connection count becomes the binding constraint.

**Phase to address:** Multi-session tabs phase. Test with 4 tabs + SFTP channel open simultaneously on the actual CachyOS server.

---

## Updated Phase-Specific Warnings

| Phase | Topic | Likely Pitfall | Mitigation |
|-------|-------|---------------|------------|
| 1 | Connection lifecycle | SSHStateError on transport close | Wrap session.done in try-catch; attach catchError to client.done |
| 1 | Terminal rendering | Cursor-up/EL sequences broken | Use xterm.dart, not custom ANSI appender |
| 1 | PTY dimensions | Fixed columns break Ink output | Compute from widget width; wire resizeTerminal to layout changes |
| 1 | Credential storage | Auto-backup destroys keys | Add backup exclusion to AndroidManifest before first build |
| 1 | minSdkVersion | Build failure or runtime crash | Set minSdkVersion 23 in build.gradle explicitly |
| 1 | Shell environment | No color / garbled output | Set TERM=xterm-256color in environment map |
| 1 | iOS backgrounding | Silent dead session | keepAliveInterval: 30s + AppLifecycleState observer |
| 2 | Voice dictation | SDK 30+ silent init failure | Add <queries> intent block before writing recognition code |
| 2 | Voice dictation | Silence timeout truncates prompt | Visual recognition state + require manual send tap |
| 3 | Reconnection | Network switch shows no error | connectivity_plus + liveness probe on resume |
| v2-tabs | app.dart routing | Tab switch disposes SSH sessions | Use StatefulShellRoute.indexedStack, add ref.keepAlive() in SshSession.build() |
| v2-tabs | Riverpod autoDispose | Tab close leaks SSHClient | Call ref.invalidate(sshSessionProvider(id)) on explicit tab close |
| v2-tabs | go_router architecture | Push route disposes all sessions | Migrate terminal to StatefulShellRoute branches before writing tab UI |
| v2-picker | SFTP vs ls | ls parsing breaks on spaces/symlinks | Use client.sftp().listdir() — structured output, no parsing |
| v2-picker | Session readiness | Command runs before auth complete | await client.authenticated before any exec/sftp call |
| v2-picker | SFTP resource leak | Channel stays open after picker | try/finally sftp.close() after listdir |
| v2-biometric | iOS | Silent crash without NSFaceIDUsageDescription | Add to Info.plist before any local_auth code |
| v2-biometric | Android | BiometricPrompt requires FragmentActivity | Change MainActivity to extend FlutterFragmentActivity |
| v2-biometric | Auth state | autoDispose resets lock state on nav | Use @Riverpod(keepAlive: true) for BiometricLock provider |
| v2-biometric | Re-lock | App not re-locked on background | WidgetsBindingObserver on AppLifecycleState.hidden triggers lock |
| v2-reconnect | Timer lifecycle | Timer fires after dispose → crash | ref.onDispose(timer.cancel) registered before timer creation |
| v2-reconnect | Async race | State written after dispose | if (_disposed) guard after every await in build() and reconnect methods |
| v2-reconnect | Terminal history | AsyncLoading wipes Terminal buffer | Keep Terminal alive through reconnection; use separate reconnecting state |
| v2-reconnect | iOS background | Timers suspended while backgrounded | Design reconnection as resume-triggered, not background-continuous |
| v2-reconnect | Riverpod 3 auto-retry | Double retry: built-in + custom | Disable Riverpod 3 auto-retry for SshSession provider |
| v2-integration | Resume sequence | Biometric + reconnect race on resume | Sequence: lock → authenticate → reconnect; use single lifecycle observer |
| v2-integration | Working directory | Start directory lost on reconnect | Store _startDirectory in notifier; re-apply cd after every reconnect |

---

## Sources

**V1.0 Sources:**
- dartssh2 documentation (Context7): `SSHClient` constructor, `keepAliveInterval` parameter, `SSHPtyConfig` — HIGH confidence
- dartssh2 GitHub Issue #86 "SSHStateError(Transport is closed)": confirmed bug in transport close sequence — HIGH confidence
- xterm.dart reference implementation (`example/lib/ssh.dart`): PTY resize pattern `terminal.onResize → session.resizeTerminal` — HIGH confidence
- flutter_secure_storage v10 release notes: minSdkVersion 23, auto-backup `InvalidKeyException`, `migrateWithBackup` option — HIGH confidence
- flutter_secure_storage GitHub Issue #1037: minSdkVersion 23 vs 24 enforcement discrepancy — MEDIUM confidence (open issue, may be resolved in latest patch)
- speech_to_text README (Context7): Android SDK 30 `<queries>` requirement, silence timeout not configurable — HIGH confidence
- Claude Code Ink renderer (DeepWiki): EL sequences, cursor tracking, color memoization for SSH — MEDIUM confidence (architectural analysis, not official Anthropic docs)
- Apple Developer Forums: iOS background TCP suspension behavior — HIGH confidence (platform behavior, well documented)
- Google Auto Backup + Android Keystore mismatch: multiple flutter_secure_storage GitHub issues — HIGH confidence

**V2.0 Sources:**
- Riverpod official docs (riverpod.dev/docs/concepts2/auto_dispose): autoDispose one-frame delay, ref.keepAlive(), onCancel/onResume callbacks — HIGH confidence
- Riverpod 3.0 changelog (riverpod.dev/docs/whats_new): TickerMode-based listener pausing, auto-retry with exponential backoff, unified Notifier interfaces — HIGH confidence
- Riverpod GitHub Discussion #4293: autoDispose fires after first await in async providers — HIGH confidence
- dartssh2 README (github.com/TerminalStudio/dartssh2): `client.authenticated` future, `client.run()` vs `client.shell()`, SFTP `listdir()` — HIGH confidence
- local_auth pub.dev package page: Android SDK 24+ support, biometricOnly behavior, stickyAuth option — HIGH confidence
- local_auth flutter/flutter GitHub Issue #108945: biometricOnly:false requiring biometric on some Android devices — MEDIUM confidence (closed as not planned, device-specific)
- local_auth flutter/flutter GitHub Issue #112796: biometricOnly:false PIN fallback bug — MEDIUM confidence (closed as invalid)
- Flutter AppLifecycleState API docs (api.flutter.dev): hidden/paused/inactive states, platform consistency via AppLifecycleListener — HIGH confidence
- AppLifecycleState flutter/flutter GitHub Issue #26886: iOS vs Android paused state inconsistency — HIGH confidence
- iOS background execution limits (appsonair.com/blogs): timers suspended, ~10s background task window — HIGH confidence (Apple platform behavior)
- StatefulShellRoute go_router documentation (medium.com/@harshhub.414): dispose only on shell removal, IndexedStack state preservation — MEDIUM confidence (verified against flutter/flutter GitHub issues #150837, #164187)
- local_auth Android setup (medium.com/@henryifebunandu): FlutterFragmentActivity requirement, USE_BIOMETRIC permission — HIGH confidence (consistent across multiple sources)
