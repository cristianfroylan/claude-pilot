---
phase: 07-sesiones-m-ltiples-con-tabs
plan: "02"
subsystem: sessions-ui-layer
tags:
  - flutter
  - riverpod
  - sessions
  - tabs
  - go-router
  - multi-tab
dependency_graph:
  requires:
    - lib/features/sessions/models/session_tab.dart
    - lib/features/sessions/providers/sessions_provider.dart
    - lib/features/terminal/providers/ssh_session_provider.dart
    - lib/features/machines/providers/machines_provider.dart
  provides:
    - lib/features/sessions/screens/sessions_screen.dart
    - lib/features/sessions/widgets/machine_selection_sheet.dart
  affects:
    - lib/features/terminal/screens/terminal_screen.dart
    - lib/app.dart
    - lib/features/machines/screens/machine_list_screen.dart
tech_stack:
  added: []
  patterns:
    - "IndexedStack + Visibility(maintainState:true) + ExcludeSemantics for inactive tab lifecycle"
    - "PopScope(canPop:false) for Android back gesture suppression on SessionsScreen"
    - "ScrollController.animateTo in addPostFrameCallback to reveal new tab in strip"
    - "isActive bool on TerminalScreen gates SnackBar for background tab failure (SESS-04)"
    - "Navigator.of(context).pop() before callback in modal bottom sheet (pop-first pattern)"
    - "ConsumerStatefulWidget with didUpdateWidget for query-param-driven tab opening"
key_files:
  created:
    - lib/features/sessions/widgets/machine_selection_sheet.dart
    - lib/features/sessions/screens/sessions_screen.dart
  modified:
    - lib/features/terminal/screens/terminal_screen.dart
    - lib/app.dart
    - lib/features/machines/screens/machine_list_screen.dart
decisions:
  - "Removed _initialTabOpened boolean field from _SessionsScreenState — field was set but never read; the guard logic is entirely covered by _lastInitialMachineId comparison in didUpdateWidget"
  - "Used alternative navigation pattern from RESEARCH.md Open Question 1: machine list calls sessionsProvider.notifier.openTab() directly then context.push('/sessions') without query param, avoiding go_router same-route push ambiguity"
  - "machineId variable retained in terminal_screen.dart build() — still used in SnackBar message after AppBar removal"
metrics:
  duration: "284s (~4m 44s)"
  completed_date: "2026-06-21T00:08:44Z"
  tasks: 3
  files_created: 2
  files_modified: 3
---

# Phase 07 Plan 02: Multi-Tab Sessions UI Layer Summary

**One-liner:** Full sessions UI — horizontal tab strip with status dots, IndexedStack multi-terminal view, machine selection sheet, /sessions route, and isActive-gated SnackBar for background tab failure suppression.

## Files Created/Modified

| File | Status | Lines | Description |
|------|--------|-------|-------------|
| `lib/features/sessions/widgets/machine_selection_sheet.dart` | Created | 149 | ConsumerWidget bottom sheet listing machines; drag handle, machine tiles, empty-state with Add a machine button |
| `lib/features/sessions/screens/sessions_screen.dart` | Created | 406 | SessionsScreen (ConsumerStatefulWidget): PopScope, AppBar with add button, 44dp horizontal tab strip, IndexedStack of TerminalScreen widgets, _TabChip, _PulsingDot |
| `lib/features/terminal/screens/terminal_screen.dart` | Modified | 284 | Added isActive param (default true), AppBar removed, go_router import removed, statusLabel/isPulsing removed, SnackBar gated by widget.isActive |
| `lib/app.dart` | Modified | 90 | /machines/:id/terminal route removed, TerminalScreen import removed; /sessions route added with optional newMachineId query param; SessionsScreen import added |
| `lib/features/machines/screens/machine_list_screen.dart` | Modified | 87 | sessionsProvider import added; onTap replaced from context.push('/machines/:id/terminal') to openTab() + context.push('/sessions') |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused _initialTabOpened field**

- **Found during:** Task 2 (flutter analyze after initial implementation)
- **Issue:** Plan specified `bool _initialTabOpened = false` as a guard field in `_SessionsScreenState`. The field was set to `true` in `initState()` but never checked in any conditional — the guard behavior was entirely implemented by the `_lastInitialMachineId` comparison in `didUpdateWidget`. flutter analyze reported `unused_field`.
- **Fix:** Removed `_initialTabOpened` field entirely. The `_lastInitialMachineId` guard correctly prevents duplicate tab openings without the redundant boolean.
- **Files modified:** `lib/features/sessions/screens/sessions_screen.dart`
- **Commit:** ed4014b

## Flutter Analyze Output

```
Analyzing lib...
No issues found! (ran in 0.9s)
```

Full `lib/` directory clean. No warnings, no errors.

## Verification Checks

| Check | Result |
|-------|--------|
| `lib/features/sessions/screens/sessions_screen.dart` exists | PASS |
| `lib/features/sessions/widgets/machine_selection_sheet.dart` exists | PASS |
| `/sessions` route in app.dart | PASS (count: 1) |
| `terminal` removed from app.dart routes | PASS (count: 0) |
| `isActive` in terminal_screen.dart | PASS (count: 4) |
| `appBar:` removed from terminal_screen.dart | PASS (count: 0) |
| `sessionsProvider` in machine_list_screen.dart | PASS (count: 1) |
| `PopScope` in sessions_screen.dart | PASS (count: 2) |
| `IndexedStack` in sessions_screen.dart | PASS (count: 4) |
| `flutter analyze lib/` | PASS: No issues found |

## Manual Smoke Test Checklist

### SESS-01: Multiple simultaneous SSH sessions

- [ ] Connect to machine A → verify terminal renders SSH output
- [ ] From machine A's active session, tap + in tab strip → open machine B
- [ ] Verify two tabs appear in horizontal strip with machine names
- [ ] Switch between tabs by tapping — verify NO reconnect banner appears on either tab
- [ ] Verify each tab shows independent terminal content

### SESS-02: Tab strip UI and machine name display

- [ ] Each tab chip shows machine name (truncated with ellipsis if long), 8dp status dot, close button
- [ ] Status dot is green when connected, secondary-color pulsing when connecting/reconnecting, error-color when failed
- [ ] Open 4+ sessions — verify horizontal scroll works in tab strip
- [ ] New tab after 4+: verify strip auto-scrolls to show the new tab
- [ ] Active tab: primaryContainer background, primary border-bottom
- [ ] Inactive tab: surfaceContainerHigh background, no border

### SESS-03: Tab close and SSH lifecycle

- [ ] Close a non-last tab → verify other tabs' SSH sessions continue unaffected
- [ ] Verify closed machine no longer has active SSH (check process list on server)
- [ ] Close last tab → verify navigation goes to /machines screen

### SESS-04: Background tab failure isolation

- [ ] With machine A tab active, kill SSH daemon on machine B
- [ ] Verify machine B's tab dot turns red (error color)
- [ ] Verify NO SnackBar appears while viewing machine A's tab
- [ ] Switch to machine B tab — verify ReconnectFailedOverlay appears (Phase 4 behavior)

### Additional checks

- [ ] Android back gesture on /sessions does nothing (PopScope canPop:false)
- [ ] MachineSelectionSheet: tap + in AppBar or tab strip → sheet shows machine list
- [ ] MachineSelectionSheet empty state: "No machines configured." + "Add a machine" button → navigates to /machines/add
- [ ] MachineSelectionSheet: tap a machine → sheet dismisses, new tab opens for that machine

## Threat Model Compliance

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-07-04 | _TabChip reads machineProvider (already visible in MachineListScreen — no new disclosure) | Accepted |
| T-07-05 | No hard cap on tabs — SSH session count bounded by device memory | Accepted |
| T-07-06 | SessionsScreen reads newMachineId from query params but only calls openTab(id); invalid id produces SshFailed gracefully | Applied (alternative simpler pattern: openTab called directly from machine_list_screen, no query param used) |
| T-07-07 | PopScope(canPop:false) prevents user back gesture; programmatic navigation is developer-controlled | Accepted |
| T-07-SC | No new packages in Phase 7 | N/A |

## Known Stubs

None. All data is wired to live providers:
- Machine names/hosts come from `machineProvider` (live data)
- SSH session status comes from `sshSessionProvider(machineId)` (live state machine)
- Tab list comes from `sessionsProvider` (live Riverpod Notifier)

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

Files exist:
- FOUND: lib/features/sessions/widgets/machine_selection_sheet.dart
- FOUND: lib/features/sessions/screens/sessions_screen.dart
- FOUND: lib/features/terminal/screens/terminal_screen.dart (modified)
- FOUND: lib/app.dart (modified)
- FOUND: lib/features/machines/screens/machine_list_screen.dart (modified)

Commits exist:
- FOUND: 6df2d48 — feat(07-02): create MachineSelectionSheet bottom sheet widget
- FOUND: ed4014b — feat(07-02): create SessionsScreen with tab strip and IndexedStack
- FOUND: b720df5 — feat(07-02): wire sessions routing — remove terminal route, add /sessions
