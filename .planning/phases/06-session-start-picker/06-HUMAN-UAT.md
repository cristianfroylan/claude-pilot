---
status: partial
phase: 06-session-start-picker
source: [06-VERIFICATION.md]
started: 2026-06-20T23:45:00Z
updated: 2026-06-20T23:45:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Picker sheet appears after SSH connects (folders configured)
expected: After SSH connects successfully on a machine with folderPaths configured, a bottom sheet appears immediately with the configured folder list and "Start blank" option
result: [pending]

### 2. Folder tap closes sheet and terminal reflects cd command
expected: Tapping a folder path closes the sheet and `cd <path>` appears in the terminal output
result: [pending]

### 3. "Start blank" closes sheet with no cd command
expected: Tapping "Start blank" closes the sheet and NO `cd` command is sent to the shell
result: [pending]

### 4. No picker appears when machine has no configured folders (PICK-04)
expected: On a machine with empty folderPaths, the session starts blank with no picker shown
result: [pending]

### 5. Picker does NOT reappear after mid-session auto-reconnect
expected: When SSH drops mid-session and auto-reconnects, the picker does NOT appear again (_pickerShown guard)
result: [pending]

### 6. Picker DOES reappear after manual retry following SshFailed
expected: When retries are exhausted (SshFailed state) and user taps Retry, on reconnect success the picker appears again (WR-02 fix: _pickerShown reset to false on SshFailed)
result: [pending]

### 7. Folder paths persist across cold app restart
expected: Configured folder paths saved in the edit screen survive app kill and relaunch
result: [pending]

### 8. Reorder order persists after save
expected: Dragging to reorder paths in the edit screen and saving preserves the new order
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
