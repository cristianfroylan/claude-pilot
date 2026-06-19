---
phase: 02-claude-code-remote
plan: "02"
subsystem: terminal/permission-detection
tags: [permission-card, ssh-session, stream-notifier, riverpod, animated-switcher]
dependency_graph:
  requires:
    - "02-01 (SshSession with sendText, terminal screen layout established)"
  provides:
    - "permissionStream on SshSession (broadcast stream of stdout chunks)"
    - "PermissionDetector @riverpod StreamNotifier (emits matched line or null)"
    - "PermissionCard widget (Approve/Reject one-tap buttons)"
    - "AnimatedSwitcher permission slot in TerminalScreen"
  affects:
    - "lib/features/terminal/providers/ssh_session_provider.dart"
    - "lib/features/terminal/screens/terminal_screen.dart"
tech_stack:
  added:
    - "dart:async StreamController<String>.broadcast() for stdout interception"
  patterns:
    - "@riverpod class PermissionDetector extends _$PermissionDetector (StreamNotifier with Stream<String?> build)"
    - "AnimatedSwitcher with distinct ValueKeys for permission card slot"
    - "ref.invalidate() for same-frame card dismissal after button tap"
key_files:
  created:
    - lib/features/terminal/models/permission_detector.dart
    - lib/features/terminal/providers/permission_detector_provider.dart
    - lib/features/terminal/providers/permission_detector_provider.g.dart
    - lib/features/terminal/widgets/permission_card.dart
  modified:
    - lib/features/terminal/providers/ssh_session_provider.dart
    - lib/features/terminal/screens/terminal_screen.dart
decisions:
  - "Used .asData?.value instead of .valueOrNull (not available in installed Riverpod 3.3.1)"
  - "StreamController field declared as non-nullable final — initialized at declaration, closed in ref.onDispose"
  - "ref.invalidate() chosen over ref.read(provider.notifier).state setter for immediate dismissal"
metrics:
  duration: "~3 minutes (203 seconds)"
  completed_date: "2026-06-19"
  tasks_completed: 3
  files_created: 4
  files_modified: 2
---

# Phase 02 Plan 02: Permission Approval Card Summary

**One-liner:** Broadcast StreamController on SshSession feeds a @riverpod PermissionDetector that drives an AnimatedSwitcher PermissionCard above InputBar for one-tap Claude Code approve/reject.

## What Was Built

The permission detection pipeline implemented as a vertical slice:

1. **SshSession stdout interception** (`ssh_session_provider.dart`): Added `StreamController<String>.broadcast()` field with public `permissionStream` getter. All stdout/stderr chunks processed by `safeWrite` are now also fed into `_permissionController.add(data)`. The controller is closed in `ref.onDispose` to prevent stream leaks. The leftover debug `print` statement was also removed.

2. **Permission model** (`permission_detector.dart`): Top-level `const kPermissionPattern` regex constant targeting Claude Code permission prompt formats. Documented as version-sensitive per STATE.md blocker. No imports required — pure constant file.

3. **Permission detector provider** (`permission_detector_provider.dart`): `@riverpod class PermissionDetector extends _$PermissionDetector` returning `Stream<String?>`. Gated via `sessionAsync.when` — emits `Stream.empty()` while connecting or on error. Maps `permissionStream` through `_detect` which scans lines in reverse, returns the most-recent matching line trimmed and truncated to 80 chars, or `null` on no match. `build_runner` generated `permission_detector_provider.g.dart`.

4. **PermissionCard widget** (`permission_card.dart`): `ConsumerWidget` with `machineId` and `line` props. Layout: `Container(color: surfaceContainerHighest)` → `Row` with `lock_outline` icon, `Expanded(Text(ellipsis))`, `OutlinedButton(Reject, error foreground)`, `FilledButton(Approve)`. Both buttons call `sendText('y\n'/'n\n')` then immediately `ref.invalidate(permissionDetectorProvider(machineId))` for same-frame dismissal.

5. **TerminalScreen wiring** (`terminal_screen.dart`): Added `permissionDetectorProvider` watch using `.asData?.value` (`.valueOrNull` not available). Inserted `AnimatedSwitcher(200ms)` with `PermissionCard(key: ValueKey('permission-card'))` / `SizedBox.shrink(key: ValueKey('no-card'))` between the `Expanded` terminal view and `InputBar`.

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| AsyncValue access | `.asData?.value` | `.valueOrNull` not available in Riverpod 3.3.1 (per line-24 caveat) |
| StreamController nullability | `final` non-nullable | Initialized at declaration; no null check needed on `.add()` or `.close()` |
| Card dismissal | `ref.invalidate()` | Dismisses on same frame as button tap; prevents y/n echo re-triggering the card (T-02-04) |
| Regex in `_detect` | Lines scanned in reverse | Most-recent matching line most accurately represents the current prompt |
| PermissionDetector form | `@riverpod class` (StreamNotifier) | Compiles correctly; no fallback to plain function provider needed (assumption A3 not triggered) |

## Deviations from Plan

None — plan executed exactly as written. The `@riverpod class PermissionDetector extends _$PermissionDetector` with `Stream<String?> build(String machineId)` compiled successfully without requiring the A3 fallback to a plain `@riverpod` function.

## Threat Mitigations Implemented

| Threat | Mitigation |
|--------|-----------|
| T-02-04: y/n echo dismiss-reappear loop | `ref.invalidate(permissionDetectorProvider)` immediately after `sendText` in both Approve and Reject handlers |
| T-02-05: StreamController leak after session ends | `_permissionController.close()` in `ref.onDispose` after `_client?.close()` |

## Self-Check: PASSED

Files verified:
- `lib/features/terminal/models/permission_detector.dart` — FOUND
- `lib/features/terminal/providers/permission_detector_provider.dart` — FOUND
- `lib/features/terminal/providers/permission_detector_provider.g.dart` — FOUND
- `lib/features/terminal/widgets/permission_card.dart` — FOUND

Commits verified:
- `01afd70` feat(02-02): wire stdout interception in SshSession and remove debug print — FOUND
- `93c48a6` feat(02-02): create permission detector model, StreamNotifier provider, and generated g.dart — FOUND
- `9f46c09` feat(02-02): create PermissionCard and wire AnimatedSwitcher into TerminalScreen — FOUND

Analysis: `flutter analyze` on all 5 touched files — No issues found.
