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

## Phase-Specific Warnings

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

---

## Sources

- dartssh2 documentation (Context7): `SSHClient` constructor, `keepAliveInterval` parameter, `SSHPtyConfig` — HIGH confidence
- dartssh2 GitHub Issue #86 "SSHStateError(Transport is closed)": confirmed bug in transport close sequence — HIGH confidence
- xterm.dart reference implementation (`example/lib/ssh.dart`): PTY resize pattern `terminal.onResize → session.resizeTerminal` — HIGH confidence
- flutter_secure_storage v10 release notes: minSdkVersion 23, auto-backup `InvalidKeyException`, `migrateWithBackup` option — HIGH confidence
- flutter_secure_storage GitHub Issue #1037: minSdkVersion 23 vs 24 enforcement discrepancy — MEDIUM confidence (open issue, may be resolved in latest patch)
- speech_to_text README (Context7): Android SDK 30 `<queries>` requirement, silence timeout not configurable — HIGH confidence
- Claude Code Ink renderer (DeepWiki): EL sequences, cursor tracking, color memoization for SSH — MEDIUM confidence (architectural analysis, not official Anthropic docs)
- Apple Developer Forums: iOS background TCP suspension behavior — HIGH confidence (platform behavior, well documented)
- Google Auto Backup + Android Keystore mismatch: multiple flutter_secure_storage GitHub issues — HIGH confidence
