# Phase 1: SSH Terminal — Research

**Researched:** 2026-06-19
**Domain:** Flutter mobile SSH terminal (dartssh2 + xterm.dart + Riverpod)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**App Navigation & Structure**
- Navigation system: `go_router` — declarative routing, deep-link ready, current Flutter standard
- Directory layout: feature-first — `lib/features/machines/` and `lib/features/terminal/`
- Entry point: `ProviderScope` wraps `MaterialApp.router` in `main.dart`
- Material version: Material 3 with `useMaterial3: true` and a dark `ColorScheme`

**Machine Manager UI**
- Machine list: full-page `ListView` with a FAB to add new machines
- Add/edit machine: dedicated page (`/machines/add`, `/machines/:id/edit`) — more room for form fields than a bottom sheet
- Connection status indicator: colored dot + text label (connected = green, disconnected = grey, error = red)
- Credential entry: username + password fields only (v1 constraint — no passphrase/key support)

**Terminal Screen Layout**
- Layout: `Column` — `Expanded(TerminalView)` fills the available height; `InputBar` pinned at bottom, sits above the software keyboard via `resizeToAvoidBottomInset: true`
- PTY sizing: computed from `MediaQuery` at mount — `columns = width ~/ 8`, `rows = availableHeight ~/ 16`; wired to `xterm.Terminal.onResize` → `session.resizeTerminal()`; updated on `LayoutBuilder` changes
- App bar: minimal `AppBar` showing machine name + disconnect `IconButton` — connection state must remain visible; no fullscreen immersive
- Scrollback: xterm.dart built-in buffer (default 1000 lines)

**Input Bar Controls**
- Control buttons: horizontal `Row` of chip-style buttons above the text field — Ctrl+C, Ctrl+D, ESC
- Send button: always visible `IconButton` at end of text field row
- Input field: single-line `TextField` with `TextInputAction.send`; `onSubmitted` fires same handler as send button
- Keyboard dismiss: Android back dismisses keyboard only; disconnect is an explicit AppBar action

### Claude's Discretion
- Exact color values for dark theme (background, surface, terminal bg) — use Material 3 dark baseline or xterm.dart default colors
- Exact font size and padding for input bar
- Error/loading states UI (connecting spinner, error snackbar vs. inline message)
- Whether to show a confirmation dialog before deleting a machine

### Deferred Ideas (OUT OF SCOPE)
- Reconnect on drop (RECON-01..03) — v2
- iOS keepAlive (keepAliveInterval: 30s) — v2
- SSH key authentication — v2 (v1 is password-only)
- Custom theme settings — v2
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MACH-01 | User can add a machine with name, IP, SSH port (default 22), username, and password | Machine data model + shared_preferences for metadata + flutter_secure_storage for password |
| MACH-02 | User sees the saved machine list with connection status (available / offline) | machineRepositoryProvider (NotifierProvider) + ListView + colored status dot |
| MACH-03 | User can edit an existing machine's data | /machines/:id/edit route via go_router + same form as add |
| MACH-04 | User can delete a saved machine | Dismissible + AlertDialog confirmation + secure storage delete |
| MACH-05 | SSH credentials stored encrypted on device | flutter_secure_storage 10.3.1 — key: `ssh_password_<uuid>` |
| SSH-01 | User can connect to a machine via SSH with a single tap | SSHClient(SSHSocket.connect()) in AsyncNotifier.build() |
| SSH-02 | App shows connection state (connecting / connected / error) | AsyncValue from AsyncNotifier: loading → connecting, data → connected, error → error |
| SSH-03 | App handles unexpected connection close without crashing (SSHStateError) | client.done.catchError() + try-catch wrapper on session lifecycle |
| SSH-04 | PTY is sized dynamically to screen width and updates when keyboard appears/disappears | LayoutBuilder → columns = width ~/ 8, rows = height ~/ 16 → session.resizeTerminal() |
| TERM-01 | Claude Code output shown in real time with full ANSI colors (256 colors) | xterm.dart Terminal.write() — handles xterm-256color; PTY type must be 'xterm-256color' |
| TERM-02 | Cursor sequences (spinners, in-place diffs) rendered correctly via xterm.dart | xterm.dart VT100/VT220/xterm-256color cell buffer — handles EL, ED, cursor-up |
| TERM-03 | Terminal has dark background, monospace font, and scrollable history | xterm.dart default theme + TerminalView; TerminalTheme for custom colors |
| TERM-04 | Text adapts to screen width without cutting characters | PTY resize wired to LayoutBuilder; terminal renders within Expanded widget |
| INP-01 | User can type a prompt in a text field and send it with a button | TextField + send IconButton → session.write(utf8.encode(text + '\n')) |
| INP-02 | User can execute Ctrl+C with a tap (interrupt process) | session.write(Uint8List.fromList([0x03])) |
| INP-03 | User can execute Ctrl+D with a tap (EOF / close session) | session.write(Uint8List.fromList([0x04])) |
| INP-04 | User can send ESC with a tap | session.write(Uint8List.fromList([0x1b])) |
</phase_requirements>

---

## Summary

Phase 1 is the foundational walking skeleton: a Flutter app that stores SSH machine credentials, opens a real PTY session over dartssh2, and renders Claude Code output with full ANSI fidelity via xterm.dart. The stack is entirely pre-decided in CONTEXT.md — there are no library choices to evaluate; all research focuses on HOW to use the locked stack correctly.

The key technical relationship: dartssh2 and xterm.dart are written by the same team (TerminalStudio). They ship an official SSH example (`example/lib/ssh.dart`) that demonstrates the five-line wiring between `SSHSession.stdout`, `Terminal.write()`, and `terminal.onOutput`. This example is the canonical reference implementation for Phase 1 — the executor must read it before writing any session code.

The primary risks are lifecycle-related, not capability-related. dartssh2 throws `SSHStateError(Transport is closed)` when the transport dies during cleanup — this must be guarded from day one. Android auto-backup to Google Drive causes `InvalidKeyException` on key restore if `android:allowBackup="false"` is not set before the first build. Both are one-line fixes that must land in the project skeleton before any functional code.

**Primary recommendation:** Build bottom-up — models → repository → provider → machine UI → SSH session → terminal rendering → input bar. Verify each layer works before building on it. The official xterm.dart SSH example is the authoritative wiring reference.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Machine CRUD (add/edit/delete) | App State (Riverpod NotifierProvider) | Persistence (shared_preferences + flutter_secure_storage) | Metadata is non-sensitive; password is sensitive — two storage layers required |
| SSH session lifecycle | App State (AsyncNotifier.autoDispose.family) | Transport (dartssh2 SSHClient) | autoDispose closes socket when screen is popped — lifecycle lives in Riverpod, not widget |
| Terminal rendering | Widget (xterm TerminalView) | App State (Terminal object held by provider) | Terminal IS the state (extends ChangeNotifier); provider holds it, TerminalView consumes it directly |
| PTY dimension updates | Widget (LayoutBuilder) | Transport (dartssh2 session.resizeTerminal) | Layout changes are widget events; must bridge to SSH layer via provider method |
| SSH byte → ANSI → display | Transport → App State → Widget | — | One stream pipeline: SSHSession.stdout → Terminal.write() → TerminalView repaint |
| User input → SSH stdin | Widget (InputBar) → Provider → Transport | — | InputBar calls provider method; provider writes to SSHSession.stdin |
| Control signals (Ctrl+C/D, ESC) | Widget (chip buttons) → Provider → Transport | — | Same path as text input but send raw bytes, not text |
| Credential encryption | Platform (flutter_secure_storage) | — | OS Keychain / Android Keystore — no app-layer crypto |
| Navigation | App (go_router) | — | Declarative; routes defined in app.dart; provider not involved in routing |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dartssh2` | 2.18.0 | SSH transport, PTY session, stdin/stdout streams | Pure Dart, no FFI/JNI, same author as xterm.dart, official SSH example in xterm repo [VERIFIED: pub.dev] |
| `xterm` | 4.0.0 | Full VT100/xterm-256color terminal emulator widget | Only Flutter package implementing proper cell buffer + cursor tracking + 60fps canvas render [VERIFIED: pub.dev] |
| `flutter_riverpod` | 3.3.2 | State management — SSH session lifecycle + machine list | AsyncNotifier.autoDispose.family maps exactly to SSH session lifecycle [VERIFIED: pub.dev] |
| `riverpod_annotation` | 4.0.3 | `@riverpod` annotation for code generation | Companion to flutter_riverpod for type-safe provider generation [VERIFIED: pub.dev] |
| `flutter_secure_storage` | 10.3.1 | Encrypted credential storage (iOS Keychain / Android Keystore) | Only pub.dev package using native OS encrypted storage; minSdkVersion 23 enforced [VERIFIED: pub.dev] |
| `shared_preferences` | 2.5.5 | Non-sensitive machine metadata (name, IP, port, username) | Official Flutter team package; no setup; machine list is flat < 10 items [VERIFIED: pub.dev] |
| `go_router` | 17.3.0 | Declarative routing and deep-link navigation | Flutter favorite, flutter.dev publisher, requires Flutter >= 3.38 (project is on 3.41.9) [VERIFIED: pub.dev] |

### Dev Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| `riverpod_generator` | 4.0.4 | Code generation for @riverpod-annotated providers [VERIFIED: pub.dev] |
| `build_runner` | latest | Runs riverpod_generator during development |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `xterm` | Custom ANSI parser | VT100 state machine is weeks of work; Claude Code uses cursor-up/EL sequences that break naive appenders |
| `xterm` | `ansi_styles` / `flutter_ansi_parser` | Color-strip only, no PTY cell buffer, no cursor movement — not a real terminal |
| `flutter_riverpod` | `bloc` | Excessive event/state boilerplate for a single-developer streaming app |
| `flutter_riverpod` | `provider` | Deprecated by same author; no autoDispose; manual dispose → SSH connection leaks |
| `flutter_secure_storage` | `shared_preferences` for passwords | SharedPreferences is plaintext; readable via ADB backup on Android |
| `go_router` | `Navigator 2.0` directly | go_router IS Navigator 2.0 with a declarative API; using Nav2 raw is 5x more boilerplate |

### Complete pubspec.yaml

```yaml
name: claude_pilot
description: Mobile remote control for Claude Code via SSH
version: 1.0.0+1
publish_to: none

environment:
  sdk: ^3.7.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter

  # SSH transport
  dartssh2: ^2.18.0

  # Terminal rendering (full ANSI + xterm-256color)
  xterm: ^4.0.0

  # State management
  flutter_riverpod: ^3.3.2
  riverpod_annotation: ^4.0.3

  # Credential storage (OS-encrypted)
  flutter_secure_storage: ^10.3.1

  # Machine metadata (non-sensitive)
  shared_preferences: ^2.5.5

  # Navigation
  go_router: ^17.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^4.0.4
  build_runner:

flutter:
  uses-material-design: true
```

---

## Package Legitimacy Audit

> slopcheck was unavailable at research time. All packages verified via pub.dev official API (`pub.dev/api/packages/<name>`). All packages are from known verified publishers or the official Flutter team.

| Package | Registry | Publisher | Downloads Signal | Source Repo | slopcheck | Disposition |
|---------|----------|-----------|-----------------|-------------|-----------|-------------|
| `dartssh2` | pub.dev | terminal.studio (verified) | Active pub.dev presence, xterm.dart integration example | github.com/TerminalStudio/dartssh2 | unavailable | Approved — verified publisher + Context7 confirmation |
| `xterm` | pub.dev | terminal.studio (verified) | 1.5k+ GitHub stars, 140/160 pub points | github.com/TerminalStudio/xterm.dart | unavailable | Approved — verified publisher + Context7 confirmation |
| `flutter_riverpod` | pub.dev | dash-overflow.net (Remi Rousselet, verified) | Flutter favorite, millions of downloads | github.com/rrousselGit/riverpod | unavailable | Approved — Flutter favorite, Context7 confirmation |
| `riverpod_annotation` | pub.dev | dash-overflow.net (verified) | Same monorepo as flutter_riverpod | github.com/rrousselGit/riverpod | unavailable | Approved — same author/monorepo |
| `riverpod_generator` | pub.dev | dash-overflow.net (verified) | Same monorepo as flutter_riverpod | github.com/rrousselGit/riverpod | unavailable | Approved — same author/monorepo |
| `flutter_secure_storage` | pub.dev | juliansteenbakker (verified) | Flutter favorite, widely adopted | github.com/juliansteenbakker/flutter_secure_storage | unavailable | Approved — Flutter favorite, Context7 confirmation |
| `shared_preferences` | pub.dev | flutter.dev (official Flutter team) | Core Flutter plugin, bundled in many apps | github.com/flutter/packages | unavailable | Approved — official Flutter team |
| `go_router` | pub.dev | flutter.dev (official Flutter team) | Flutter favorite, 3.25M+ downloads | github.com/flutter/packages | unavailable | Approved — official Flutter team |

**Packages removed due to slopcheck [SLOP] verdict:** none

**Packages flagged as suspicious [SUS]:** none

*slopcheck was unavailable at research time. All packages listed above are from verified pub.dev publishers or the official Flutter team (`flutter.dev`). No checkpoint:human-verify required — publisher verification serves as the legitimacy gate for this Dart/Flutter ecosystem.*

---

## Architecture Patterns

### System Architecture Diagram

```
User (phone)
    │
    │ tap "Connect"
    ▼
go_router
    │ push /terminal/:machineId
    ▼
TerminalScreen (ConsumerWidget)
    │ ref.watch(sshSessionProvider(machineId))
    │
    ├── AsyncValue.loading → CircularProgressIndicator
    ├── AsyncValue.error   → error SnackBar + disabled InputBar
    └── AsyncValue.data(terminal) ──────────────────────────┐
                                                             │
                                                             ▼
                                                   TerminalView(terminal: terminal)
                                                   [xterm.dart widget — 60fps Canvas]
                                                             │
                                            TerminalTheme (dark bg, monospace)
                                            LayoutBuilder → resizeTerminal(cols, rows)

InputBar (always rendered)
    │ onSend(text)           → provider.sendText(text + '\n')
    │ onCtrlC()              → provider.sendBytes([0x03])
    │ onCtrlD()              → provider.sendBytes([0x04])
    │ onEsc()                → provider.sendBytes([0x1b])
    ▼
sshSessionProvider(machineId) [AsyncNotifier.autoDispose.family]
    │
    │ ref.onDispose → _session?.close(); _client?.close()
    │
    ├── build():
    │   machineRepo.get(id) → Machine
    │   SSHSocket.connect(host, port)
    │   SSHClient(socket, username, onPasswordRequest)
    │   client.shell(pty: SSHPtyConfig('xterm-256color', 80, 24))
    │   terminal = Terminal(maxLines: 2000)
    │   session.stdout.cast<List<int>>().transform(Utf8Decoder()).listen(terminal.write)
    │   session.stderr.cast<List<int>>().transform(Utf8Decoder()).listen(terminal.write)
    │   terminal.onOutput = (data) => session.write(utf8.encode(data))
    │   client.done.catchError((e) => _handleDisconnect(e))
    │   return terminal
    │
    └── sendText(text)  → _session?.write(utf8.encode(text))
        sendBytes(bytes) → _session?.write(Uint8List.fromList(bytes))

machineRepositoryProvider [NotifierProvider]
    │
    ├── machines: List<Machine>           → shared_preferences (key: 'machines_v1')
    └── passwords: Map<uuid, String>      → flutter_secure_storage (key: 'ssh_password_<uuid>')

MachineListScreen (/machines)
    │ ref.watch(machineRepositoryProvider)
    │ ListView of machines + status dot + FAB
    │ tap → go_router.push('/terminal/:id')
    └── FAB → go_router.push('/machines/add')

AddEditMachineScreen (/machines/add, /machines/:id/edit)
    │ Form: name, host, port, username, password
    │ Save → machineRepo.save(machine)
    └── Delete → machineRepo.delete(id)
```

### Recommended Project Structure

```
lib/
├── main.dart                          # ProviderScope + runApp(ClaudePilotApp())
├── app.dart                           # MaterialApp.router + GoRouter config + ThemeData
│
├── core/
│   ├── models/
│   │   └── machine.dart               # Machine(id, name, host, port, username) — Freezed or plain class
│   ├── repositories/
│   │   └── machine_repository.dart    # MachineRepository: CRUD + shared_prefs + secure_storage
│   └── theme/
│       └── app_theme.dart             # ColorScheme.fromSeed(#1E8BC3, dark) + TerminalTheme
│
├── features/
│   ├── machines/
│   │   ├── providers/
│   │   │   └── machines_provider.dart        # machineRepositoryProvider (NotifierProvider)
│   │   ├── screens/
│   │   │   ├── machine_list_screen.dart
│   │   │   └── add_edit_machine_screen.dart
│   │   └── widgets/
│   │       └── machine_list_tile.dart         # ListTile with status dot
│   │
│   └── terminal/
│       ├── providers/
│       │   └── ssh_session_provider.dart      # SshSession (AsyncNotifier.autoDispose.family)
│       ├── screens/
│       │   └── terminal_screen.dart
│       └── widgets/
│           ├── terminal_view_wrapper.dart     # LayoutBuilder → resizeTerminal wiring
│           └── input_bar.dart                 # TextField + Ctrl+C/D/ESC chips + send button
```

### Pattern 1: SSH Session as AsyncNotifier.autoDispose.family

**What:** The SSH session is owned by a Riverpod `AsyncNotifier` parameterized by `machineId`. It connects during `build()`, exposes the `Terminal` object as its state, and disposes the `SSHClient` and `SSHSession` via `ref.onDispose`.

**When to use:** Any state that has an async initialization sequence AND must be cleaned up when no longer watched. SSH connections fit perfectly.

```dart
// Source: xterm.dart official SSH example + Riverpod docs (Context7 /rrousselgit/riverpod)
// File: lib/features/terminal/providers/ssh_session_provider.dart

part 'ssh_session_provider.g.dart';

@riverpod
class SshSession extends _$SshSession {
  SSHClient? _client;
  SSHSession? _session; // Note: SSHSession from dartssh2, not Riverpod

  @override
  Future<Terminal> build(String machineId) async {
    ref.onDispose(() {
      _session?.close();
      _client?.close();
    });

    final machine = ref.read(machineRepositoryProvider.notifier).get(machineId);
    final password = await ref.read(machineRepositoryProvider.notifier).getPassword(machineId);

    _client = SSHClient(
      await SSHSocket.connect(machine.host, machine.port),
      username: machine.username,
      onPasswordRequest: () => password,
      // Note: keepAliveInterval deferred to v2 per CONTEXT.md
    );

    // Guard transport close — does NOT throw, channels error to _handleDisconnect
    _client!.done.catchError((e) {
      if (mounted) state = AsyncError(e, StackTrace.current);
    });

    final terminal = Terminal(maxLines: 2000);

    _session = await _client!.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: terminal.viewWidth > 0 ? terminal.viewWidth : 80,
        height: terminal.viewHeight > 0 ? terminal.viewHeight : 24,
      ),
      environment: {'TERM': 'xterm-256color', 'LANG': 'en_US.UTF-8'},
    );

    // Wire stdout + stderr → terminal model
    _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    _session!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    // Wire terminal keyboard → SSH stdin
    terminal.onOutput = (data) => _session?.write(utf8.encode(data));

    return terminal;
  }

  void sendText(String text) {
    _session?.write(utf8.encode(text));
  }

  void sendBytes(List<int> bytes) {
    _session?.write(Uint8List.fromList(bytes));
  }

  void resizeTerminal(int columns, int rows) {
    _session?.resizeTerminal(columns, rows, 0, 0);
  }
}
```

### Pattern 2: TerminalView with LayoutBuilder Resize Wiring

**What:** Wrap `TerminalView` in a `LayoutBuilder` to detect dimension changes (keyboard show/hide, rotation) and call `resizeTerminal` on the provider.

**When to use:** Every time TerminalView is mounted. This is mandatory for SSH-04.

```dart
// Source: CONTEXT.md + xterm.dart official SSH example
// File: lib/features/terminal/widgets/terminal_view_wrapper.dart

class TerminalViewWrapper extends ConsumerWidget {
  final String machineId;
  final Terminal terminal;

  const TerminalViewWrapper({
    super.key,
    required this.machineId,
    required this.terminal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute PTY dimensions from available space
        // 8dp per char column, 16dp per char row (monospace approximation)
        final cols = (constraints.maxWidth / 8).floor().clamp(40, 220);
        final rows = (constraints.maxHeight / 16).floor().clamp(10, 60);

        // Notify SSH session of new dimensions
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sshSessionProvider(machineId).notifier).resizeTerminal(cols, rows);
        });

        return TerminalView(
          terminal,
          theme: const TerminalTheme(
            cursor: Color(0xFF4BA3C7),
            selection: Color(0xFF4BA3C7),
            foreground: Color(0xFFCDD6F4),
            background: Color(0xFF0F1117),
            // ... other xterm theme colors matching Material 3 dark seed
          ),
          autofocus: false,
          // Do NOT use resizeToFit: true if LayoutBuilder already manages resize
        );
      },
    );
  }
}
```

### Pattern 3: Machine Repository with Split Storage

**What:** Machine metadata (name, host, port, username, UUID) stored in `shared_preferences` as JSON list. Password stored separately in `flutter_secure_storage` keyed by UUID.

**When to use:** Any entity with a mix of sensitive and non-sensitive fields — never store everything in secure storage (unnecessary overhead) or everything in shared_prefs (credentials exposure).

```dart
// Source: CLAUDE.md + flutter_secure_storage Context7 docs
// File: lib/core/repositories/machine_repository.dart

class MachineRepository {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _machinesKey = 'machines_v1';
  static String _passwordKey(String id) => 'ssh_password_$id';

  Future<List<Machine>> loadAll() async {
    final json = _prefs.getStringList(_machinesKey) ?? [];
    return json.map((s) => Machine.fromJson(jsonDecode(s))).toList();
  }

  Future<void> save(Machine machine, String password) async {
    final machines = await loadAll();
    final index = machines.indexWhere((m) => m.id == machine.id);
    if (index >= 0) {
      machines[index] = machine;
    } else {
      machines.add(machine);
    }
    await _prefs.setStringList(
      _machinesKey,
      machines.map((m) => jsonEncode(m.toJson())).toList(),
    );
    await _secure.write(key: _passwordKey(machine.id), value: password);
  }

  Future<void> delete(String machineId) async {
    final machines = await loadAll();
    machines.removeWhere((m) => m.id == machineId);
    await _prefs.setStringList(
      _machinesKey,
      machines.map((m) => jsonEncode(m.toJson())).toList(),
    );
    await _secure.delete(key: _passwordKey(machineId));
  }

  Future<String?> getPassword(String machineId) =>
      _secure.read(key: _passwordKey(machineId));
}
```

### Pattern 4: go_router Route Configuration

**What:** Declarative route table in `app.dart`. Two top-level routes plus nested terminal route.

```dart
// Source: go_router official docs (flutter.dev publisher, pub.dev)
// File: lib/app.dart

final _router = GoRouter(
  initialLocation: '/machines',
  routes: [
    GoRoute(
      path: '/machines',
      builder: (context, state) => const MachineListScreen(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddEditMachineScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          builder: (context, state) => AddEditMachineScreen(
            machineId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: ':id/terminal',
          builder: (context, state) => TerminalScreen(
            machineId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
  ],
);
```

### Anti-Patterns to Avoid

- **Custom ANSI parser:** Claude Code's Ink renderer uses cursor-up (`\x1b[A`), erase-in-line (`\x1b[K`), and SGR sequences. Any append-only text approach produces a waterfall of spinner frames instead of in-place updates. Use `xterm.dart` exclusively — `Terminal.write()` handles the full VT100 spec.
- **Global SSHClient singleton:** `static final _instance` persists across navigation and leaks connections. Use `AsyncNotifier.autoDispose.family(machineId)` — Riverpod disposes the client when the screen is popped.
- **Storing SSH password in SharedPreferences:** Plaintext on device; readable via ADB backup. Use `flutter_secure_storage` keyed by machine UUID.
- **Hard-coding PTY dimensions (80x24):** Claude Code's Ink renderer uses terminal width for line-wrap. A mismatch between PTY cols and visible widget width produces horizontally scrolling garbage. Wire `LayoutBuilder` → `resizeTerminal` from the first build.
- **Skipping `android:allowBackup="false"`:** Google Drive auto-backup copies the encrypted blob but not the Android Keystore key. On restore, every `flutter_secure_storage` read throws `InvalidKeyException`. Set this in `AndroidManifest.xml` before the first device test.
- **Sending voice transcript automatically:** SPEC mandates the transcript is editable before send. Never auto-send on `SpeechRecognitionResult.finalResult == true` — this is deferred to Phase 2 but the pattern must be established correctly.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ANSI terminal rendering | Custom regex parser, RichText word-wrap | `xterm` 4.0.0 | VT100 has 100+ escape sequences; Claude Code uses cursor-up/EL/SGR; correct implementation is months of work |
| SSH handshake + PTY | Raw TCP socket + SSH protocol | `dartssh2` 2.18.0 | SSH protocol negotiation alone is thousands of lines; dartssh2 handles cipher suites, key exchange, PTY |
| Encrypted local storage | AES + SharedPreferences | `flutter_secure_storage` 10.3.1 | Android Keystore / iOS Keychain integration requires JNI/platform code; not possible in pure Dart |
| Reactive SSH session lifecycle | StatefulWidget + dispose() | Riverpod `AsyncNotifier.autoDispose.family` | Manual dispose() on StatefulWidget does not fire reliably on navigation pop under all conditions |
| Declarative routing | `Navigator.push` / `MaterialPageRoute` | `go_router` 17.3.0 | Navigator 2.0 raw API requires 5x more boilerplate; go_router is the Flutter team's supported abstraction |

**Key insight:** Every problem in this phase has a well-established package solution from the Flutter ecosystem. The value of Phase 1 is the integration — not any individual algorithm. Time spent on custom solutions reduces quality without improving architecture.

---

## Common Pitfalls

### Pitfall 1: SSHStateError — Transport is Closed

**What goes wrong:** When the desktop reboots, Wi-Fi drops, or SSH daemon is killed, dartssh2 raises `SSHStateError(Transport is closed)` as an unhandled exception. Code that awaits `session.done` or calls `client.close()` after the transport is already dead crashes with an unhandled exception.

**Why it happens:** The xterm.dart reference example wires streams with no error handling — developers copy that pattern and miss that `client.done` can throw rather than complete normally.

**How to avoid:** Attach `.catchError()` to `client.done` at connection time. Never await `session.done` or `client.close()` without a surrounding try-catch. In the AsyncNotifier, funnel all transport errors to `state = AsyncError(e, StackTrace.current)`.

**Warning signs:** App crashes when desktop sleeps or loses power; "Unhandled Exception: SSHStateError" in logcat.

---

### Pitfall 2: PTY Dimensions Fixed at Session Creation

**What goes wrong:** `client.shell()` takes a fixed `SSHPtyConfig(width, height)`. If the keyboard appears (shrinking the visible area) and `resizeTerminal` is not called, Claude Code's Ink renderer wraps at the wrong column width — producing horizontally scrolling garbage or truncated diff blocks.

**Why it happens:** There is no automatic bridge between Flutter `LayoutBuilder` resize events and `session.resizeTerminal()`. The developer must wire them explicitly.

**How to avoid:** Wrap `TerminalView` in a `LayoutBuilder`. On every constraint change, recompute `cols = width ~/ 8`, `rows = height ~/ 16`, and call `session.resizeTerminal(cols, rows, 0, 0)`. Use `addPostFrameCallback` to avoid calling during build.

**Warning signs:** Diff output truncated at wrong column; spinner frames overwriting adjacent lines; Claude Code permission cards wrapping mid-word.

---

### Pitfall 3: Android Auto-Backup Destroys Encryption Keys

**What goes wrong:** Google Drive auto-backup copies `flutter_secure_storage`'s encrypted blob but NOT the Android Keystore key that decrypts it. After restoring to a new device, every credential read throws `java.security.InvalidKeyException`. All saved machine passwords are permanently lost.

**Why it happens:** Google's Auto Backup captures `shared_prefs/` by default but does not capture Android Keystore entries (by design — keys are device-bound).

**How to avoid:** Add `android:allowBackup="false"` to `<application>` in `AndroidManifest.xml` before the first build. This is a one-line change that must land in the project skeleton.

**Warning signs:** `PlatformException` on first credential read after app reinstall or restore; all saved machines disappear after restoring from backup.

---

### Pitfall 4: minSdkVersion Not Set to 23

**What goes wrong:** `flutter_secure_storage` v10+ enforces `minSdkVersion 23`. If `build.gradle` uses the Flutter default (21), the build fails with a Gradle SDK version conflict, or the package silently malfunctions on Android 5.x devices.

**Why it happens:** Flutter's default `minSdkVersion` is 21. The package enforces 23 via its own Gradle config.

**How to avoid:** Explicitly set `minSdkVersion 23` in `android/app/build.gradle` before writing any code. Also set `compileSdkVersion 34` (or 35).

**Warning signs:** Gradle build error: `uses-sdk:minSdkVersion X cannot be smaller than version Y`.

---

### Pitfall 5: TERM Environment Variable Not Set

**What goes wrong:** If `TERM` is not set or set to a non-recognized value, Claude Code emits no colors. If the server doesn't have `xterm-256color` terminfo, commands like `less` and `man` behave oddly.

**Why it happens:** `client.shell()` does not set environment variables by default. The shell inherits whatever the server defaults to.

**How to avoid:** Always pass `environment: {'TERM': 'xterm-256color', 'LANG': 'en_US.UTF-8'}` to `client.shell()`. The target is a CachyOS desktop — `xterm-256color` terminfo is guaranteed to exist.

**Warning signs:** Terminal output appears without any colors even when the SSH connection works; `less` output is garbled.

---

### Pitfall 6: Soft Keyboard Covers InputBar

**What goes wrong:** `resizeToAvoidBottomInset: true` (which CONTEXT.md mandates) causes the `Scaffold` to shrink when the keyboard appears. The terminal viewport shrinks AND the scroll position jumps, creating a jarring UX.

**Why it happens:** Flutter's default `Scaffold` resizing behavior applies to the entire layout including the terminal, not just the InputBar.

**How to avoid:** The CONTEXT.md decision to use `resizeToAvoidBottomInset: true` is correct for keeping the InputBar visible. The key detail is that `Expanded(TerminalView)` flexes to fill remaining space, so when the keyboard appears, the TerminalView shrinks in height and the InputBar stays visible. This is the intended behavior. The PTY resize wiring (Pitfall 2) handles the resulting dimension change.

**Warning signs:** InputBar hidden behind keyboard (wrong — means `resizeToAvoidBottomInset: false`); terminal scrolls to bottom on keyboard appear (expected behavior on first keyboard open, acceptable).

---

### Pitfall 7: go_router 17.x Requires Flutter 3.38+

**What goes wrong:** go_router 17.3.0 introduced a minimum Flutter SDK requirement of 3.38. Projects on older Flutter will get a pub resolution error.

**Why it happens:** go_router 17.2.0+ updated its SDK constraints.

**How to avoid:** The project is on Flutter 3.41.9 (confirmed via `flutter --version`). No action needed. Document `flutter: ">=3.38.0"` in pubspec.yaml to make the constraint explicit.

**Warning signs:** `pub get` fails with "The current Flutter SDK version is X. Because go_router >=17.0.0 requires Flutter SDK version >=3.38.0".

---

## Code Examples

### SSH Session Provider (Complete)

```dart
// Source: xterm.dart official SSH example + Riverpod docs
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm/xterm.dart';

part 'ssh_session_provider.g.dart';

@riverpod
class SshSession extends _$SshSession {
  SSHClient? _client;
  SSHSession? _session;  // dartssh2 SSHSession type

  @override
  Future<Terminal> build(String machineId) async {
    ref.onDispose(() {
      _session?.close();
      _client?.close();
    });

    final machine = ref.read(machineRepositoryProvider.notifier).get(machineId);
    final password = await ref.read(machineRepositoryProvider.notifier).getPassword(machineId);

    _client = SSHClient(
      await SSHSocket.connect(machine.host, machine.port),
      username: machine.username,
      onPasswordRequest: () => password ?? '',
    );

    // Guard transport close — prevents unhandled SSHStateError
    _client!.done.catchError((e) {
      if (mounted) state = AsyncError(e, StackTrace.current);
    });

    final terminal = Terminal(maxLines: 2000);

    _session = await _client!.shell(
      pty: const SSHPtyConfig(type: 'xterm-256color', width: 80, height: 24),
      environment: {'TERM': 'xterm-256color', 'LANG': 'en_US.UTF-8'},
    );

    _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    _session!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    terminal.onOutput = (data) => _session?.write(utf8.encode(data));

    return terminal;
  }

  void sendText(String text) => _session?.write(utf8.encode(text));
  void sendBytes(List<int> bytes) => _session?.write(Uint8List.fromList(bytes));
  void resizeTerminal(int cols, int rows) => _session?.resizeTerminal(cols, rows, 0, 0);
}
```

### AndroidManifest.xml Required Changes

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required for SSH over Wi-Fi -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="claude_pilot"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false">   <!-- REQUIRED: prevents flutter_secure_storage key loss on backup restore -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">  <!-- Required for resizeToAvoidBottomInset -->
```

### android/app/build.gradle Required Settings

```groovy
android {
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.example.claude_pilot"
        minSdkVersion 23          // REQUIRED: flutter_secure_storage v10+ enforces this
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }
}
```

### InputBar Widget Skeleton

```dart
// Control signal byte constants
const _ctrlC = [0x03];  // SIGINT
const _ctrlD = [0x04];  // EOF
const _esc   = [0x1b];  // Escape

class InputBar extends ConsumerStatefulWidget {
  final String machineId;
  const InputBar({super.key, required this.machineId});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(sshSessionProvider(widget.machineId).notifier).sendText('$text\n');
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sshSessionProvider(widget.machineId));
    final isConnected = sessionAsync.hasValue;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Control chips row
          Row(
            children: [
              for (final (label, bytes) in [
                ('Ctrl+C', _ctrlC),
                ('Ctrl+D', _ctrlD),
                ('ESC', _esc),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    onPressed: isConnected
                        ? () => ref.read(sshSessionProvider(widget.machineId).notifier)
                            .sendBytes(bytes)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Text input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => isConnected ? _send() : null,
                  enabled: isConnected,
                  decoration: const InputDecoration(
                    hintText: 'Type a prompt…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
                onPressed: isConnected ? _send : null,
                tooltip: 'Send',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `provider` package (ChangeNotifier) | `flutter_riverpod` (AsyncNotifier) | Riverpod released 2021, v3 in 2024 | autoDispose + family removes entire class of connection leak bugs |
| Navigator 1.0 (`Navigator.push`) | `go_router` (Navigator 2.0 declarative) | go_router became Flutter Favorite 2022 | Deep linking, type-safe routes, easier testing |
| Custom ANSI color parsers | `xterm.dart` full terminal emulator | xterm.dart 3.0.0 added Flutter 3.x support | Correct VT100 rendering without implementing the spec from scratch |
| `ssh` package (abandoned 2019) | `dartssh2` | Active since 2021 | Pure Dart, maintained, same author as xterm.dart |
| `flutter_secure_storage` v8 (API 21) | v10+ (API 23) | v10.0.0 in 2024 | Moved from deprecated EncryptedSharedPreferences to Android Keystore RSA OAEP + AES-GCM |

**Deprecated/outdated:**
- `provider` package: deprecated by its own author (Remi Rousselet) in favor of Riverpod. Still works but no autoDispose support.
- `ssh` pub.dev package: last release 2019, incompatible with current Dart SDK.
- `flutter_secure_storage` v8 and below: used `EncryptedSharedPreferences` which is deprecated in Android API 33+.

---

## Open Questions

1. **dartssh2 AES-GCM cipher compatibility with the target desktop SSH server**
   - What we know: dartssh2 does not enable AES-GCM by default. Most OpenSSH default configs accept chacha20-poly1305 and aes256-ctr, which dartssh2 does support by default.
   - What's unclear: Whether the target CachyOS desktop's `/etc/ssh/sshd_config` restricts ciphers to AES-GCM only.
   - Recommendation: Test connection in a Wave 1 integration test against the actual server. If cipher negotiation fails, enable AES-GCM explicitly via `SSHClient` cipher configuration. This is a known-solvable issue discoverable only at runtime.

2. **TerminalTheme color values for ANSI 256-color palette**
   - What we know: xterm.dart's `TerminalTheme` accepts 256-color palette overrides. The UI-SPEC mandates `colorScheme.surface` (~`#0F1117`) as terminal background.
   - What's unclear: Whether xterm.dart's default 256-color ANSI palette needs tuning for Claude Code's specific color choices to be readable against `#0F1117`.
   - Recommendation: Use xterm.dart's default ANSI palette initially. The UI-SPEC explicitly notes "executor must NOT override" the terminal font — apply the same conservatism to the color palette unless specific colors are illegible in testing.

3. **`TerminalView` keyboard input vs. custom `InputBar` keyboard conflict**
   - What we know: `TerminalView` has its own keyboard handling when `autofocus: true`. The CONTEXT.md decision uses a separate `TextField` in the InputBar for user input, not the TerminalView's built-in keyboard.
   - What's unclear: Whether `TerminalView` with `autofocus: false` correctly passes focus to the InputBar's `TextField` without interaction conflicts.
   - Recommendation: Set `TerminalView(autofocus: false)` and let the `InputBar` `TextField` own focus. Tap outside the `TextField` dismisses the keyboard. Test on physical Android device — emulators may behave differently for focus.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All Flutter code | ✓ | 3.41.9 (stable) | — |
| Dart SDK | All Dart code | ✓ | Bundled with Flutter 3.41.9 | — |
| Android SDK / Gradle | Android build | ✓ | Installed (system has flutter) | — |
| Physical Android device / emulator | SSH connection testing (emulator may not replicate real SSH) | [ASSUMED] | — | Emulator acceptable for UI; physical device needed for SSH integration |
| SSH server on LAN (CachyOS desktop) | SSH-01 integration testing | [ASSUMED] | OpenSSH | Cannot test SSH without server |
| `build_runner` (Dart) | Riverpod code generation | ✓ | Will be installed via `flutter pub get` | — |

**Missing dependencies with no fallback:**
- Physical device or emulator for mobile testing — required before verifying SSH-01 through SSH-04.

**Missing dependencies with fallback:**
- LAN SSH server — not required for UI development tasks (MACH-01 through MACH-04 can be verified without a live SSH connection).

---

## Project Constraints (from CLAUDE.md)

| Directive | Type | Impact on Phase 1 |
|-----------|------|-------------------|
| Flutter only (iOS + Android) | Required | All code is Dart/Flutter; no native modules |
| LAN only — no internet dependency | Required | SSH direct to local IP; no cloud services; `INTERNET` permission granted only for SSH socket |
| `flutter_secure_storage` for SSH credentials | Required | Passwords stored with `ssh_password_<uuid>` key |
| ANSI color fidelity — render exactly as desktop | Required | `xterm.dart` mandatory; no custom ANSI parser |
| SSH via `dartssh2` | Required | No alternative SSH packages |
| `flutter_riverpod` for state | Required | AsyncNotifier.autoDispose.family for SSH session |
| `go_router` for navigation | Required | Declarative routes in app.dart |
| Material 3 dark theme | Required | `ColorScheme.fromSeed(seedColor: Color(0xFF1E8BC3), brightness: Brightness.dark)` |
| v1: password auth only | Required | No key auth UI; no passphrase fields |
| `android:allowBackup="false"` before any test | Required — noted in CONTEXT.md specifics | Must be first AndroidManifest.xml edit |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Physical Android device or emulator available for testing | Environment Availability | SSH connection tests (SSH-01..04) cannot be verified without one |
| A2 | CachyOS desktop SSH server accepts dartssh2's default cipher suite (chacha20-poly1305, aes256-ctr) | Open Questions #1 | Connection fails until cipher mismatch is diagnosed; one-day debugging task |
| A3 | xterm.dart's default 256-color ANSI palette is readable against `#0F1117` background | Open Questions #2 | Some ANSI colors may be illegible; requires TerminalTheme palette adjustment |
| A4 | `TerminalView(autofocus: false)` correctly yields focus to InputBar TextField | Open Questions #3 | If focus conflicts exist, keyboard may not appear when InputBar is tapped |

**If this table is empty:** N/A — 4 assumptions logged above.

---

## Sources

### Primary (HIGH confidence)
- pub.dev API `pub.dev/api/packages/<name>` — all package versions verified programmatically on 2026-06-19
- xterm.dart official SSH example: `github.com/TerminalStudio/xterm.dart/blob/master/example/lib/ssh.dart` — SSH wiring pattern (stdout/onOutput/onResize)
- CONTEXT.md (01-CONTEXT.md) — all locked implementation decisions
- UI-SPEC.md (01-UI-SPEC.md) — screen layout, colors, typography, spacing
- CLAUDE.md project constraints — stack, security requirements, storage schema
- REQUIREMENTS.md — all 17 Phase 1 requirement IDs
- Riverpod official docs `riverpod.dev/docs/introduction/getting_started` — pubspec.yaml setup for v3 with code generation
- go_router changelog `pub.dev/packages/go_router/changelog` — v17.3.0 Flutter 3.38 minimum requirement confirmed

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` — pre-existing domain research (dartssh2 + xterm.dart integration, Riverpod patterns, build order)
- `.planning/research/PITFALLS.md` — pre-existing pitfall catalog (SSHStateError, PTY resize, auto-backup, minSdkVersion)
- `.planning/research/STACK.md` — pre-existing stack analysis with package justifications
- `.planning/research/FEATURES.md` — pre-existing feature landscape analysis

### Tertiary (LOW confidence — [ASSUMED])
- Physical device/emulator availability assumption (cannot probe without device)
- SSH server cipher suite compatibility (cannot probe without live server)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all package versions verified via pub.dev API; publishers confirmed
- Architecture: HIGH — patterns derived from official xterm.dart SSH example + Riverpod docs + locked CONTEXT.md decisions
- Pitfalls: HIGH — dartssh2 SSHStateError and flutter_secure_storage auto-backup issues are documented in official/community sources; confirmed in pre-existing research
- go_router version requirement: HIGH — confirmed via pub.dev changelog

**Research date:** 2026-06-19

**Valid until:** 2026-07-19 (package versions change — re-verify pub.dev versions before adding to pubspec.yaml if more than 30 days pass)
