---
phase: 06-session-start-picker
verified: 2026-06-20T23:45:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification: null
human_verification:
  - test: "Connect to a machine with configured folder paths and verify picker sheet appears once"
    expected: "After SSH connects (SshConnected state), a non-dismissible bottom sheet appears listing all configured folder paths and a 'Start blank' option"
    why_human: "Modal bottom sheet display and session lifecycle require a running device/emulator with an SSH server to exercise the showModalBottomSheet trigger path"
  - test: "Tap a folder in the picker sheet and verify terminal reflects cd command"
    expected: "Sheet closes immediately, terminal input line shows 'cd /path/to/folder' was sent, and the shell prompt changes to that directory"
    why_human: "Requires live SSH session to verify sendText('cd $path\\n') is received by the shell and reflected in terminal output"
  - test: "Tap 'Start blank' and verify no cd command is sent"
    expected: "Sheet closes, terminal shows default shell prompt with no preceding cd command, session starts in home/default directory"
    why_human: "Requires live SSH session to confirm absence of a cd command being sent"
  - test: "Connect to a machine with NO configured folder paths and verify picker never appears"
    expected: "SSH connects directly to terminal with no bottom sheet appearing at any point"
    why_human: "Requires a running device to confirm showModalBottomSheet is not called; cannot be verified by static analysis"
  - test: "Disconnect mid-session and allow auto-reconnect — verify picker does NOT reappear"
    expected: "After SshReconnecting -> SshConnected transition, no picker sheet is shown; the terminal continues from where it left off"
    why_human: "Requires live SSH session to simulate mid-session drop and reconnect to observe the _pickerShown guard behavior"
  - test: "Exhaust all auto-retries (SshFailed), then tap manual Retry — verify picker DOES reappear"
    expected: "After _pickerShown is reset on SshFailed and reconnect() succeeds, the picker sheet appears again for the new shell session"
    why_human: "Requires triggering the full reconnect failure lifecycle on a device to verify the _pickerShown=false reset and subsequent re-show"
  - test: "Add folders to a machine in the edit screen, save, close app, reopen — verify folders persist"
    expected: "After app cold restart, editing the same machine shows the same folder paths in the same order as before the restart"
    why_human: "Requires device persistence verification across app restarts; shared_preferences writes cannot be confirmed via static analysis alone"
  - test: "Reorder folder paths using drag handle and verify new order is saved"
    expected: "After dragging a path from position 2 to position 1 and tapping Save, reopening the edit screen shows the updated order"
    why_human: "Requires interaction with ReorderableListView drag gesture on a device"
---

# Phase 06: Session Start Picker — Verification Report

**Phase Goal:** Users can land in the right project directory immediately after connecting — no manual `cd` required
**Verified:** 2026-06-20T23:45:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | When editing a machine, the user can add, reorder, and delete a list of working folder paths that are saved per machine | VERIFIED | `ReorderableListView` with delete, `_addFolderPath()` helper, `folderPaths: _folderPaths` in `_save()`, `_folderPaths = List<String>.from(machine.folderPaths)` in load — all present in `add_edit_machine_screen.dart` |
| 2 | After an SSH session connects, a picker sheet appears showing configured folders; tapping a folder closes the sheet and terminal reflects the `cd <path>` command | VERIFIED (automated portion) | `ref.listen` trigger with `_pickerShown` guard → `showModalBottomSheet` → `SessionPickerSheet` → `onFolderSelected` → `sendText('cd $path\n')` — full chain present in `terminal_screen.dart` lines 83–109; `Navigator.of(context).pop()` before callback in `session_picker_sheet.dart` line 88-89 |
| 3 | The user can dismiss the picker with a "Start blank" option to enter the session without any `cd` command | VERIFIED (automated portion) | `TextButton('Start blank')` with `onPressed: () => Navigator.of(context).pop()` at line 114 in `session_picker_sheet.dart` — pops sheet only, no sendText call |
| 4 | If a machine has no configured folders, the session starts in blank mode directly — picker sheet never appears | VERIFIED | `if (paths != null && paths.isNotEmpty)` guard at line 89 in `terminal_screen.dart` prevents `showModalBottomSheet` from being called; `folderPaths` defaults to `const []` in `Machine` model |

**Score:** 4/4 truths have automated-evidence support. Full pass requires human verification of runtime behavior (items above cannot be confirmed by static analysis alone).

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/core/models/machine.dart` | Machine model with `folderPaths` field, backward-compatible `fromJson`/`toJson`, `copyWith`, `generate()` | VERIFIED | All 8 `folderPaths` occurrences present: field decl, constructor default, `generate()` param, `generate()` body, `copyWith()` param, `copyWith()` body, `fromJson` backward-compat cast, `toJson` entry |
| `lib/features/machines/screens/add_edit_machine_screen.dart` | Component A folder path editor (ReorderableListView, add field, delete, empty state) | VERIFIED | `ReorderableListView` present; `shrinkWrap: true`; `NeverScrollableScrollPhysics()`; `ValueKey('folder_$i')`; empty state text; `_folderPathCtrl`; `_addFolderPath()` helper; 10 `_folderPaths` references |
| `lib/features/terminal/widgets/session_picker_sheet.dart` | StatelessWidget with folder list, `onFolderSelected` callback, "Start blank" button, no Riverpod | VERIFIED | `class SessionPickerSheet extends StatelessWidget`; `void Function(String path) onFolderSelected`; 2x `Navigator.of(context).pop()`; `onFolderSelected(folderPaths[index])`; `'Start blank'`; no `flutter_riverpod` import |
| `lib/features/terminal/screens/terminal_screen.dart` | `ConsumerStatefulWidget` conversion; `_pickerShown` guard; picker trigger in `ref.listen`; `session_picker_sheet.dart` import | VERIFIED | `class TerminalScreen extends ConsumerStatefulWidget`; `class _TerminalScreenState extends ConsumerState<TerminalScreen>`; `bool _pickerShown = false`; 12x `widget.machineId`; `addPostFrameCallback`; `isDismissible: false`; `enableDrag: false`; import present; `_ConnectingDot` unchanged |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `add_edit_machine_screen.dart` | `machine.dart` | `folderPaths: _folderPaths` in `_save()` | VERIFIED | Exact match at line 73 |
| `machine.dart` | shared_preferences via MachineRepository | `toJson()` / `fromJson()` with `'folderPaths'` key | VERIFIED | `'folderPaths': folderPaths` in `toJson()` line 69; backward-compat `fromJson` at line 60 |
| `terminal_screen.dart` | `session_picker_sheet.dart` | `showModalBottomSheet` builder → `SessionPickerSheet(...)` | VERIFIED | `import '../widgets/session_picker_sheet.dart'` at line 13; `SessionPickerSheet(folderPaths: paths, onFolderSelected: ...)` at lines 98–105 |
| `terminal_screen.dart` | `ssh_session_provider.dart` `sendText()` | `onFolderSelected` callback → `ref.read(sshSessionProvider(...).notifier).sendText('cd $path\n')` | VERIFIED | Lines 100–104 in `terminal_screen.dart` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `session_picker_sheet.dart` | `folderPaths` (constructor prop) | `machine.folderPaths` from `MachineRepository` (shared_preferences) | Yes — populated from `_folderPaths` state loaded in `_loadExistingMachine()` and persisted via `_save()` | FLOWING |
| `add_edit_machine_screen.dart` | `_folderPaths` | `machine.folderPaths` via `List<String>.from(machine.folderPaths)` in `_loadExistingMachine()` | Yes — reads from deserialized Machine model | FLOWING |
| `terminal_screen.dart` | `paths` | `pickerMachine?.folderPaths` via type-safe `.where().firstOrNull` lookup on `machineProvider` | Yes — reads from live Riverpod provider backed by shared_preferences | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — requires a running device with SSH server. All behaviors involve modal bottom sheets and SSH shell stdin which cannot be tested with a single static command.

`flutter analyze .` was run as a project-wide compilation correctness check:

| Check | Command | Result | Status |
|-------|---------|--------|--------|
| Project-wide static analysis | `/home/cristian/.local/share/mise/installs/flutter/latest/bin/flutter analyze .` | No issues found (ran in 1.8s) | PASS |

---

### Probe Execution

No probes declared or found under `scripts/*/tests/probe-*.sh`. Phase produces Flutter UI, not a CLI/migration script. Step 7c: SKIPPED (no applicable probes).

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PICK-01 | 06-02-PLAN.md | Al iniciar sesión con carpetas configuradas, usuario puede elegir entre sesión en blanco o cargar un proyecto | SATISFIED (automated) | `_pickerShown` guard + `showModalBottomSheet` + `SessionPickerSheet` + `'Start blank'` button — full path present; runtime confirmation needs human |
| PICK-02 | 06-01-PLAN.md | Usuario puede configurar lista de rutas de carpetas por máquina en pantalla de edición | SATISFIED | `ReorderableListView` add/reorder/delete wired to `_folderPaths` → `Machine.folderPaths` → `toJson` → shared_preferences; full chain verified |
| PICK-03 | 06-02-PLAN.md | Al seleccionar un proyecto, la sesión envía automáticamente `cd <ruta>` | SATISFIED (automated) | `sendText('cd $path\n')` in `onFolderSelected` callback at `terminal_screen.dart:103` — `\n` appended as required |
| PICK-04 | 06-02-PLAN.md | Si no hay carpetas configuradas, sesión inicia en blanco sin picker | SATISFIED | `if (paths != null && paths.isNotEmpty)` guard prevents `showModalBottomSheet` call; `Machine.folderPaths` defaults to `const []` |

**Note:** `REQUIREMENTS.md` traceability table still shows all four PICK IDs as `Pending` — this is a documentation state issue only. The implementations are verified in code. The checkboxes at lines 77–80 and the traceability table at lines 135–138 should be updated to reflect completion.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `add_edit_machine_screen.dart` | 126 | `_loadExistingMachine()` called directly from `build()` | Info | Side-effectful call in build method; `_loaded` guard makes it idempotent; flagged as IN-01 in code review; not a blocker for goal achievement |
| `add_edit_machine_screen.dart` | 115–122 | `_addFolderPath()` allows silent duplicate paths | Info | UX defect — duplicate entries appear in both the editor and the picker sheet; flagged as IN-02 in code review; not a functional blocker |
| `session_picker_sheet.dart` | 16–20 | No `assert(folderPaths.isNotEmpty)` guard in constructor | Info | If called with empty list, sheet renders with only "Start blank" visible; caller contract enforced by `terminal_screen.dart` guard; flagged as IN-03 in code review |

**Resolved review findings (WR-02, WR-03):** Both were addressed in commit `aea5dc3`:
- WR-02: `_pickerShown = false` reset added on `SshFailed` transition so manual reconnect after exhausting auto-retries shows the picker again
- WR-03: `cast<dynamic>().firstWhere(orElse)` replaced with type-safe `.where().firstOrNull` throughout `terminal_screen.dart`

**Unresolved review findings (WR-01, WR-04):**
- WR-01: Password validator requires non-empty value in edit mode even when async load hasn't completed — could cause false "Required" error on fast taps; pre-existing issue not introduced by phase 06
- WR-04: Index-based `ValueKey('folder_$i')` may cause unstable drag animation in some Flutter versions per `ReorderableListView` documentation — review recommends stable content-based keys; design decision documented in SUMMARY (index-based chosen to handle duplicates)

These are carryover warnings from the code review; they do not block the phase goal.

---

### Human Verification Required

#### 1. Picker appears on connect with configured folders

**Test:** Connect to a machine that has at least one configured folder path. Watch the screen after SSH connection succeeds.
**Expected:** A non-dismissible bottom sheet slides up showing the configured folder paths and a "Start blank" option. Back gesture and barrier tap do NOT dismiss it.
**Why human:** `showModalBottomSheet` display and the `SshConnected` state transition require a running device with an SSH server.

#### 2. Folder tap sends cd command and closes sheet

**Test:** In the picker sheet, tap one of the folder rows.
**Expected:** The sheet closes immediately, and the terminal shows `cd /the/selected/path` was sent (visible in terminal output or shell prompt changes to that directory).
**Why human:** Requires live SSH session to verify `sendText('cd $path\n')` is received and executed by the shell.

#### 3. "Start blank" sends no command

**Test:** In the picker sheet, tap "Start blank."
**Expected:** The sheet closes, the terminal shows the default shell prompt with no preceding `cd` command. Working directory is the default SSH login directory.
**Why human:** Requires live SSH session to confirm absence of a cd command.

#### 4. No picker when machine has no configured folders

**Test:** Connect to a machine with an empty folder path list (no folders configured in the edit screen).
**Expected:** SSH connects directly to blank terminal session with no bottom sheet appearing at any point during or after connection.
**Why human:** Requires a running device to observe that `showModalBottomSheet` is never called.

#### 5. Picker does NOT reappear after mid-session reconnect

**Test:** Connect to a machine with folders, select a folder (or Start blank). Simulate a mid-session SSH drop and allow auto-reconnect to succeed (SshReconnecting → SshConnected).
**Expected:** No picker sheet appears after the mid-session reconnect. The terminal continues from the previous state.
**Why human:** Requires controlled SSH drop to exercise the `_pickerShown` guard on mid-session reconnect path.

#### 6. Picker DOES reappear after manual retry following SshFailed

**Test:** Connect to a machine with folders that fails all 5 auto-retries (SshFailed state). Tap the manual Retry button.
**Expected:** If reconnect succeeds (SshConnected), the picker sheet appears again because `_pickerShown` was reset to `false` on `SshFailed`.
**Why human:** Requires triggering the full retry exhaustion lifecycle on a device.

#### 7. Folder paths persist across app restarts

**Test:** Add multiple folder paths to a machine, save, force-close the app, reopen and navigate to that machine's edit screen.
**Expected:** All folder paths are present in the same order as when saved.
**Why human:** Requires device cold-restart to verify shared_preferences persistence survives process termination.

#### 8. Reorder persists after save

**Test:** In the edit screen, drag a folder path from one position to another using the drag handle, then tap Save Machine. Reopen the edit screen.
**Expected:** The folder paths appear in the new order established by the drag operation.
**Why human:** Requires interaction with ReorderableListView drag gesture on a physical device or emulator.

---

## Gaps Summary

No automated gaps found. All 4 observable truths have static evidence. All artifacts exist, are substantive, are wired, and data flows end-to-end through the chain.

The 8 human verification items above are required to confirm the runtime behavior of this phase. They cover the complete PICK-01..04 requirement set from the user's perspective on a device.

**REQUIREMENTS.md documentation state:** The traceability table at lines 135–138 and the checkbox list at lines 77–80 still show PICK-01..04 as Pending. This should be updated as a documentation task after human verification passes.

---

_Verified: 2026-06-20T23:45:00Z_
_Verifier: Claude (gsd-verifier)_
