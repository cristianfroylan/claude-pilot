<!-- GSD:project-start source:PROJECT.md -->
## Project

**claude-pilot**

App móvil Flutter que funciona como control remoto para Claude Code sobre la red local vía SSH. La computadora corre Claude Code con todo su poder; el teléfono expone una interfaz mínima para enviar prompts, ver el output en tiempo real y aprobar acciones — sin tener que estar sentado frente al escritorio. El objetivo es la comodidad, no replicar la terminal en el teléfono.

**Core Value:** Enviar un prompt a Claude Code desde el teléfono y ver la respuesta llegar — sin abrir la laptop.

### Constraints

- **Tech stack**: Flutter — iOS + Android desde un solo codebase, ya familiar al usuario (tiene Semvy en Flutter)
- **Red**: Solo LAN local — sin dependencia de internet, sin servidores externos
- **Seguridad**: Credenciales SSH almacenadas con flutter_secure_storage (cifrado nativo del dispositivo)
- **Fidelidad visual**: El terminal debe renderizar colores ANSI igual a como los ve en su monitor — familiaridad como requisito
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Core Packages
### SSH Transport — dartssh2
| Field | Value |
|-------|-------|
| Package | `dartssh2` |
| Current version | **2.18.0** (published ~5 days ago as of research date) |
| Publisher | terminal.studio (verified) |
| Confidence | HIGH — verified via Context7 + pub.dev |
- `ssh2` (older, less maintained, no active pub.dev presence)
- `ssh` (pub.dev package — abandoned, last release 2019)
- WebSocket bridge on the desktop — adds an extra process and defeats the "minimal infra" goal
- `dart:io` raw sockets — would require implementing SSH handshake from scratch
### Terminal Renderer — xterm
| Field | Value |
|-------|-------|
| Package | `xterm` |
| Current version | **4.0.0** (published ~2 years ago; no newer release) |
| Publisher | terminal.studio (verified) |
| Flutter constraint | `>=3.0.0` |
| Confidence | HIGH — Context7 + official GitHub README + pub.dev |
- Custom ANSI parser + RichText: Claude Code output includes cursor movement, in-place rewrites
- `ansi_styles` / `flutter_ansi_parser` (pub.dev) — strip color for display only, no PTY model,
- `flutter_pty` alone — provides PTY plumbing but not a rendering widget.
### State Management — flutter_riverpod
| Field | Value |
|-------|-------|
| Package | `flutter_riverpod` |
| Current version | **3.3.2** (published ~9 days ago as of research date) |
| Publisher | dash-overflow.net / Remi Rousselet (verified) |
| Confidence | HIGH — Context7 + pub.dev |
- `StreamNotifierProvider.autoDispose` holds the SSH session and exposes `shell.stdout` as a stream.
- `ref.onDispose()` closes the SSH socket — no manual lifecycle management needed.
- `StreamProvider` handles the loading/connected/error states (connecting, connected, disconnected)
- Compile-time safety: provider references are typed, no `context.read<X>()` casting errors at
- Machine list (name, IP, credentials key reference) lives in a `NotifierProvider` — simple CRUD,
- `provider` package: `ChangeNotifier` + `StreamBuilder` works but requires manual `dispose()`
- `bloc` / `flutter_bloc`: Excellent for large teams needing enforced event→state flows, but for a
- `setState` + `StatefulWidget`: Fine for simple widgets, unacceptable for SSH session state that
### Credential Storage — flutter_secure_storage
| Field | Value |
|-------|-------|
| Package | `flutter_secure_storage` |
| Current version | **10.3.1** stable (11.0.0-beta.1 also available — do not use in v1) |
| Publisher | juliansteenbakker (verified) |
| Confidence | HIGH — Context7 + pub.dev changelog |
- Minimum iOS deployment target: **13.0** (darwin subpackage v0.4.0 raised it from 12 to 13 for
- Key SSH password by machine UUID: `ssh_password_<uuid>`.
- Machine metadata (name, IP, port, username) goes in `shared_preferences` — not sensitive, no
- `shared_preferences` for passwords: plaintext on device, readable without root on some Android
- `hive` with encryption: heavier dependency, same outcome as flutter_secure_storage but more setup.
- Hardcoding credentials: obvious.
### Voice Dictation — speech_to_text
| Field | Value |
|-------|-------|
| Package | `speech_to_text` |
| Current version | **7.4.0** (published ~30 days ago as of research date) |
| Publisher | csdcorp.com (verified) |
| Confidence | HIGH — Context7 + pub.dev |
- **Short pause timeout:** Android SpeechRecognizer auto-stops when the speaker pauses for ~3-5
- **Device beep:** Android plays an audible beep on start and stop of recognition. This is an OS
- **SpeechRecognizer unavailability:** On some Android devices (mainly stripped AOSP ROMs), the
- **Emulator:** Google app must have microphone permission granted separately in the emulator
- Whisper via `flutter_whisper` or similar: heavier model download, higher latency, overkill for
- Google Cloud Speech-to-Text API: requires internet, API key, billing, and breaks the LAN-only
- `record` + custom cloud STT: two packages where one suffices.
### Machine Metadata Storage — shared_preferences
| Field | Value |
|-------|-------|
| Package | `shared_preferences` |
| Current version | **2.5.5** (published ~2 months ago as of research date) |
| Publisher | flutter.dev (official Flutter team, verified) |
| Confidence | HIGH — pub.dev official |
- `flutter_secure_storage` for metadata: adds encryption overhead where none is needed. Reserve
- SQLite / `sqflite`: the data model is a flat list of <10 machines. A relational DB is
- `hive`: valid alternative but an extra dependency. `shared_preferences` covers this use case with
## Effective Android SDK Floor
## iOS Deployment Target
## Complete pubspec.yaml Dependencies
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
## Sources
- dartssh2: [pub.dev](https://pub.dev/packages/dartssh2) · [GitHub](https://github.com/TerminalStudio/dartssh2) · Context7 `/terminalstudio/dartssh2`
- xterm.dart: [pub.dev](https://pub.dev/packages/xterm) · [SSH example](https://github.com/TerminalStudio/xterm.dart/blob/master/example/lib/ssh.dart) · Context7 `/terminalstudio/xterm.dart`
- flutter_riverpod: [pub.dev](https://pub.dev/packages/flutter_riverpod) · Context7 `/rrousselgit/riverpod`
- flutter_secure_storage: [pub.dev](https://pub.dev/packages/flutter_secure_storage) · [GitHub](https://github.com/juliansteenbakker/flutter_secure_storage) · Context7 `/juliansteenbakker/flutter_secure_storage`
- speech_to_text: [pub.dev](https://pub.dev/packages/speech_to_text) · [GitHub](https://github.com/csdcorp/speech_to_text) · Context7 `/csdcorp/speech_to_text`
- shared_preferences: [pub.dev](https://pub.dev/packages/shared_preferences)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
