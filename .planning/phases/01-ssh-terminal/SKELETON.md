# Walking Skeleton: claude-pilot

**Phase:** 01-ssh-terminal
**Created:** 2026-06-19
**Status:** Defined — implemented by Plan 01

---

## What the Skeleton Delivers

The walking skeleton is the thinnest possible end-to-end stack. After Plan 01 completes:

- A Flutter app named `claude_pilot` boots on Android and iOS
- It shows the Machine List screen (dark themed, empty state)
- Navigation routes are wired (`/machines`, `/machines/add`, `/machines/:id/edit`, `/machines/:id/terminal`)
- All Phase 1 packages are installed and resolving
- Android is hardened against backup-key-loss and compile SDK floor is set
- Riverpod, go_router, and Material 3 dark theme are verified working

No features yet — but the skeleton proves every dependency resolves and the app launches.

---

## Architectural Decisions

These decisions are locked for all subsequent phases. Do not renegotiate them.

### Framework & Platform

| Decision | Value | Rationale |
|----------|-------|-----------|
| Framework | Flutter (Dart) | Single codebase for iOS + Android; user already has Flutter expertise (Semvy app) |
| Platform targets | Android + iOS | Primary dev device is Android; iOS builds alongside |
| Flutter SDK | >=3.38.0 | go_router 17.x requires 3.38+; project is on 3.41.9 |
| Dart SDK | ^3.7.0 | Bundled with Flutter 3.41.9 |
| Android minSdkVersion | 23 | flutter_secure_storage v10+ enforces this; set before first build |
| Android compileSdkVersion | 34 | Current stable |

### State Management

| Decision | Value | Rationale |
|----------|-------|-----------|
| Package | flutter_riverpod 3.3.2 + riverpod_annotation 4.0.3 | AsyncNotifier.autoDispose.family maps to SSH session lifecycle; autoDispose closes socket on pop |
| Pattern | @riverpod code generation | riverpod_generator 4.0.4 + build_runner; .g.dart files committed |
| SSH session provider | AsyncNotifier.autoDispose.family(machineId) | One provider instance per machine; disposed on navigation pop |
| Machine list provider | AsyncNotifier (NotifierProvider via @riverpod) | Holds List<Machine>; ref.invalidateSelf() after mutations |

### Navigation

| Decision | Value | Rationale |
|----------|-------|-----------|
| Package | go_router 17.3.0 | Flutter-team publisher; declarative; Navigator 2.0 abstraction |
| Initial route | /machines | Machine list is the home screen |
| Route table | /machines, /machines/add, /machines/:id/edit, /machines/:id/terminal | Defined in app.dart |

### Persistence

| Decision | Value | Rationale |
|----------|-------|-----------|
| Machine metadata | shared_preferences 2.5.5 — key: `machines_v1` (JSON list) | Non-sensitive; flat list <10 items; official Flutter team package |
| SSH passwords | flutter_secure_storage 10.3.1 — key: `ssh_password_<uuid>` | OS Keychain (iOS) / Android Keystore (Android); device-bound encryption |
| Split storage rule | NEVER store password in shared_preferences; NEVER use secure_storage for non-sensitive metadata | Principle of least privilege; backup key-loss prevention |

### SSH Transport

| Decision | Value | Rationale |
|----------|-------|-----------|
| Package | dartssh2 2.18.0 | Pure Dart; same author as xterm.dart; official SSH example in xterm repo |
| PTY type | xterm-256color | Required for Claude Code ANSI color output |
| PTY initial size | 80 columns x 24 rows | Until first LayoutBuilder measurement |
| Environment | TERM=xterm-256color, LANG=en_US.UTF-8 | Without TERM set, Claude Code outputs no colors |
| Auth | Password only (v1) | SSH key auth is v2 |
| Error handling | _client.done.catchError() at connection time | Prevents unhandled SSHStateError on network drop |

### Terminal Rendering

| Decision | Value | Rationale |
|----------|-------|-----------|
| Package | xterm 4.0.0 | Only Flutter package with full VT100/xterm-256color cell buffer + cursor tracking; same author as dartssh2 |
| Terminal state | Terminal object owned by SshSession provider | Terminal IS the state; TerminalView consumes it directly; no wrapper |
| Scrollback | 2000 lines (Terminal(maxLines: 2000)) | Default 1000 is low for Claude Code diff output |
| Autofocus | TerminalView(autofocus: false) | InputBar TextField owns focus; prevents keyboard conflict |
| PTY resize wiring | LayoutBuilder → addPostFrameCallback → resizeTerminal | Mandatory; without it, Claude Code Ink renderer wraps at wrong width |

### UI & Theme

| Decision | Value | Rationale |
|----------|-------|-----------|
| Material version | Material 3 (useMaterial3: true) | Current Flutter standard |
| Color scheme | ColorScheme.fromSeed(Color(0xFF1E8BC3), brightness: Brightness.dark) | Terminal-blue seed; dark baseline per user requirement |
| Terminal theme | TerminalTheme — background #0F1117, foreground #CDD6F4; Catppuccin-inspired palette | Matches colorScheme.surface; readable against dark background |
| Font (UI) | Roboto (Material 3 default) | No custom font in v1 |
| Font (terminal) | xterm.dart default monospace | Must NOT be overridden |

### Directory Structure

```
lib/
├── main.dart                                    # ProviderScope + runApp
├── app.dart                                     # MaterialApp.router + GoRouter + ThemeData
│
├── core/
│   ├── models/
│   │   └── machine.dart                         # Machine(id, name, host, port, username)
│   ├── repositories/
│   │   └── machine_repository.dart              # MachineRepository — CRUD + split storage
│   └── theme/
│       └── app_theme.dart                       # AppTheme.darkTheme + AppTheme.terminalTheme
│
└── features/
    ├── machines/
    │   ├── providers/
    │   │   └── machines_provider.dart           # @riverpod MachineRepository
    │   ├── screens/
    │   │   ├── machine_list_screen.dart
    │   │   └── add_edit_machine_screen.dart
    │   └── widgets/
    │       └── machine_list_tile.dart
    │
    └── terminal/
        ├── providers/
        │   └── ssh_session_provider.dart        # @riverpod SshSession (autoDispose.family)
        ├── screens/
        │   └── terminal_screen.dart
        └── widgets/
            ├── terminal_view_wrapper.dart       # LayoutBuilder + resizeTerminal wiring
            └── input_bar.dart                   # TextField + Ctrl+C/D/ESC chips
```

### Android-Specific Hardening

| Setting | Location | Value | Reason |
|---------|----------|-------|--------|
| android:allowBackup | AndroidManifest.xml | false | Prevents flutter_secure_storage key loss after backup restore |
| android:windowSoftInputMode | AndroidManifest.xml | adjustResize | Required for resizeToAvoidBottomInset to work |
| INTERNET permission | AndroidManifest.xml | granted | SSH over Wi-Fi |
| minSdkVersion | build.gradle | 23 | flutter_secure_storage v10+ enforces this |
| compileSdkVersion | build.gradle | 34 | Current stable |

---

## What Subsequent Phases Build On

- **Phase 2:** Imports from `lib/features/machines/providers/machines_provider.dart` and `lib/features/terminal/providers/ssh_session_provider.dart`; adds new feature directories under `lib/features/`; extends InputBar with voice dictation button and permission card overlay
- **Phase 3:** Cross-cutting stability — PTY resize edge cases, iOS keepAlive, connection robustness; no new features, refines existing files

---

## Constraints That Must Not Change

1. `dartssh2` is the only SSH package — no alternatives, no WebSocket bridge
2. `xterm` is the only terminal renderer — no custom ANSI parser
3. SSH password stored under `ssh_password_<uuid>` in flutter_secure_storage — key format is load-bearing for future phases
4. Machine metadata stored under `machines_v1` in shared_preferences — key format is load-bearing
5. `android:allowBackup="false"` must remain false — removing it destroys all user credentials on backup restore
