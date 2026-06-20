---
phase: 06-session-start-picker
plan: 01
subsystem: ui
tags: [flutter, riverpod, shared_preferences, machine_model, folder_paths, reorderable_list]

# Dependency graph
requires:
  - phase: 01-machine-management
    provides: Machine model, AddEditMachineScreen, MachineRepository with shared_preferences serialization
provides:
  - Machine.folderPaths field with backward-compatible fromJson/toJson
  - Component A folder path editor in AddEditMachineScreen (add, reorder, delete)
  - folderPaths persisted inside machines_v1 shared_preferences key
affects:
  - 06-02 session-start-picker plan 02 (picker sheet uses machine.folderPaths as source list)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ReorderableListView with shrinkWrap: true + NeverScrollableScrollPhysics inside SingleChildScrollView"
    - "Index-based ValueKey('folder_$i') for duplicate-safe reorder keys"
    - "Backward-compatible fromJson: (json['key'] as List<dynamic>?)?.cast<String>() ?? const []"

key-files:
  created: []
  modified:
    - lib/core/models/machine.dart
    - lib/features/machines/screens/add_edit_machine_screen.dart

key-decisions:
  - "folderPaths uses optional constructor param (no required) so existing Machine() call sites need no update"
  - "Index-based ValueKey('folder_$i') chosen over ValueKey(path) to handle duplicate paths without crashing"
  - "ReorderableListView embedded with shrinkWrap+NeverScrollableScrollPhysics to avoid unbounded height error inside SingleChildScrollView"

patterns-established:
  - "Backward-compat List fromJson: (json['key'] as List<dynamic>?)?.cast<String>() ?? const []"
  - "Embedded ReorderableListView pattern: shrinkWrap: true + NeverScrollableScrollPhysics() + parent SingleChildScrollView"

requirements-completed:
  - PICK-02

# Metrics
duration: 8min
completed: 2026-06-20
---

# Phase 06 Plan 01: Machine folderPaths model and Component A folder editor

**Machine model extended with backward-compatible folderPaths field; AddEditMachineScreen gains a full folder path editor (add/reorder/delete) wired to Machine serialization in shared_preferences**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-20T23:00:00Z
- **Completed:** 2026-06-20T23:08:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Machine model gains `folderPaths: List<String>` with backward-compatible fromJson (existing machines without the key default to `[]` without error)
- AddEditMachineScreen gains Component A: section header, empty state, ReorderableListView with drag-to-reorder and per-item delete, add-path row with TextFormField + add button
- folderPaths persisted automatically through existing MachineRepository serialization (toJson/fromJson) with no repository changes needed
- Full project `flutter analyze` passes with no issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend Machine model with folderPaths** - `658b8f6` (feat)
2. **Task 2: Add Component A folder editor to AddEditMachineScreen** - `411a437` (feat)

**Plan metadata:** (docs commit follows this summary)

## Files Created/Modified

- `lib/core/models/machine.dart` - Added folderPaths field, updated constructor, generate(), copyWith(), fromJson (backward-compat), toJson
- `lib/features/machines/screens/add_edit_machine_screen.dart` - Added _folderPathCtrl, _folderPaths state, _addFolderPath() helper, Component A folder editor section between Password field and Save button

## Decisions Made

- `folderPaths` uses optional constructor parameter (no `required`) so all existing `Machine(...)` call sites compile without changes
- Index-based `ValueKey('folder_$i')` chosen over `ValueKey(path)` to handle duplicate paths without key collision crash
- `ReorderableListView` embedded with `shrinkWrap: true` + `NeverScrollableScrollPhysics()` inside the parent `SingleChildScrollView` — required pattern to avoid unbounded height assertion error

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Flutter binary not on PATH in shell; resolved using mise-managed binary at `/home/cristian/.local/share/mise/installs/flutter/latest/bin/flutter`. No code change needed.

## Known Stubs

None — folderPaths is fully wired: loaded from machine in _loadExistingMachine(), saved via Machine constructor in _save(), persisted through existing MachineRepository serialization.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 (session start picker sheet) can now read `machine.folderPaths` as its source list for the session type picker
- folderPaths field and Component A editor are stable; no changes expected to these files in Plan 02
- No blockers

---
*Phase: 06-session-start-picker*
*Completed: 2026-06-20*
