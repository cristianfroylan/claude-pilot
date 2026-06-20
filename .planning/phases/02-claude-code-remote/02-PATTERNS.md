# Phase 2: Claude Code Remote - Pattern Map

**Mapped:** 2026-06-19
**Files analyzed:** 7
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/terminal/widgets/input_bar.dart` | widget | event-driven | `lib/features/terminal/widgets/input_bar.dart` (self) | self — extend in place |
| `lib/features/terminal/providers/ssh_session_provider.dart` | provider (AsyncNotifier) | streaming | `lib/features/terminal/providers/ssh_session_provider.dart` (self) | self — add StreamController |
| `lib/features/terminal/widgets/permission_card.dart` | widget | event-driven | `lib/features/machines/widgets/machine_list_tile.dart` | role-match (ConsumerWidget with FilledButton/OutlinedButton actions) |
| `lib/features/terminal/providers/permission_detector_provider.dart` | provider (StreamNotifier) | streaming | `lib/features/machines/providers/machines_provider.dart` | role-match (@riverpod class pattern) |
| `lib/features/terminal/models/permission_detector.dart` | model/constants | — | `lib/features/terminal/widgets/input_bar.dart` (const `_commands` pattern) | role-match (top-level const declarations) |
| `android/app/src/main/AndroidManifest.xml` | config | — | `android/app/src/main/AndroidManifest.xml` (self) | self — add nodes to existing structure |
| `pubspec.yaml` | config | — | `pubspec.yaml` (self) | self — add one dependency |

Note: `lib/features/terminal/widgets/voice_bottom_sheet.dart` (NEW) is also required per RESEARCH.md architecture.

| `lib/features/terminal/widgets/voice_bottom_sheet.dart` | widget | request-response | `lib/features/machines/screens/add_edit_machine_screen.dart` | role-match (modal with FilledButton + TextButton confirm/cancel) |

---

## Pattern Assignments

### `lib/features/terminal/widgets/input_bar.dart` (MODIFY — widget, event-driven)

**Analog:** Self — the file being extended.

**Current imports block** (lines 1–4 of existing file):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ssh_session_provider.dart';
```
Add `speech_to_text` import here after the package is added to pubspec:
```dart
import 'package:speech_to_text/speech_to_text.dart';
```

**ConsumerStatefulWidget pattern** (lines 28–34 of existing file):
```dart
class InputBar extends ConsumerStatefulWidget {
  final String machineId;
  const InputBar({super.key, required this.machineId});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}
```
This is the correct widget base class for InputBar — `ConsumerStatefulWidget` because it needs `_commandsVisible` bool state AND Riverpod access. New `_voiceAvailable` bool follows the exact same pattern as `_commandsVisible`.

**Existing state field and toggle pattern** (lines 37–38, 98–99):
```dart
bool _commandsVisible = false;
// ...
setState(() => _commandsVisible = !_commandsVisible)
```
New voice state field follows the same declaration and `setState` update pattern:
```dart
bool _voiceAvailable = false;
// set in initState via _initSpeech()
```

**`isConnected` guard pattern** (lines 41–42, 45–49):
```dart
final isConnected = ref.watch(sshSessionProvider(widget.machineId)).hasValue;
// ...
void send(List<int> bytes) {
  if (!isConnected) return;
  ref.read(sshSessionProvider(widget.machineId).notifier).sendBytes(bytes);
}
```
All new chip `onPressed` callbacks use the same `isConnected` guard. Text commands use `sendText` instead of `sendBytes`:
```dart
onPressed: isConnected
    ? () => ref
          .read(sshSessionProvider(widget.machineId).notifier)
          .sendText('/clear\n')
    : null,
```

**Existing chip rendering pattern** (lines 77–84):
```dart
for (final cmd in _commands)
  ActionChip(
    label: Text(cmd.label, style: const TextStyle(fontSize: 12)),
    onPressed: isConnected ? () => sendAndClose(cmd.bytes) : null,
  ),
```
New text-command sections use the same `ActionChip` style with the same `fontSize: 12`. Section headers slot in as plain `Text` widgets with `fontWeight: FontWeight.w400` and `colorScheme.onSurfaceVariant`.

**Expandable panel container pattern** (lines 69–86):
```dart
if (_commandsVisible)
  Container(
    color: colorScheme.surfaceContainerHighest,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [ /* chips */ ],
    ),
  ),
```
The new sectioned panel is this same `Container → Wrap` structure. Section headers are interleaved `Text` children inside the `Wrap`. Making the `Wrap` scrollable: wrap in `SingleChildScrollView` with a capped `maxHeight` constraint.

**Main bar Row layout** (lines 92–125):
```dart
Row(
  children: [
    // Command toggle   [existing]
    TextButton.icon(...),
    const Spacer(),
    // Arrow keys       [existing — stays here]
    arrowBtn(Icons.arrow_back,    _arrowLeft),
    arrowBtn(Icons.arrow_upward,  _arrowUp),
    arrowBtn(Icons.arrow_downward,_arrowDown),
    arrowBtn(Icons.arrow_forward, _arrowRight),
  ],
)
```
Insert mic `IconButton` between `Spacer()` and the first `arrowBtn`. The mic button is a simple `IconButton` (not `arrowBtn` helper — different size semantics):
```dart
if (_voiceAvailable)
  IconButton(
    icon: const Icon(Icons.mic),
    onPressed: isConnected ? _launchVoiceRecognition : null,
  ),
```

**initState + dispose lifecycle** — new pattern needed. Follow `_ConnectingDotState` in `terminal_screen.dart` (lines 160–177) as the initState/dispose template:
```dart
@override
void initState() {
  super.initState();
  _initSpeech();       // async, safe — sets state only if mounted
}

@override
void dispose() {
  _speech.cancel();    // required by speech_to_text
  super.dispose();
}
```

---

### `lib/features/terminal/providers/ssh_session_provider.dart` (MODIFY — provider, streaming)

**Analog:** Self — the file being modified.

**Existing `_connectOnce` method structure** (lines 73–122):

The `safeWrite` local function at lines 103–107 is the exact insertion point:
```dart
void safeWrite(String data) {
  try {
    terminal.write(data);
  } catch (_) {}
}
```
Add `_permissionController.add(data)` as a second line inside this function, after the try/catch:
```dart
void safeWrite(String data) {
  try {
    terminal.write(data);
  } catch (_) {}
  _permissionController.add(data);   // feed all stdout to permission detector
}
```

**Field declaration pattern** (lines 25–32 — existing fields):
```dart
SSHClient? _client;
SSHSession? _sshSession;
bool _disposed = false;
```
New `StreamController` field follows the same nullable-field-at-class-level pattern:
```dart
final _permissionController = StreamController<String>.broadcast();
Stream<String> get permissionStream => _permissionController.stream;
```
Use `broadcast()` because `permissionDetectorProvider` will subscribe after the session is already running, and only one subscriber is expected.

**`ref.onDispose` cleanup pattern** (lines 39–43):
```dart
ref.onDispose(() {
  _disposed = true;
  _sshSession?.close();
  _client?.close();
});
```
Add `_permissionController.close()` here, after `_client?.close()`:
```dart
ref.onDispose(() {
  _disposed = true;
  _sshSession?.close();
  _client?.close();
  _permissionController.close();   // prevent stream leak
});
```

**Public method pattern** (lines 126–137):
```dart
void sendText(String text) => _sshSession?.write(utf8.encode(text));
void sendBytes(List<int> bytes) => _sshSession?.write(Uint8List.fromList(bytes));
void resizeTerminal(int cols, int rows) => _sshSession?.resizeTerminal(cols, rows, 0, 0);
```
`permissionStream` getter follows the same one-liner public API style.

---

### `lib/features/terminal/widgets/permission_card.dart` (CREATE — widget, event-driven)

**Analog:** `lib/features/machines/widgets/machine_list_tile.dart`

**ConsumerWidget import and class pattern** (lines 1–9 of analog):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/machine.dart';
// ...

class MachineListTile extends ConsumerWidget {
  final Machine machine;
  // ...
  const MachineListTile({super.key, required this.machine, ...});
```
`PermissionCard` follows the same `ConsumerWidget` structure with a `machineId` string prop and a `line` string prop (the matched terminal line):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ssh_session_provider.dart';

class PermissionCard extends ConsumerWidget {
  final String machineId;
  final String line;
  const PermissionCard({super.key, required this.machineId, required this.line});
```

**FilledButton + TextButton action pattern** from `terminal_screen.dart` (lines 60–70):
```dart
FilledButton(
  onPressed: () { /* ... */ },
  child: const Text('Review settings'),
),
TextButton(
  onPressed: () => Navigator.of(dialogContext).pop(),
  child: const Text('Not now'),
),
```
`PermissionCard` uses `FilledButton` for Approve and `OutlinedButton` for Reject (per CONTEXT.md):
```dart
FilledButton.icon(
  icon: const Icon(Icons.check),
  label: const Text('Approve'),
  onPressed: () {
    ref.read(sshSessionProvider(machineId).notifier).sendText('y\n');
  },
),
OutlinedButton.icon(
  icon: const Icon(Icons.close),
  label: const Text('Reject'),
  onPressed: () {
    ref.read(sshSessionProvider(machineId).notifier).sendText('n\n');
  },
),
```

**Theme color pattern** (lines 51–63 of analog, colorScheme usage):
```dart
Theme.of(context).colorScheme.error   // for delete/reject actions
Theme.of(context).colorScheme         // always via Theme.of(context), never hardcoded
```

**Card container**: use `Card` widget wrapping a `Padding` with a `Column`. Background color from `colorScheme.surfaceContainerHighest` to match the expandable command panel.

---

### `lib/features/terminal/providers/permission_detector_provider.dart` (CREATE — provider, streaming)

**Analog:** `lib/features/machines/providers/machines_provider.dart` (for `@riverpod` class codegen structure)

**`@riverpod` class codegen pattern** (lines 1–9 of analog):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'machines_provider.g.dart';

@riverpod
class MachineNotifier extends _$MachineNotifier {
  // ...
  @override
  Future<List<Machine>> build() async { ... }
```
`PermissionDetector` follows the exact same `@riverpod class ... extends _$...` pattern. The generated file `permission_detector_provider.g.dart` is the `part` target. Return type is `Stream<String?>` instead of `Future<List<Machine>>`:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ssh_session_provider.dart';
import '../models/permission_detector.dart';

part 'permission_detector_provider.g.dart';

@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) { ... }
```

**`ref.watch` + `sessionAsync.when` pattern** from `terminal_screen.dart` (lines 21–23, 74–78):
```dart
final sessionAsync = ref.watch(sshSessionProvider(machineId));
// ...
sessionAsync.when(
  loading: () => ...,
  error: (_, __) => ...,
  data: (_) => ...,
);
```
In `PermissionDetector.build`, use this same `.when` to gate stream subscription:
```dart
@override
Stream<String?> build(String machineId) {
  final sessionAsync = ref.watch(sshSessionProvider(machineId));
  return sessionAsync.when(
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
    data: (_) {
      final notifier = ref.read(sshSessionProvider(machineId).notifier);
      return notifier.permissionStream.map(_detect);
    },
  );
}
```

**No `ref.onDispose` needed here** — the `StreamController` is owned and closed by `SshSession`. The stream subscription inside `PermissionDetector` is managed by Riverpod's `StreamNotifier` lifecycle automatically.

---

### `lib/features/terminal/models/permission_detector.dart` (CREATE — constants/model)

**Analog:** `lib/features/terminal/widgets/input_bar.dart` top-level const declarations (lines 6–16).

**Top-level const pattern** (lines 6–16 of analog):
```dart
const _arrowLeft  = [0x1b, 0x5b, 0x44];
// ...
const _commands = [
  _Cmd('Interrupt  [Ctrl+C]',  [0x03]),
  // ...
];
```
`permission_detector.dart` uses the same top-level `const` style for the regex string. No class wrapper — just a bare constant:
```dart
/// Regex targeting Claude Code permission prompts.
/// Version-sensitive: Claude Code output format may change across releases.
/// Named kPermissionPattern (k prefix = compile-time constant per Dart convention).
/// Update this constant when Claude Code changes its permission message format.
const kPermissionPattern =
    r'(Do you want to|Allow .+ to|Approve .+|\(y\/n\)|\[y\/n\]|✓ Yes|yes\/no)';
```

No imports needed — this file is purely a constant declaration consumed by `permission_detector_provider.dart`.

---

### `lib/features/terminal/widgets/voice_bottom_sheet.dart` (CREATE — widget, request-response)

**Analog:** `lib/features/machines/screens/add_edit_machine_screen.dart` (modal with confirm/cancel actions). Also pattern-matches `terminal_screen.dart` dialog pattern (lines 46–70).

**ModalBottomSheet stateless widget pattern** — the bottom sheet content is a plain `StatelessWidget` (or `ConsumerWidget` if it needs ref) passed to `showModalBottomSheet`:

```dart
import 'package:flutter/material.dart';

class VoiceBottomSheet extends StatelessWidget {
  final String transcript;
  final VoidCallback onSend;

  const VoiceBottomSheet({
    super.key,
    required this.transcript,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) { ... }
}
```

**FilledButton + TextButton pattern** from `terminal_screen.dart` (lines 59–70):
```dart
FilledButton(
  onPressed: () { /* action */ Navigator.of(ctx).pop(); },
  child: const Text('Send'),
),
TextButton(
  onPressed: () => Navigator.of(ctx).pop(),
  child: const Text('Cancel'),
),
```

**Theme access** — same `Theme.of(context).colorScheme` for all colors. The transcript text uses `Theme.of(context).textTheme.bodyMedium` (same pattern as subtitle in `machine_list_tile.dart` line 91).

**`showModalBottomSheet` call site** — in `_InputBarState._showReviewSheet`:
```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,   // CRITICAL: respects keyboard inset (see Pitfall 4 in RESEARCH.md)
  builder: (_) => VoiceBottomSheet(
    transcript: transcript,
    onSend: () {
      ref.read(sshSessionProvider(widget.machineId).notifier)
          .sendText('$transcript\n');
      Navigator.of(context).pop();
    },
  ),
);
```

---

### `lib/features/terminal/screens/terminal_screen.dart` (MODIFY — screen, event-driven)

**Analog:** Self — the file being modified.

**`ref.watch` for new provider** — follows existing `ref.watch(sshSessionProvider(machineId))` pattern at line 21. Add after it:
```dart
final permissionLine = ref.watch(
  permissionDetectorProvider(machineId),
).valueOrNull;
```
Note: `.valueOrNull` is the Riverpod 3.x equivalent of `.asData?.value`. If not available, use `.when(data: (v) => v, loading: () => null, error: (_, __) => null)`.

**Column child insertion** (lines 126–142 of existing file):
```dart
body: Column(
  children: [
    Expanded(child: sessionAsync.when(...)),   // line 129
    // INSERT AnimatedSwitcher here
    InputBar(machineId: machineId),             // line 141
  ],
),
```
The `AnimatedSwitcher` slot is a direct `Column` child — no `Expanded`, no flexible sizing. It grows/shrinks naturally with card content:
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  child: (permissionLine != null)
    ? PermissionCard(
        key: const ValueKey('permission-card'),
        line: permissionLine,
        machineId: machineId,
      )
    : const SizedBox.shrink(key: ValueKey('no-card')),
),
```

**Import additions** needed at top of file:
```dart
import '../providers/permission_detector_provider.dart';
import '../widgets/permission_card.dart';
```

---

### `android/app/src/main/AndroidManifest.xml` (MODIFY — config)

**Analog:** Self — the file being modified.

**Existing `<uses-permission>` pattern** (line 3):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
Add `RECORD_AUDIO` in the same position (before `<application>`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```
`INTERNET` is already present — do not duplicate it.

**Existing `<queries>` block** (lines 43–48):
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
</queries>
```
Merge the new speech intent into this block — do NOT create a second `<queries>` element (invalid XML):
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

---

### `pubspec.yaml` (MODIFY — config)

**Analog:** Self — the file being modified.

**Existing dependency block** (lines 10–20):
```yaml
dependencies:
  flutter:
    sdk: flutter
  dartssh2: ^2.18.0
  xterm: ^4.0.0
  flutter_riverpod: ^3.3.1
  riverpod_annotation: 4.0.2
  flutter_secure_storage: ^10.3.1
  shared_preferences: ^2.5.5
  go_router: ^17.3.0
```
Add `speech_to_text` using the same caret-version constraint style as other packages. Note: RESEARCH.md flags this as `[ASSUMED]` — planner must include a `checkpoint:human-verify` task before the `flutter pub add` step:
```yaml
  speech_to_text: ^7.4.0
```

---

## Shared Patterns

### `@riverpod` code generation (applies to `permission_detector_provider.dart`)

**Source:** `lib/features/machines/providers/machines_provider.dart` lines 1–14 + `lib/features/terminal/providers/ssh_session_provider.dart` lines 1–11

Pattern: every `@riverpod` class requires:
1. `import 'package:riverpod_annotation/riverpod_annotation.dart';`
2. `part '<filename>.g.dart';`
3. Class named `Foo` extends `_$Foo`
4. `dart run build_runner build --delete-conflicting-outputs` run after file creation

```dart
part 'permission_detector_provider.g.dart';

@riverpod
class PermissionDetector extends _$PermissionDetector {
  @override
  Stream<String?> build(String machineId) { ... }
}
```

### Theme access (applies to all new widgets)

**Source:** `lib/features/terminal/widgets/input_bar.dart` line 43, `lib/features/machines/widgets/machine_list_tile.dart` lines 52, 58

```dart
final colorScheme = Theme.of(context).colorScheme;
// Never use hardcoded Color() values
// Use: colorScheme.primary, colorScheme.error, colorScheme.onSurfaceVariant
//      colorScheme.surfaceContainerHighest, colorScheme.surfaceContainerHigh
```

### `ref.read` for one-shot actions vs `ref.watch` for reactive state

**Source:** `lib/features/terminal/widgets/input_bar.dart` lines 47–50 (read in callback) vs `lib/features/terminal/screens/terminal_screen.dart` line 21 (watch in build)

```dart
// In build() — reactive, rebuilds widget on state change:
final isConnected = ref.watch(sshSessionProvider(widget.machineId)).hasValue;

// In event handlers / callbacks — one-shot, no rebuild needed:
ref.read(sshSessionProvider(widget.machineId).notifier).sendText('y\n');
```

### `ConsumerWidget` vs `ConsumerStatefulWidget` selection

**Source:** All existing files in the codebase.

- Use `ConsumerWidget` when the widget has **no local mutable state** → `permission_card.dart`, `voice_bottom_sheet.dart`, `terminal_view_wrapper.dart`
- Use `ConsumerStatefulWidget` when the widget has **local mutable state** (`bool _commandsVisible`, `bool _voiceAvailable`, `SpeechToText _speech`) → `input_bar.dart` (already established)

### Error and state guard pattern in callbacks

**Source:** `lib/features/terminal/widgets/input_bar.dart` lines 45–50

```dart
void send(List<int> bytes) {
  if (!isConnected) return;    // guard before acting
  ref.read(...).sendBytes(bytes);
}
```
All new `onPressed` callbacks that write to PTY must be `null` when `!isConnected`, not wrapped in runtime guards. Use `onPressed: isConnected ? () => ... : null` — Flutter handles the disabled visual state automatically.

---

## No Analog Found

All files have close analogs in the existing codebase. No files require falling back to RESEARCH.md patterns exclusively — though `permission_detector_provider.dart` (StreamNotifier) uses a pattern not previously instantiated in the codebase and relies on the code examples in RESEARCH.md § Pattern 2 for the `Stream<String?>` return and `.map(_detect)` chain.

---

## Build Step Reminder

After creating `permission_detector_provider.dart` and before any widget references `permissionDetectorProvider`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates `permission_detector_provider.g.dart`. Without it, the compiler reports `'permissionDetectorProvider' isn't defined`.

The same command regenerates `ssh_session_provider.g.dart` if the `SshSession` class signature changes (it does not in this phase — only the body changes).

---

## Metadata

**Analog search scope:** `lib/features/terminal/`, `lib/features/machines/`, `android/app/src/main/`
**Files read:** 10 source files
**Pattern extraction date:** 2026-06-19
