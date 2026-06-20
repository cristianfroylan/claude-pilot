---
phase: 04-reconexion-robusta
reviewed: 2026-06-20T21:51:22Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/features/terminal/models/ssh_session_state.dart
  - lib/features/terminal/providers/permission_detector_provider.dart
  - lib/features/terminal/providers/ssh_session_provider.dart
  - lib/features/terminal/providers/ssh_session_provider.g.dart
  - lib/features/terminal/screens/terminal_screen.dart
  - lib/features/terminal/widgets/input_bar.dart
  - lib/features/terminal/widgets/reconnect_banner.dart
  - lib/features/terminal/widgets/reconnect_overlay.dart
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-06-20T21:51:22Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The reconnection state machine is architecturally sound: the generation-guarded done-watcher, the preserved `Terminal` instance across reconnect cycles, and the `_disposed` / `_cancelRequested` flag pattern all show careful reasoning about async lifecycle. The sealed `SshSessionState` hierarchy is clean and exhaustively pattern-matched at the call sites.

Two defects stand out as shippable blockers. First, the `onDispose` callback cancels `StreamSubscription`s without `await`, leaving a race window where data arriving after `_permissionController.close()` throws an unhandled `StateError` into the Flutter error zone. Second, `PermissionDetector.build()` is re-invoked on every countdown tick because it watches the SSH session provider directly; this tears down and recreates the broadcast stream subscription on each tick, creating a window where permission prompts can be silently dropped.

There are also four warnings of varying impact: inverted expand/collapse icons that will confuse users, a dead `sendAndClose` helper that does nothing beyond `send`, an uncommunicated `AsyncError` state when `machineId` is not found (perpetual spinner), and a `String.substring` call that can split a UTF-16 surrogate pair when a Claude Code prompt contains emoji.

---

## Critical Issues

### CR-01: `StreamSubscription.cancel()` not awaited in `onDispose` — `StateError` after controller close

**File:** `lib/features/terminal/providers/ssh_session_provider.dart:76-83`

**Issue:** `onDispose` calls `_stdoutSub?.cancel()` and `_stderrSub?.cancel()` without `await`. `StreamSubscription.cancel()` returns a `Future<void>`; the subscription's internal teardown is asynchronous. `_permissionController.close()` runs immediately after on the next line. If SSH bytes arrive in the brief window between `cancel()` being called and its future completing, `safeWrite` is invoked on the still-live listener. Inside `safeWrite`, `_terminal!.write` is protected by a try/catch, but `_permissionController.add(data)` on line 309 is **not** — it throws `StateError: Cannot add event after closing` on a closed broadcast `StreamController`. Because the `listen()` calls on lines 315 and 320 have no `onError` handler, this `StateError` propagates to the Flutter zone error handler, producing a crash report in debug mode and a silent swallowed error in release.

**Fix:**
```dart
// onDispose must be a sync callback, so use a microtask to sequence teardown
ref.onDispose(() {
  _disposed = true;
  _countdownTimer?.cancel();
  _countdownTimer = null;
  // Cancel subscriptions synchronously (cancel() is safe to call without await
  // if we guard _permissionController.add against the closed state)
  _stdoutSub?.cancel();
  _stderrSub?.cancel();
  _stdoutSub = null;
  _stderrSub = null;
  _sshSession?.close();
  _client?.close();
  _permissionController.close();
});
```

And protect the `_permissionController.add` call in `safeWrite`:

```dart
void safeWrite(String data) {
  try {
    _terminal!.write(data);
  } catch (_) {}
  if (!_permissionController.isClosed) {
    _permissionController.add(data);
  }
}
```

`StreamController.isClosed` is synchronously readable and eliminates the race without requiring `await` in the dispose callback.

---

### CR-02: `PermissionDetector.build()` re-subscribes on every countdown tick — permission prompts silently dropped

**File:** `lib/features/terminal/providers/permission_detector_provider.dart:24-43`

**Issue:** `PermissionDetector` calls `ref.watch(sshSessionProvider(machineId))` in its `build()`. The SSH session provider emits a new `AsyncData` on **every countdown tick** (once per second during `SshReconnecting` or `SshConnecting`) because the timer loop calls `state = AsyncData(SshReconnecting(..., secondsLeft: N))` repeatedly. Each emission causes Riverpod to tear down the current `StreamNotifier` stream and call `build()` again, which cancels the previous subscription to `_permissionController` (a broadcast stream) and creates a new one. Broadcast streams do not buffer events for late subscribers. Any permission prompt line that arrives during the ~0 ms subscription gap is permanently lost. Over a 3-attempt mid-session reconnect with 2+4+8 second delays, `build()` is called at least 14 times.

**Fix:** Do not watch the full `sshSessionProvider` stream from inside `PermissionDetector`. Instead, watch only the connectivity class (connected vs. not) using `select`, or subscribe to `permissionStream` once outside of the countdown-ticking state:

```dart
@override
Stream<String?> build(String machineId) {
  // Watch only the type tag — not the full state (which changes every countdown tick).
  final isActive = ref.watch(
    sshSessionProvider(machineId).select((async) {
      final s = async.value;
      return s is SshConnected || s is SshReconnecting || s is SshFailed;
    }),
  );

  if (!isActive) return const Stream.empty();

  return ref
      .read(sshSessionProvider(machineId).notifier)
      .permissionStream
      .map(_detect);
}
```

`select` only triggers a rebuild when the **selected boolean** changes (connecting→connected, or connected→failed), not on every countdown tick.

---

## Warnings

### WR-01: `expand_more` / `expand_less` icons are inverted

**File:** `lib/features/terminal/widgets/input_bar.dart:257-259`

**Issue:** `Icons.expand_more` (downward chevron, "show more") is displayed when `_commandsVisible == true` (the panel is already open and the user needs a collapse affordance). `Icons.expand_less` (upward chevron, "show less") is displayed when the panel is hidden and the user needs an expand affordance. The icons are exactly backwards relative to their Material Design semantics and every standard Flutter pattern (e.g., `ExpansionTile`).

**Fix:**
```dart
icon: Icon(
  _commandsVisible
      ? Icons.expand_less   // panel open → tap to collapse
      : Icons.expand_more,  // panel closed → tap to expand
  size: 16,
),
```

---

### WR-02: `sendAndClose` is a dead alias — misleading name, panel never closes

**File:** `lib/features/terminal/widgets/input_bar.dart:141`

**Issue:** `void sendAndClose(List<int> bytes) => send(bytes);` is named to suggest it sends bytes and closes the command panel, but it simply delegates to `send` with no panel-close logic. All control chips use `sendAndClose` on line 205, so users who select Ctrl+C, Ctrl+D, etc. expect the command panel to collapse — it doesn't. The misleading name also obscures what the actual intent was.

**Fix:** Implement the close, or rename to `send` and remove the duplicate:
```dart
void sendAndClose(List<int> bytes) {
  send(bytes);
  setState(() => _commandsVisible = false);
}
```

---

### WR-03: `StateError` on missing `machineId` leaves UI in a permanent spinner

**File:** `lib/features/terminal/providers/ssh_session_provider.dart:93`

**Issue:** `if (machine == null) throw StateError('Machine $machineId not found');` causes `build()` to throw, which Riverpod converts to `AsyncError`. Because `terminal_screen.dart` accesses the provider via `sessionAsync.value` (returns `null` on error, not just loading), the UI renders `CircularProgressIndicator` forever with no error message and no way to recover other than the close button. There is no user-visible indication that the machine record is missing.

**Fix:** Emit `SshFailed` instead of throwing, so the failed-overlay with a Retry button is shown:
```dart
final machine = ref.read(machineProvider.notifier).get(machineId);
if (machine == null) {
  // Emit a terminal-less failed state or pop the route — throwing leaves the
  // UI in AsyncError which renders as a perpetual spinner.
  // Option A: return a placeholder SshFailed with a fresh Terminal so UI recovers.
  _terminal ??= Terminal(maxLines: 2000);
  return SshFailed(_terminal!);
}
```

Alternatively, `terminal_screen.dart` should handle `AsyncError` explicitly with `sessionAsync.when(error: ...)` and show an actionable error widget.

---

### WR-04: `String.substring` truncation can split a UTF-16 surrogate pair

**File:** `lib/features/terminal/providers/permission_detector_provider.dart:56-58`

**Issue:** `trimmed.substring(0, 77)` operates on UTF-16 code units. A surrogate pair (emoji, supplementary CJK characters) occupies two code units. If the 77th or 78th code unit is the first half of a surrogate pair, `substring` produces a string with an unpaired surrogate, which is technically invalid and can cause rendering glitches or assertion errors in some Flutter/Dart code paths. Claude Code permission prompts rarely contain emoji, but it is a latent defect.

**Fix:**
```dart
String _truncate(String s, int maxChars) {
  if (s.length <= maxChars) return s;
  // Walk runes (Unicode code points) to avoid splitting surrogates.
  final runes = s.runes.toList();
  if (runes.length <= maxChars - 3) return s;
  return String.fromCharCodes(runes.take(maxChars - 3)) + '...';
}
```

Then in `_detect`: `return _truncate(trimmed, 80);`

---

## Info

### IN-01: `RegExp` compiled on every stdout chunk — consider a module-level constant

**File:** `lib/features/terminal/providers/permission_detector_provider.dart:51`

**Issue:** `final pattern = RegExp(kPermissionPattern)` inside `_detect` compiles the regular expression on every call. `_detect` is invoked for each SSH stdout/stderr chunk while the session is active, which can be thousands of times per second during active Claude Code output. Dart's `RegExp` compilation is not free.

**Fix:** Hoist to a module-level constant:
```dart
final _kPermissionRegExp = RegExp(kPermissionPattern);
```
Then use `_kPermissionRegExp.hasMatch(trimmed)` in `_detect`.

---

### IN-02: `cast<dynamic>()` workaround in `terminal_screen.dart` obscures type errors

**File:** `lib/features/terminal/screens/terminal_screen.dart:41-44`

**Issue:** `machines?.cast<dynamic>().firstWhere((m) => m.id == machineId, orElse: () => null)` casts `List<Machine>` to `List<dynamic>` solely to allow `orElse: () => null` (which requires the list's element type to be nullable). This bypasses the type checker — if `Machine` is ever refactored and `name` is moved or renamed, the `machine?.name as String?` cast on line 45 fails at runtime with no compile-time warning.

**Fix:** Use a nullable typed approach:
```dart
final machine = machines?.where((m) => m.id == machineId).firstOrNull;
final machineName = machine?.name ?? 'Terminal';
```
`Iterable.firstOrNull` is available in Dart 3+, returns `Machine?` without a cast.

---

### IN-03: `ReconnectBanner` contains a redundant inner `SafeArea`

**File:** `lib/features/terminal/widgets/reconnect_banner.dart:41-43`

**Issue:** `ReconnectBanner` wraps its content in `SafeArea(top: true, ...)`. The banner is rendered inside a `Positioned(top: 0)` within a `Stack` that is itself inside the `Scaffold` body, which is already wrapped in `SafeArea(top: true)` at `terminal_screen.dart:128`. The inner `SafeArea` adds zero padding (the outer one already consumed the inset) and creates a confusing double-wrap that implies the widget is designed to be used outside of a safe area context.

**Fix:** Remove the `SafeArea` wrapper from `ReconnectBanner`. The widget should not be responsible for top insets when it is always placed inside a safe context by its parent.

---

_Reviewed: 2026-06-20T21:51:22Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
