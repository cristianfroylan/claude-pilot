---
phase: 06-session-start-picker
plan: 02
subsystem: ui
tags: [flutter, riverpod, bottom-sheet, consumer-stateful-widget, picker, ssh-session]

# Dependency graph
requires:
  - phase: 06-session-start-picker
    plan: 01
    provides: Machine.folderPaths field (source list for the picker sheet)
provides:
  - SessionPickerSheet StatelessWidget (Component B picker UI)
  - TerminalScreen converted to ConsumerStatefulWidget with _pickerShown guard
  - One-shot post-connect project picker wired to sendText('cd $path\n')
affects:
  - terminal_screen.dart consumers (no API change — widget public interface unchanged)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ConsumerWidget → ConsumerStatefulWidget conversion: _pickerShown bool field on ConsumerState"
    - "One-shot state transition trigger via ref.listen + boolean guard"
    - "addPostFrameCallback wrapping showModalBottomSheet from ref.listen (Pitfall 2 guard)"
    - "Navigator.of(context).pop() before callback in onTap (Pitfall 6 guard)"
    - "Non-dismissible modal: showModalBottomSheet(isDismissible: false, enableDrag: false)"

key-files:
  created:
    - lib/features/terminal/widgets/session_picker_sheet.dart
  modified:
    - lib/features/terminal/screens/terminal_screen.dart

key-decisions:
  - "_pickerShown stays true for ConsumerState lifetime — not reset on reconnect (PICK-01 intent: show once per session open)"
  - "addPostFrameCallback required when calling showModalBottomSheet from ref.listen to avoid setState-during-build assertion"
  - "Navigator.pop() called before onFolderSelected callback — sheet dismisses synchronously before cd command fires"
  - "folderPaths cast as List<String>? from dynamic machine object — null-safe, handles machines with no configured paths"

patterns-established:
  - "One-shot modal trigger pattern: boolean guard on ConsumerState + addPostFrameCallback + mounted check"
  - "ConsumerWidget → ConsumerStatefulWidget when persistent per-widget-instance state is needed"

requirements-completed:
  - PICK-01
  - PICK-03
  - PICK-04

# Metrics
duration: 3m
completed: 2026-06-20
---

# Phase 06 Plan 02: SessionPickerSheet widget and TerminalScreen picker wiring

**SessionPickerSheet created as clean StatelessWidget; TerminalScreen converted to ConsumerStatefulWidget with _pickerShown guard and one-shot post-connect picker trigger via ref.listen**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-06-20T23:10:21Z
- **Completed:** 2026-06-20T23:13:35Z
- **Tasks:** 2
- **Files created:** 1
- **Files modified:** 1

## Accomplishments

- `SessionPickerSheet` StatelessWidget created with folder list, "Start blank" button, non-dismissible by design, semantics labels per row, drag handle matching VoiceBottomSheet exactly
- `TerminalScreen` mechanically converted from `ConsumerWidget` to `ConsumerStatefulWidget`; `_TerminalScreenState extends ConsumerState<TerminalScreen>` holds `_pickerShown = false`
- All `machineId` references in the build method and ref.listen block updated to `widget.machineId` (12 references updated)
- Picker trigger appended inside existing ref.listen block: only fires when `!_pickerShown && nextState is SshConnected`; machine with no folders skips showModalBottomSheet entirely (PICK-04)
- `addPostFrameCallback` wrapping prevents "setState during build" Flutter assertion (Pitfall 2 from RESEARCH.md)
- `mounted` check inside callback handles navigation-away-before-frame edge case
- `sendText('cd $path\n')` includes trailing `\n` as required (sendText does not append it)
- Full project `flutter analyze .` passes with no issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SessionPickerSheet widget** - `c27568f` (feat)
2. **Task 2: Convert TerminalScreen to ConsumerStatefulWidget and wire picker** - `370632f` (feat)

**Plan metadata:** (docs commit follows this summary)

## Files Created/Modified

- `lib/features/terminal/widgets/session_picker_sheet.dart` — NEW: StatelessWidget with folderPaths list, onFolderSelected callback, drag handle, ListView.separated, "Start blank" TextButton, Semantics per row
- `lib/features/terminal/screens/terminal_screen.dart` — MODIFIED: ConsumerWidget → ConsumerStatefulWidget conversion; _pickerShown guard added; picker trigger block appended to ref.listen; session_picker_sheet.dart import added; all machineId → widget.machineId

## Decisions Made

- `_pickerShown` stays `true` for the lifetime of `_TerminalScreenState` — not reset on reconnect. This matches the intent of PICK-01: show picker exactly once per session open, not once per `SshConnected` transition.
- `addPostFrameCallback` required when calling `showModalBottomSheet` from inside `ref.listen`. `ref.listen` fires synchronously during the build phase; deferring to the next frame avoids the Flutter "setState called during build" assertion.
- `Navigator.of(context).pop()` called before `onFolderSelected` callback in the `onTap` handler. Sheet dismisses synchronously first; cd command fires after. This matches VoiceBottomSheet pattern and Pitfall 6 guard from RESEARCH.md.
- `folderPaths` cast via `pickerMachine?.folderPaths as List<String>?` — null-safe; if cast fails or machine has no folderPaths the `if (paths != null && paths.isNotEmpty)` guard prevents showModalBottomSheet from being called (PICK-04).

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — SessionPickerSheet is fully wired: folderPaths sourced from machine.folderPaths (set in Plan 01), onFolderSelected fires sendText('cd $path\n') which is routed to the SSH shell immediately.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. `sendText('cd $path\n')` sends user-owned path strings sourced from local storage (accepted in threat model T-06-02).

## Self-Check

### Files exist
- `lib/features/terminal/widgets/session_picker_sheet.dart` — FOUND
- `lib/features/terminal/screens/terminal_screen.dart` — FOUND (modified)

### Commits exist
- `c27568f` — FOUND (feat(06-02): add SessionPickerSheet widget)
- `370632f` — FOUND (feat(06-02): convert TerminalScreen to ConsumerStatefulWidget and wire picker)

### flutter analyze . — PASSED (no issues)

## Self-Check: PASSED
