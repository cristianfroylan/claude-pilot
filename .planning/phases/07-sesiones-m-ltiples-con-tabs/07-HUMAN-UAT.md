---
status: partial
phase: 07-sesiones-m-ltiples-con-tabs
source: [07-VERIFICATION.md]
started: 2026-06-21T00:30:00Z
updated: 2026-06-21T00:30:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Multiple sessions stay connected during tab switch (SESS-01)
expected: Open tab to machine A, open tab to machine B via the + button. Switch between tabs. Neither tab shows a reconnect banner or resets PTY scrollback. Claude Code output in both terminals is preserved.
result: [pending]

### 2. Background tab failure isolation — status dot only, no SnackBar on active tab (SESS-04)
expected: Kill SSH daemon on machine B while on machine A's tab. Machine B's tab chip dot turns red (colorScheme.error). No SnackBar appears on machine A's view. Switching to machine B's tab shows the ReconnectFailedOverlay.
result: [pending]

### 3. Last tab close navigates to /machines
expected: With exactly one tab open, tap the close (×) button on the tab chip. App navigates to the machine list screen. No crash.
result: [pending]

### 4. Android back gesture suppression (PopScope)
expected: On the sessions screen with tabs open, press the Android hardware back button. Nothing happens — the app does NOT navigate back to the machine list. The back gesture is fully suppressed.
result: [pending]

### 5. Horizontal tab strip scrolls when 3+ tabs open (SESS-02)
expected: Open 3+ sessions. The tab strip scrolls horizontally. All tabs are reachable. When a new tab opens, the strip auto-scrolls to reveal it.
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
