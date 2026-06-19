# Phase 1: SSH Terminal - Pattern Map

**Mapped:** 2026-06-19
**Files analyzed:** 13 new files (greenfield — no existing source code)
**Analogs found:** 0 / 13 (greenfield project — all patterns sourced from RESEARCH.md code examples and official package documentation)

> **Greenfield note:** No Flutter/Dart source files exist in this repository. The project root contains only `CLAUDE.md`, `README.md`, and `SPEC.md`. Every pattern below is sourced from RESEARCH.md code examples (which were derived from the official xterm.dart SSH example and Riverpod docs) and from the locked decisions in CONTEXT.md. These are the founding patterns for the project — they will become the analogs that future phases copy.

---

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `pubspec.yaml` | config | — | none | no analog |
| `android/app/src/main/AndroidManifest.xml` | config | — | none | no analog |
| `android/app/build.gradle` | config | — | none | no analog |
| `lib/main.dart` | config | request-response | none | no analog |
| `lib/app.dart` | config | request-response | none | no analog |
| `lib/core/models/machine.dart` | model | transform | none | no analog |
| `lib/core/repositories/machine_repository.dart` | service | CRUD | none | no analog |
| `lib/core/theme/app_theme.dart` | config | — | none | no analog |
| `lib/features/machines/providers/machines_provider.dart` | provider | CRUD | none | no analog |
| `lib/features/machines/screens/machine_list_screen.dart` | component | request-response | none | no analog |
| `lib/features/machines/screens/add_edit_machine_screen.dart` | component | CRUD | none | no analog |
| `lib/features/machines/widgets/machine_list_tile.dart` | component | request-response | none | no analog |
| `lib/features/terminal/providers/ssh_session_provider.dart` | provider | streaming | none | no analog |
| `lib/features/terminal/screens/terminal_screen.dart` | component | streaming | none | no analog |
| `lib/features/terminal/widgets/terminal_view_wrapper.dart` | component | streaming | none | no analog |
| `lib/features/terminal/widgets/input_bar.dart` | component | event-driven | none | no analog |

---

## Pattern Assignments

### `pubspec.yaml` (config)

**Source:** RESEARCH.md `## Standard Stack > Complete pubspec.yaml`

**Complete file pattern:**
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
  dartssh2: ^2.18.0
  xterm: ^4.0.0
  flutter_riverpod: ^3.3.2
  riverpod_annotation: ^4.0.3
  flutter_secure_storage: ^10.3.1
  shared_preferences: ^2.5.5
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

### `android/app/src/main/AndroidManifest.xml` (config)

**Source:** RESEARCH.md `## Code Examples > AndroidManifest.xml Required Changes`

**Critical attributes — must land before any device test:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:allowBackup="false"
        android:windowSoftInputMode="adjustResize">
```

- `android:allowBackup="false"` prevents `InvalidKeyException` on flutter_secure_storage after backup restore (Pitfall 3 in RESEARCH.md)
- `android:windowSoftInputMode="adjustResize"` required for `resizeToAvoidBottomInset: true` to work correctly

---

### `android/app/build.gradle` (config)

**Source:** RESEARCH.md `## Code Examples > android/app/build.gradle Required Settings`

**Critical values:**
```groovy
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 23      // REQUIRED: flutter_secure_storage v10+ enforces this
        targetSdkVersion 34
    }
}
```

- `minSdkVersion 23` is mandatory — flutter_secure_storage v10+ will fail with a Gradle conflict on 21 (Pitfall 4 in RESEARCH.md)

---

### `lib/main.dart` (config, entry point)

**Source:** CONTEXT.md `## Implementation Decisions > App Navigation & Structure`

**Core pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ClaudePilotApp(),
    ),
  );
}
```

- `ProviderScope` must wrap `runApp` — this is the Riverpod requirement; all providers are scoped here
- No `WidgetsFlutterBinding.ensureInitialized()` needed unless async init (shared_preferences init happens in providers)

---

### `lib/app.dart` (config, routing)

**Source:** RESEARCH.md `## Architecture Patterns > Pattern 4: go_router Route Configuration`

**Imports pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/machines/screens/machine_list_screen.dart';
import 'features/machines/screens/add_edit_machine_screen.dart';
import 'features/terminal/screens/terminal_screen.dart';
import 'core/theme/app_theme.dart';
```

**Router pattern:**
```dart
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

**App widget pattern:**
```dart
class ClaudePilotApp extends StatelessWidget {
  const ClaudePilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Claude Pilot',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
```

---

### `lib/core/models/machine.dart` (model, transform)

**Source:** RESEARCH.md `## Architecture Patterns > Pattern 3` + CONTEXT.md `## Implementation Decisions`

**Core pattern (plain Dart class — no Freezed in v1):**
```dart
import 'package:uuid/uuid.dart'; // or use dart:math for uuid generation

class Machine {
  final String id;       // UUID — used as key for flutter_secure_storage
  final String name;
  final String host;
  final int port;        // default 22
  final String username;

  const Machine({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
  });

  Machine copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
  }) => Machine(
    id: id,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
  );

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
  };
}
```

- Password is NOT a field on Machine — it lives in flutter_secure_storage keyed by `ssh_password_<id>`
- `id` is generated at creation time (use `const Uuid().v4()` or equivalent)

---

### `lib/core/repositories/machine_repository.dart` (service, CRUD)

**Source:** RESEARCH.md `## Architecture Patterns > Pattern 3: Machine Repository with Split Storage`

**Imports pattern:**
```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/machine.dart';
```

**Core CRUD pattern:**
```dart
class MachineRepository {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _machinesKey = 'machines_v1';
  static String _passwordKey(String id) => 'ssh_password_$id';

  MachineRepository(this._prefs, this._secure);

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

  Machine? get(String machineId) => null; // synchronous lookup from loaded state
}
```

- Metadata (name, host, port, username) → `shared_preferences` key `machines_v1` as JSON list
- Password → `flutter_secure_storage` key `ssh_password_<uuid>`
- Never store password in shared_preferences (plaintext)

---

### `lib/core/theme/app_theme.dart` (config)

**Source:** RESEARCH.md `## Project Constraints` + UI-SPEC.md `## Color`

**Core pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E8BC3),
      brightness: Brightness.dark,
    ),
  );

  // TerminalTheme for xterm.dart — matches colorScheme.surface (~#0F1117)
  static const terminalTheme = TerminalTheme(
    cursor: Color(0xFF4BA3C7),
    selection: Color(0xFF4BA3C7),
    foreground: Color(0xFFCDD6F4),
    background: Color(0xFF0F1117),
    black: Color(0xFF1E2030),
    red: Color(0xFFFF757F),
    green: Color(0xFF66BB6A),
    yellow: Color(0xFFFFCB6B),
    blue: Color(0xFF82AAFF),
    magenta: Color(0xFFC792EA),
    cyan: Color(0xFF89DCEB),
    white: Color(0xFFCDD6F4),
    brightBlack: Color(0xFF444A73),
    brightRed: Color(0xFFFF757F),
    brightGreen: Color(0xFF66BB6A),
    brightYellow: Color(0xFFFFCB6B),
    brightBlue: Color(0xFF82AAFF),
    brightMagenta: Color(0xFFC792EA),
    brightCyan: Color(0xFF89DCEB),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFF4BA3C7),
    searchHitBackgroundCurrent: Color(0xFF4BA3C7),
    searchHitForeground: Color(0xFF0F1117),
  );
}
```

---

### `lib/features/machines/providers/machines_provider.dart` (provider, CRUD)

**Source:** RESEARCH.md `## Architecture Patterns > System Architecture Diagram`

**Imports pattern:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/machine.dart';
import '../../../core/repositories/machine_repository.dart';

part 'machines_provider.g.dart';
```

**Core Riverpod NotifierProvider pattern:**
```dart
@riverpod
class MachineRepository extends _$MachineRepository {
  @override
  Future<List<Machine>> build() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    _repo = MachineRepositoryImpl(prefs, secure);
    return _repo.loadAll();
  }

  MachineRepositoryImpl? _repo;

  Future<void> save(Machine machine, String password) async {
    await _repo?.save(machine, password);
    ref.invalidateSelf();
  }

  Future<void> delete(String machineId) async {
    await _repo?.delete(machineId);
    ref.invalidateSelf();
  }

  Machine? get(String machineId) {
    return state.valueOrNull?.firstWhere((m) => m.id == machineId);
  }

  Future<String?> getPassword(String machineId) =>
      _repo?.getPassword(machineId) ?? Future.value(null);
}
```

- Uses `@riverpod` annotation — requires `build_runner` code generation to produce `.g.dart` file
- `ref.invalidateSelf()` after mutations causes the list to reload from storage
- `NotifierProvider` (not `AsyncNotifier`) if state can be held synchronously after initial load

---

### `lib/features/machines/screens/machine_list_screen.dart` (component, request-response)

**Source:** RESEARCH.md `## Architecture Patterns > System Architecture Diagram` + UI-SPEC.md `## Screen 1`

**Imports pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/machines_provider.dart';
import '../widgets/machine_list_tile.dart';
```

**ConsumerWidget pattern:**
```dart
class MachineListScreen extends ConsumerWidget {
  const MachineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machinesAsync = ref.watch(machineRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machines'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      body: machinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (machines) => machines.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                itemCount: machines.length,
                itemBuilder: (context, i) => MachineListTile(
                  machine: machines[i],
                  onTap: () => context.push('/machines/${machines[i].id}/terminal'),
                  onEdit: () => context.push('/machines/${machines[i].id}/edit'),
                  onDelete: () => _confirmDelete(context, ref, machines[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/machines/add'),
        tooltip: 'Add Machine',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- `ConsumerWidget` is the Riverpod equivalent of `StatelessWidget` — provides `WidgetRef ref`
- `machinesAsync.when(loading, error, data)` is the standard AsyncValue pattern
- Navigation via `context.push()` from go_router extension on `BuildContext`

---

### `lib/features/machines/screens/add_edit_machine_screen.dart` (component, CRUD)

**Source:** UI-SPEC.md `## Screen 2` + RESEARCH.md `## Architecture Patterns`

**Imports pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/machines_provider.dart';
import '../../../core/models/machine.dart';
```

**ConsumerStatefulWidget pattern (form needs local state for controllers):**
```dart
class AddEditMachineScreen extends ConsumerStatefulWidget {
  final String? machineId; // null = add mode, non-null = edit mode

  const AddEditMachineScreen({super.key, this.machineId});

  @override
  ConsumerState<AddEditMachineScreen> createState() => _AddEditMachineScreenState();
}

class _AddEditMachineScreenState extends ConsumerState<AddEditMachineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // build Machine + call repo.save()
  }
}
```

- Use `ConsumerStatefulWidget` + `ConsumerState` (not `StatefulWidget` + `State`) so `ref` is available in state
- `TextEditingController` requires manual `dispose()` — always in `ConsumerState.dispose()`
- Password field: `obscureText: _obscurePassword`, toggle via `setState(() => _obscurePassword = !_obscurePassword)`

---

### `lib/features/machines/widgets/machine_list_tile.dart` (component, request-response)

**Source:** UI-SPEC.md `## Screen 1 > Machine list item`

**Core widget pattern:**
```dart
import 'package:flutter/material.dart';
import '../../../core/models/machine.dart';

class MachineListTile extends StatelessWidget {
  final Machine machine;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MachineListTile({
    super.key,
    required this.machine,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(machine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => /* show AlertDialog confirmation */ true,
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey, // status dot — color driven by connection state
          ),
        ),
        title: Text(machine.name),
        subtitle: Text('${machine.username}@${machine.host}:${machine.port}',
            style: Theme.of(context).textTheme.bodySmall),
        onTap: onTap,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
```

---

### `lib/features/terminal/providers/ssh_session_provider.dart` (provider, streaming)

**Source:** RESEARCH.md `## Architecture Patterns > Pattern 1` and `## Code Examples > SSH Session Provider (Complete)`

This is the most complex file in Phase 1 and the canonical reference is the xterm.dart official SSH example at `github.com/TerminalStudio/xterm.dart/blob/master/example/lib/ssh.dart`.

**Imports pattern:**
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xterm/xterm.dart';
import '../../machines/providers/machines_provider.dart';

part 'ssh_session_provider.g.dart';
```

**Core AsyncNotifier.autoDispose.family pattern:**
```dart
@riverpod
class SshSession extends _$SshSession {
  SSHClient? _client;
  SSHSession? _session; // dartssh2 SSHSession — different from Riverpod

  @override
  Future<Terminal> build(String machineId) async {
    ref.onDispose(() {
      _session?.close();
      _client?.close();
    });

    final machine = ref.read(machineRepositoryProvider.notifier).get(machineId);
    final password = await ref.read(machineRepositoryProvider.notifier).getPassword(machineId);

    _client = SSHClient(
      await SSHSocket.connect(machine!.host, machine.port),
      username: machine.username,
      onPasswordRequest: () => password ?? '',
    );

    // Guard transport close — prevents unhandled SSHStateError crash
    _client!.done.catchError((e) {
      if (mounted) state = AsyncError(e, StackTrace.current);
    });

    final terminal = Terminal(maxLines: 2000);

    _session = await _client!.shell(
      pty: const SSHPtyConfig(type: 'xterm-256color', width: 80, height: 24),
      environment: {'TERM': 'xterm-256color', 'LANG': 'en_US.UTF-8'},
    );

    // Wire stdout + stderr → terminal model (ANSI rendering)
    _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    _session!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    // Wire terminal keyboard output → SSH stdin
    terminal.onOutput = (data) => _session?.write(utf8.encode(data));

    return terminal;
  }

  void sendText(String text) => _session?.write(utf8.encode(text));
  void sendBytes(List<int> bytes) => _session?.write(Uint8List.fromList(bytes));
  void resizeTerminal(int cols, int rows) => _session?.resizeTerminal(cols, rows, 0, 0);
}
```

**Critical details:**
- `@riverpod` on a class with a `String` parameter generates `.autoDispose.family` — the provider is keyed by `machineId` and disposed when the terminal screen is popped
- `_client!.done.catchError(...)` MUST be called at connection time — without it, network drops produce uncaught `SSHStateError` crashes
- PTY type MUST be `'xterm-256color'` — without it, Claude Code outputs no colors
- `allowMalformed: true` in `Utf8Decoder` prevents crashes on partial multi-byte sequences from the stream

---

### `lib/features/terminal/screens/terminal_screen.dart` (component, streaming)

**Source:** RESEARCH.md `## Architecture Patterns > System Architecture Diagram` + UI-SPEC.md `## Screen 3`

**Imports pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ssh_session_provider.dart';
import '../widgets/terminal_view_wrapper.dart';
import '../widgets/input_bar.dart';
import '../../../core/models/machine.dart';
import '../../machines/providers/machines_provider.dart';
```

**ConsumerWidget with AsyncValue.when pattern:**
```dart
class TerminalScreen extends ConsumerWidget {
  final String machineId;
  const TerminalScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sshSessionProvider(machineId));
    final machine = ref.watch(machineRepositoryProvider).valueOrNull
        ?.firstWhere((m) => m.id == machineId);

    return MediaQuery(
      // Clamp textScaleFactor to prevent terminal layout overflow
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.3),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(machine?.name ?? 'Terminal'),
              Text(
                sessionAsync.when(
                  loading: () => 'Connecting…',
                  error: (e, _) => 'Connection failed',
                  data: (_) => 'Connected',
                ),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Disconnect',
              onPressed: () => context.pop(),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: sessionAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (terminal) => TerminalViewWrapper(
                  machineId: machineId,
                  terminal: terminal,
                ),
              ),
            ),
            InputBar(machineId: machineId),
          ],
        ),
      ),
    );
  }
}
```

- `resizeToAvoidBottomInset: true` causes Scaffold to shrink when keyboard appears — `Expanded(TerminalView)` flexes down, keeping `InputBar` visible
- `ExcludeSemantics` should wrap `TerminalViewWrapper` per UI-SPEC accessibility requirements
- Error state should also show a `SnackBar` with the message from UI-SPEC copywriting

---

### `lib/features/terminal/widgets/terminal_view_wrapper.dart` (component, streaming)

**Source:** RESEARCH.md `## Architecture Patterns > Pattern 2: TerminalView with LayoutBuilder Resize Wiring`

**Imports pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../providers/ssh_session_provider.dart';
import '../../../core/theme/app_theme.dart';
```

**LayoutBuilder + TerminalView pattern:**
```dart
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
        final cols = (constraints.maxWidth / 8).floor().clamp(40, 220);
        final rows = (constraints.maxHeight / 16).floor().clamp(10, 60);

        // Use addPostFrameCallback to avoid calling session during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sshSessionProvider(machineId).notifier)
              .resizeTerminal(cols, rows);
        });

        return ExcludeSemantics(
          child: TerminalView(
            terminal,
            theme: AppTheme.terminalTheme,
            autofocus: false, // InputBar TextField owns focus
          ),
        );
      },
    );
  }
}
```

- `addPostFrameCallback` is mandatory — calling `resizeTerminal` during `build` causes setState-during-build errors
- `autofocus: false` on `TerminalView` — the InputBar's TextField owns keyboard focus
- `ExcludeSemantics` wraps the terminal per UI-SPEC accessibility requirements (raw terminal output is noise for screen readers)
- PTY dimension formula: `cols = width ~/ 8`, `rows = height ~/ 16` (matches xterm.dart monospace cell size approximation)

---

### `lib/features/terminal/widgets/input_bar.dart` (component, event-driven)

**Source:** RESEARCH.md `## Code Examples > InputBar Widget Skeleton` + UI-SPEC.md `## Screen 3 > InputBar`

**Imports pattern:**
```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ssh_session_provider.dart';
```

**Control signal constants + ConsumerStatefulWidget pattern:**
```dart
// Control signal byte constants — raw bytes sent directly to SSH stdin
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(sshSessionProvider(widget.machineId).notifier)
        .sendText('$text\n');
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sshSessionProvider(widget.machineId));
    final isConnected = sessionAsync.hasValue;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        ? () => ref.read(
                            sshSessionProvider(widget.machineId).notifier)
                            .sendBytes(bytes)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
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
              Semantics(
                label: 'Send',
                child: IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: isConnected ? _send : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- Use `ConsumerStatefulWidget` + `ConsumerState` (not `StatefulWidget`) for access to `ref`
- `sessionAsync.hasValue` disables chips and send button when not connected — satisfies SSH-02 InputBar disabled state
- `onSubmitted: (_) => isConnected ? _send() : null` — same handler as send button, satisfies INP-01
- Send `text + '\n'` (newline required to submit command to shell)

---

## Shared Patterns

### Riverpod Widget Base Classes

**Apply to:** All screens and widgets that read providers

| Situation | Widget Base Class |
|-----------|-------------------|
| No local state needed, reads providers | `ConsumerWidget` (replaces `StatelessWidget`) |
| Local state needed AND reads providers | `ConsumerStatefulWidget` + `ConsumerState` |
| Local state only, no providers | `StatefulWidget` + `State` |

```dart
// ConsumerWidget — most common pattern
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(someProvider);
    // ...
  }
}

// ConsumerStatefulWidget — use for forms and widgets with TextEditingController
class MyForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyForm> createState() => _MyFormState();
}

class _MyFormState extends ConsumerState<MyForm> {
  // ref available directly (not in build signature)
}
```

### AsyncValue Handling

**Apply to:** All ConsumerWidget builds that watch an `AsyncNotifier`

```dart
// Standard when() pattern — always handle all three states
someAsyncProvider.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, stack) => Center(child: Text('Error: $e')),
  data: (value) => /* render with value */,
);

// Check if connected without switching — for enabling/disabling UI
final isConnected = ref.watch(someAsyncProvider).hasValue;
```

### go_router Navigation

**Apply to:** All screen navigations

```dart
// Push (adds to stack — use for drill-down)
context.push('/machines/add');
context.push('/machines/${machine.id}/terminal');

// Pop (returns — use in AppBar back/close buttons)
context.pop();

// Named parameters in routes
GoRoute(
  path: ':id/terminal',
  builder: (context, state) => TerminalScreen(
    machineId: state.pathParameters['id']!,  // non-null assertion safe after path match
  ),
),
```

### Riverpod Code Generation

**Apply to:** All `@riverpod`-annotated provider files

Every file with `@riverpod` needs:
1. `part 'filename.g.dart';` directive at the top
2. Run `flutter pub run build_runner build --delete-conflicting-outputs` to generate `.g.dart`
3. The generated file must be committed (it is not a build artifact — it changes infrequently)

### Error Handling for SSH Transport

**Apply to:** `ssh_session_provider.dart` — the only file that touches SSHClient

```dart
// Guard client.done — prevents uncaught SSHStateError on network drop
_client!.done.catchError((e) {
  if (mounted) state = AsyncError(e, StackTrace.current);
});

// All close calls should be in onDispose — never await them without try-catch
ref.onDispose(() {
  _session?.close();  // null-safe — no throw if already closed
  _client?.close();   // null-safe — no throw if already closed
});
```

---

## No Analog Found

All files are new (greenfield project). No existing codebase analogs. The patterns above ARE the founding analogs for this project.

---

## Metadata

**Analog search scope:** entire repository (`/home/cristian/Documentos/GitHub/claude-pilot`)
**Files scanned:** 3 (CLAUDE.md, README.md, SPEC.md — no Dart source files exist)
**Greenfield:** true — this phase establishes all project patterns
**Pattern sources:**
- RESEARCH.md code examples (derived from xterm.dart official SSH example + Riverpod docs)
- CONTEXT.md locked implementation decisions
- UI-SPEC.md visual and interaction contract
- Official package documentation referenced in RESEARCH.md
**Pattern extraction date:** 2026-06-19
