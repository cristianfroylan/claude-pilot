# Phase 4: Reconexión Robusta - Research

**Researched:** 2026-06-20
**Domain:** Flutter / Riverpod AsyncNotifier state machines, Dart sealed classes, dartssh2 connection lifecycle
**Confidence:** HIGH

## Summary

Phase 4 transforms the existing brittle 3-attempt / fixed-1s-delay retry loop in `SshSession` into a full reconnection state machine. The architecture decisions are already locked (sealed class, AsyncData-only pattern, Timer.periodic for countdown). This research confirms the exact Dart/Riverpod APIs needed and surfaces one critical correction to a STATE.md assumption: `@Riverpod(retry: false)` is **not valid syntax** — the annotation accepts a function, not a boolean. The correct idiom is a top-level function that always returns `null`.

The implementation scope is narrow: one provider file to refactor (`ssh_session_provider.dart`), one screen to wrap in a Stack (`terminal_screen.dart`), and two new widget files (reconnection overlay + mid-session banner). No new packages are required; everything is already in `pubspec.yaml`. The xterm `Terminal` instance must be promoted from a local variable in `_connectOnce()` to an instance field on `SshSession` — this is the pivotal structural change that everything else depends on.

The existing `.g.dart` confirms the provider already generates with `retry: null` at the Riverpod runtime level, meaning Riverpod 3's auto-retry is already inactive. Adding the function-based annotation is a belt-and-suspenders declaration for human readers and future-proofs against generator behavior changes.

**Primary recommendation:** Promote `Terminal` to an instance field first (Task 1), then replace the state type from `AsyncValue<Terminal>` to `AsyncValue<SshSessionState>` (Task 2), then wire the retry loop and countdown (Task 3), then build the UI (Task 4).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Reconnection State Model**
- Use `AsyncData(SshSessionState)` with a sealed class — never emit `AsyncLoading` or `AsyncError` during reconnect so the xterm `Terminal` instance (and its scrollback buffer) is always reachable from the UI
- Sealed class variants: `SshConnecting | SshConnected(terminal) | SshReconnecting(terminal, attempt, maxAttempts, secondsLeft) | SshFailed(terminal)`
- The `Terminal` instance is carried in all variants — UI always has a valid terminal to render
- Retry loop lives inside `SshSession.build()` with a `_isMidSession` bool flag distinguishing initial vs mid-session paths — no external ReconnectManager class
- Countdown exposed via `secondsLeft` field in `SshReconnecting`, updated each second via `Timer.periodic` that writes `state = AsyncData(SshReconnecting(..., secondsLeft: n))`

**Retry Parameters & Cancel**
- Initial connection: 5 attempts, exponential backoff 1s→2s→4s→8s→16s (per RECON-01)
- Mid-session drop: 3 attempts, backoff 2s→4s→8s (per RECON-02)
- Cancel mechanism: `bool _cancelRequested` field on the notifier, checked at each loop iteration before sleeping and before retrying
- Manual retry post-exhaustion: public `reconnect()` method on `SshSession` notifier that resets `_cancelRequested = false` and re-runs the retry loop from the current state's terminal — does NOT call `ref.invalidateSelf()` (would create new Terminal and clear scrollback)
- `@Riverpod(retry: false)` on SshSession — prevents Riverpod 3 auto-retry stacking with custom backoff loop (already noted in STATE.md)

**UI Feedback**
- Initial connection failure UI: overlay on `TerminalScreen` (not a Dialog) showing spinner + "Attempt N/5 — retrying in Xs" + Cancel button — terminal content visible in background
- Mid-session drop UI: inline `AnimatedContainer` banner pinned to top of terminal view — one compact line showing "Connection lost · Attempt N/3 · Retry in Xs" + Cancel — terminal scrollback fully visible below
- Post-reconnect: brief `SnackBar("Reconnected")` auto-dismissing in 2s — does not write to terminal (would contaminate Claude Code scrollback)

### Claude's Discretion
- Exact widget styling (colors, fonts, padding) consistent with existing `AppTheme` — no new design tokens needed
- Whether to extract reconnect overlay into its own widget file or keep inline in `terminal_screen.dart` — prefer separate file if >50 lines
- `@Riverpod(retry: false)` exact annotation syntax — verify against Riverpod 3 docs during planning research

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RECON-01 | Al fallar la conexión inicial, la app reintenta automáticamente hasta 5 veces con backoff exponencial (1s→2s→4s→8s→16s) mostrando número de intento y tiempo de espera | Retry loop in `build()`, `SshConnecting` / `SshReconnecting` state, Timer.periodic countdown, initial-path detection via `_isMidSession = false` |
| RECON-02 | Al caerse una sesión activa (mid-session), la app reintenta automáticamente hasta 3 veces con un banner inline en el terminal | `done.then()` triggers mid-session path (`_isMidSession = true`), `SshReconnecting` emitted via `AsyncData`, `AnimatedContainer` banner in `TerminalScreen` |
| RECON-03 | El usuario puede cancelar los reintentos en curso con un botón visible | `_cancelRequested` bool field, Cancel button in both overlay and banner calls `notifier.cancel()` public method |
| RECON-04 | Tras agotar los reintentos automáticos, el usuario puede forzar un reintento manual | `SshFailed` state drives "Retry" button, tapping calls `notifier.reconnect()` which re-runs loop |
| RECON-05 | El historial del terminal (scrollback) se preserva durante y después de la reconexión — no se limpia el buffer de xterm | `Terminal` promoted to instance field; all sealed class variants carry it; no `AsyncLoading`/`AsyncError` emitted after first connection |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Retry loop + backoff timing | Provider (SshSession notifier) | — | Business logic, not UI concern; notifier owns SSH lifecycle |
| Countdown exposure | Provider (SshSession notifier) | — | `secondsLeft` on `SshReconnecting` state — UI reads it, doesn't compute it |
| Mid-session drop detection | Provider (SshSession notifier) | — | `_client!.done.then(...)` is inside the notifier — only place with SSHClient reference |
| Cancel / manual retry | Provider (public methods) | UI (buttons call methods) | Notifier exposes `cancel()` and `reconnect()` — UI is stateless |
| Initial-connect overlay | UI (TerminalScreen) | — | Overlay is a presentation concern — reads `SshConnecting` state |
| Mid-session banner | UI (TerminalScreen via Stack) | — | `AnimatedContainer` banner: reads `SshReconnecting` state |
| Post-reconnect SnackBar | UI (TerminalScreen listener) | — | `ref.listen` transition `SshReconnecting → SshConnected` fires SnackBar |
| Terminal scrollback preservation | Provider (Terminal as instance field) | — | Critical: Terminal must not be recreated; provider field survives re-runs of `_connectOnce` |

---

## Standard Stack

### Core — no new packages required

| Library | Version in pubspec | Purpose | Why Standard |
|---------|-------------------|---------|--------------|
| `flutter_riverpod` | ^3.3.1 | AsyncNotifier state machine | Already in use; `AsyncData(SshSessionState)` pattern is the standard Riverpod 3 way to avoid loading/error destroying widget state |
| `riverpod_annotation` | 4.0.2 | `@riverpod` codegen annotation | Already in use; `retry` parameter controls auto-retry |
| `dartssh2` | ^2.18.0 | SSH transport; `SSHClient.done` for drop detection | Already in use; `done` Future is the official disconnect signal |
| `xterm` | ^4.0.0 | Terminal model (scrollback buffer owner) | Already in use; `Terminal(maxLines: 2000)` instance promoted to field |
| `dart:async` `Timer` | SDK | Countdown timer (1-second ticks) | Standard library; `Timer.periodic` + `ref.onDispose(timer.cancel)` |

**No additional packages needed for Phase 4.** [VERIFIED: codebase pubspec.yaml]

### Package Legitimacy Audit

> No new packages are installed in this phase. All dependencies are already in `pubspec.yaml` and were verified during Phase 1 research. Audit not required.

---

## Critical Annotation Syntax Correction

> STATE.md Pending Todo: "Verify Riverpod 3 @Riverpod(retry: false) annotation syntax before Phase 4 implementation"

**Finding: `@Riverpod(retry: false)` is INVALID.** [VERIFIED: pub.dev/documentation/riverpod_annotation/latest/]

The `retry` parameter on the `@Riverpod` annotation has type `Duration? Function(int retryCount, Object error)?` — it accepts a function reference or null, not a boolean.

**Correct syntax to disable auto-retry:**

```dart
// Top-level function (global scope, NOT static method — static causes build_runner error)
// [VERIFIED: riverpod.dev/docs/concepts2/retry + GitHub issue #4332]
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
class SshSession extends _$SshSession {
  // ...
}
```

**Why a top-level function, not an inline lambda or static method:**
- Inline lambda `(retryCount, error) => null` in an annotation is a compile-time constant restriction — Dart annotation arguments must be compile-time constants; function literals are not.
- Static method reference (e.g., `SshSession._noRetry`) causes a `PrefixedIdentifierImpl` cast error in `riverpod_generator` build_runner (confirmed bug in GitHub issue #4332). [CITED: github.com/rrousselGit/riverpod/issues/4332]
- Top-level function reference is the documented working pattern. [VERIFIED: riverpod.dev/docs/concepts2/retry]

**Current state (pre-Phase 4):** The generated `.g.dart` already passes `retry: null` to the provider constructor (line 51 of `ssh_session_provider.g.dart`), which effectively disables auto-retry at runtime. The annotation is belt-and-suspenders — but required to future-proof against generator behavior changes.

---

## Architecture Patterns

### System Architecture: State Machine Data Flow

```
SSHClient.done future
        │
        ▼ (transport closed)
SshSession.build()
  ├─ _isMidSession == false (initial path)
  │     │
  │     ├── attempt loop (max 5, backoff 1→2→4→8→16s)
  │     │     ├── state = AsyncData(SshConnecting(attempt, max, secondsLeft))
  │     │     │         └── Timer.periodic updates secondsLeft each 1s
  │     │     ├── _connectOnce() → success → state = AsyncData(SshConnected(terminal))
  │     │     │                              install done-watcher → _isMidSession = true
  │     │     └── failure → _cancelRequested? → state = AsyncData(SshFailed(terminal))
  │     │                                         else loop continues
  │     └── exhausted → state = AsyncData(SshFailed(terminal))
  │
  └─ _isMidSession == true (mid-session drop)
        │
        ├── attempt loop (max 3, backoff 2→4→8s)
        │     ├── state = AsyncData(SshReconnecting(terminal, attempt, max, secondsLeft))
        │     │         └── Timer.periodic updates secondsLeft each 1s
        │     ├── _connectOnce() → success → state = AsyncData(SshConnected(terminal))
        │     │                              install new done-watcher
        │     └── failure → _cancelRequested? → state = AsyncData(SshFailed(terminal))
        │
        └── exhausted → state = AsyncData(SshFailed(terminal))

UI (TerminalScreen) reads:
  SshConnecting(attempt, max, secondsLeft) → full-screen overlay (Stack)
  SshConnected(terminal)                  → TerminalViewWrapper (normal)
  SshReconnecting(terminal, att, max, s)  → TerminalViewWrapper + AnimatedContainer banner
  SshFailed(terminal)                     → TerminalViewWrapper + "Retry" button overlay
```

### Recommended Project Structure — Phase 4 file changes

```
lib/
├── features/
│   └── terminal/
│       ├── models/
│       │   └── ssh_session_state.dart        # NEW — sealed class SshSessionState
│       ├── providers/
│       │   ├── ssh_session_provider.dart     # MODIFIED — major refactor
│       │   └── ssh_session_provider.g.dart   # REGENERATED by build_runner
│       ├── screens/
│       │   └── terminal_screen.dart          # MODIFIED — Stack + state switch
│       └── widgets/
│           ├── reconnect_overlay.dart         # NEW — initial connect failure overlay
│           └── reconnect_banner.dart          # NEW — mid-session inline banner
```

### Pattern 1: SshSessionState Sealed Class

**What:** Dart 3 sealed class with four variants, all carrying `Terminal` to guarantee scrollback survives state transitions.
**When to use:** Any time the provider needs to communicate connect progress or failure without losing the terminal instance.

```dart
// lib/features/terminal/models/ssh_session_state.dart
// Source: Dart 3 sealed class docs — dart.dev/language/class-modifiers#sealed
sealed class SshSessionState {
  const SshSessionState();
}

/// Initial connection attempt in progress (no terminal yet rendered by xterm).
class SshConnecting extends SshSessionState {
  const SshConnecting({
    required this.attempt,
    required this.maxAttempts,
    required this.secondsLeft,
  });
  final int attempt;
  final int maxAttempts;
  final int secondsLeft;
}

/// Connected and live.
class SshConnected extends SshSessionState {
  const SshConnected(this.terminal);
  final Terminal terminal;
}

/// Mid-session drop: retrying. Terminal kept alive.
class SshReconnecting extends SshSessionState {
  const SshReconnecting({
    required this.terminal,
    required this.attempt,
    required this.maxAttempts,
    required this.secondsLeft,
  });
  final Terminal terminal;
  final int attempt;
  final int maxAttempts;
  final int secondsLeft;
}

/// All retries exhausted. Terminal kept alive — user can tap Retry.
class SshFailed extends SshSessionState {
  const SshFailed(this.terminal);
  final Terminal terminal;
}
```

### Pattern 2: Terminal as Instance Field

**What:** `Terminal` promoted from local variable in `_connectOnce()` to an instance field on the notifier. Created lazily on first build (or explicitly before the first attempt).
**When to use:** Required whenever `Terminal` must persist across calls to `_connectOnce()` — i.e., every reconnect attempt.

```dart
// BEFORE (Phase 1-3): Terminal was created inside _connectOnce, destroyed on reconnect
Future<Terminal> _connectOnce(...) async {
  final terminal = Terminal(maxLines: 2000);  // ← local, destroyed each retry
  ...
}

// AFTER (Phase 4): Terminal is an instance field, created once
Terminal? _terminal;

@override
Future<SshSessionState> build(String machineId) async {
  ref.onDispose(() { ... });
  _terminal ??= Terminal(maxLines: 2000);  // created once, reused forever
  ...
}
```

### Pattern 3: `@Riverpod` with retry disabled + auto-retry prevention

```dart
// Top-level function — NOT a static or lambda (see Critical Annotation Syntax Correction above)
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
class SshSession extends _$SshSession {
  Terminal? _terminal;
  bool _isMidSession = false;
  bool _cancelRequested = false;

  static const _initialMaxAttempts = 5;
  static const _midSessionMaxAttempts = 3;
  static const _initialBackoff = [1, 2, 4, 8, 16];  // seconds
  static const _midSessionBackoff = [2, 4, 8];

  @override
  Future<SshSessionState> build(String machineId) async {
    ref.onDispose(() {
      _disposed = true;
      _sshSession?.close();
      _client?.close();
      _permissionController.close();
    });

    _terminal ??= Terminal(maxLines: 2000);
    _cancelRequested = false;

    final machine = ref.read(machineProvider.notifier).get(machineId);
    if (machine == null) throw StateError('Machine $machineId not found');
    final password = await ref.read(machineProvider.notifier).getPassword(machineId);

    return _runRetryLoop(
      machine.host, machine.port, machine.username, password,
      maxAttempts: _initialMaxAttempts,
      backoffSeconds: _initialBackoff,
    );
  }
}
```

### Pattern 4: Timer.periodic countdown with ref.onDispose

**What:** Each backoff wait exposes a countdown to the UI by updating state once per second.
**When to use:** During any wait period in the retry loop.

```dart
Future<void> _waitWithCountdown(int totalSeconds, SshSessionState baseState) async {
  // baseState is SshConnecting or SshReconnecting with secondsLeft filled in
  var secondsLeft = totalSeconds;
  final completer = Completer<void>();
  Timer? timer;

  timer = Timer.periodic(const Duration(seconds: 1), (_) {
    secondsLeft--;
    if (secondsLeft <= 0 || _cancelRequested || _disposed) {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete();
      return;
    }
    // Emit updated countdown state — use baseState pattern to determine which variant
    _emitCountdownState(secondsLeft);
  });

  // Cancel timer on provider dispose
  ref.onDispose(() {
    timer?.cancel();
    if (!completer.isCompleted) completer.complete();
  });

  await completer.future;
  timer?.cancel();
}
```

**Simpler alternative:** `await Future.delayed(Duration(seconds: totalSeconds))` with a parallel `Timer.periodic`. The completer approach lets cancellation (`_cancelRequested`) short-circuit the wait without waiting for the full duration.

### Pattern 5: Mid-session drop detection via `SSHClient.done`

**What:** Detect transport close by awaiting `_client!.done` after successful connection. On completion, trigger the mid-session retry loop.
**When to use:** Once per successful connection, immediately after setting `state = AsyncData(SshConnected(...))`.

```dart
// CURRENT (Phase 1-3) — routes drop to AsyncError:
_client!.done.catchError((Object e) {
  if (!_disposed) state = AsyncError(e, StackTrace.current);
});

// PHASE 4 — routes drop to mid-session retry loop:
_client!.done.then((_) {
  if (!_disposed && _isMidSession) {
    _runMidSessionRetry();  // kicks off the 3-attempt loop
  }
}, onError: (Object e) {
  if (!_disposed && _isMidSession) {
    _runMidSessionRetry();  // error also triggers retry
  }
});
```

### Pattern 6: UI — Stack + sealed class switch

**What:** `TerminalScreen` wraps its body in a `Stack`. The top layer is conditionally visible based on the sealed class variant. The `TerminalViewWrapper` always renders (to keep PTY mounted).
**When to use:** Any terminal screen state overlay.

```dart
// In TerminalScreen.build():
final sessionState = ref.watch(sshSessionProvider(machineId)).value;

// Stack: terminal always at bottom, overlay/banner on top
Stack(
  children: [
    // Always present — preserves PTY mount and scrollback
    if (sessionState case SshConnected(:final terminal) ||
                          SshReconnecting(:final terminal) ||
                          SshFailed(:final terminal))
      TerminalViewWrapper(machineId: machineId, terminal: terminal),

    // Initial-connect overlay (full-screen, semi-transparent)
    if (sessionState case SshConnecting(:final attempt, :final maxAttempts, :final secondsLeft))
      ReconnectOverlay(attempt: attempt, max: maxAttempts, secondsLeft: secondsLeft,
                       onCancel: () => ref.read(sshSessionProvider(machineId).notifier).cancel()),

    // Mid-session banner (inline, top-pinned)
    if (sessionState case SshReconnecting(:final attempt, :final maxAttempts, :final secondsLeft))
      Positioned(top: 0, left: 0, right: 0,
        child: ReconnectBanner(attempt: attempt, max: maxAttempts, secondsLeft: secondsLeft,
                               onCancel: () => ref.read(...).cancel())),

    // Failed overlay with Retry button
    if (sessionState is SshFailed)
      ReconnectFailedOverlay(
        onRetry: () => ref.read(sshSessionProvider(machineId).notifier).reconnect()),
  ],
)
```

### Anti-Patterns to Avoid

- **`ref.invalidateSelf()` for manual retry:** Destroys the provider and recreates a new `Terminal` instance — scrollback buffer lost. RECON-05 violation. Use the public `reconnect()` method that re-runs the loop on the existing `_terminal` field. [ASSUMED — derived from Riverpod invalidation semantics]
- **Emitting `AsyncLoading` or `AsyncError` after first connection:** Destroys `AsyncData` state, causes `sessionAsync.when(loading: ..., error: ...)` to render the fallback widget instead of the terminal. All post-connect states must be `AsyncData(SshSessionState)`. [VERIFIED: CONTEXT.md locked decision]
- **`state = AsyncData(SshReconnecting(...))` with new Timer started inside Timer callback:** Timer-inside-timer causes doubled tick rate on consecutive reconnects. Always cancel previous timer before starting a new one.
- **Calling `ref.onDispose()` after an `await`:** The existing `ref.onDispose()` must remain the very first call in `build()` — before any awaits. Riverpod disposes the provider if a watcher disappears mid-await; the dispose registration must happen synchronously.
- **Static method as `retry:` parameter:** Causes `build_runner` cast failure (`PrefixedIdentifierImpl` not subtype of `SimpleIdentifier?`). Use a top-level function. [CITED: github.com/rrousselGit/riverpod/issues/4332]
- **Leaving `_isMidSession` true when `reconnect()` is called manually:** The `reconnect()` method should reset `_isMidSession = false` before re-running the loop so it uses initial-path attempt counts (5) not mid-session counts (3). Wait — actually, manual retry after exhaustion keeps `_isMidSession` intact because the user was in a live session. The planner must decide: use the same attempt count as the path that exhausted, or always use 3 for manual retry. **This is a discretion call for the planner.**

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Countdown timer | Manual `Future.delayed` loop writing integers | `Timer.periodic` (dart:async) | Single object, `cancel()` method, integrates with `ref.onDispose` |
| Exponential backoff values | Runtime math `pow(2, attempt)` | Constant list `[1, 2, 4, 8, 16]` | No risk of float precision issues; values are fixed by CONTEXT.md |
| Drop detection | Polling `_client.isClosed` every N seconds | `_client.done.then()` | Push-based; no polling overhead; `done` completes exactly once per connection |
| State pattern matching UI | `if (state is X) ... else if (state is Y) ...` chains | Dart 3 `switch (state)` exhaustive pattern matching | Compile-time exhaustiveness check — adding a new sealed variant forces all switch sites to handle it |
| Overlay positioning | Absolute pixel offsets | `Stack` + `Positioned(top: 0)` | Adapts to any screen size; no hardcoded heights |

**Key insight:** The Riverpod `AsyncData`-only approach avoids the double-render trap. If you emit `AsyncLoading`, the widget tree switches to the loading branch, unmounting `TerminalView`, and xterm loses its render context. The sealed class inside `AsyncData` gives you full UI expressiveness without that risk.

---

## Common Pitfalls

### Pitfall 1: `ref.invalidateSelf()` destroys scrollback

**What goes wrong:** Developer calls `ref.invalidateSelf()` in the `reconnect()` method to "restart" the provider. Riverpod creates a new provider instance, a new `Terminal`, and the scrollback is gone.
**Why it happens:** `invalidateSelf()` is the obvious Riverpod "retry" idiom for simple providers. Here it's wrong because the `Terminal` is stateful and must survive.
**How to avoid:** The `reconnect()` public method calls a private `_runRetryLoop()` method directly — same instance, same `_terminal` field.
**Warning signs:** SnackBar("Reconnected") appears but the terminal is blank.

### Pitfall 2: Timer not cancelled before starting a new one

**What goes wrong:** On a second reconnect attempt, a stale `Timer.periodic` from the first attempt is still running. State receives double `secondsLeft` updates, UI jumps or double-decrements.
**Why it happens:** The countdown timer is created inside the retry loop. If `reconnect()` is called while a timer is running (e.g., user cancels at secondsLeft=3, then taps Retry), the old timer fires into the new state.
**How to avoid:** Store `Timer? _countdownTimer` as a notifier field. Cancel it at the start of `_waitWithCountdown` before creating a new one. Also register `ref.onDispose(_countdownTimer?.cancel)` pattern.
**Warning signs:** Countdown visually jumps (e.g., shows "3s… 2s… 1s… 3s… 2s…" interleaved).

### Pitfall 3: `_isMidSession` flag not reset correctly on dispose/rebuild

**What goes wrong:** Provider is disposed (user navigates away, comes back). On rebuild, `_isMidSession` is a field on the notifier class, which is recreated fresh — but if `reconnect()` is called without going through `build()`, the field may be in an unexpected state.
**Why it happens:** Dart instance fields reinitialise on class creation, but `build()` is not the constructor. Field initialisation happens in the constructor (`_isMidSession = false`), before `build()` runs. This is actually correct behavior — just needs explicit declaration at the field level.
**How to avoid:** Declare `bool _isMidSession = false;` as a class-level field (not local to `build()`). Always set `_isMidSession = false` at the top of `build()`.
**Warning signs:** Manual retry after a navigate-away/navigate-back uses 3 attempts instead of 5.

### Pitfall 4: `AsyncData(SshConnecting(...))` during initial build before terminal exists

**What goes wrong:** The initial `SshConnecting` state is emitted before `_terminal` is created, but the UI's `Stack` tries to read `state.terminal` — `null`.
**Why it happens:** `SshConnecting` doesn't carry a terminal (it's the pre-connection state). The `Stack` switch must correctly handle the case where no terminal widget should render.
**How to avoid:** The `Stack` only renders `TerminalViewWrapper` for variants that carry a `terminal` field (`SshConnected`, `SshReconnecting`, `SshFailed`). For `SshConnecting`, the terminal widget is simply absent — the overlay is the only child.
**Warning signs:** `Null check operator used on a null value` in `TerminalViewWrapper`.

### Pitfall 5: `_client!.done` resolving immediately on retry attempt errors

**What goes wrong:** If `_connectOnce()` throws during TCP connect (before `SSHClient` is fully formed), `done` was never attached. The mid-session watcher from the previous successful connection may fire at the wrong time.
**Why it happens:** `done` is attached per-`SSHClient` instance. Each call to `_connectOnce()` creates a new `SSHClient`. Old `done` callbacks must not overlap with new ones.
**How to avoid:** Clear and re-register the `done` watcher after every successful connection. Use a guard variable (e.g., `int _connectionGeneration`) to ensure stale callbacks don't fire for replaced connections.
**Warning signs:** Mid-session reconnect loop starts immediately after reconnection succeeds (appears to reconnect, then immediately reconnect again).

### Pitfall 6: `_permissionController` and `safeWrite` binding across reconnects

**What goes wrong:** After reconnect, `_sshSession!.stdout` is a new stream, but `safeWrite` closure from the old session is still attached (or not attached at all to the new one).
**Why it happens:** `_connectOnce()` sets up stream listeners per-session. If called again, listeners must be re-registered for the new streams.
**How to avoid:** The `_permissionController` is a broadcast controller — it can have multiple listeners. Each call to `_connectOnce()` `.listen(safeWrite)` on the new session's streams. The old listeners auto-cancel when the old streams close. Verify `_permissionController` is NOT recreated in `_connectOnce()` (it would break existing subscribers).
**Warning signs:** Permission card stops appearing after a reconnect.

---

## Code Examples

### Sealed Class Pattern Matching (Dart 3)

```dart
// Exhaustive switch — compiler error if new variant added and not handled here
// Source: dart.dev/language/patterns#switch-statements-and-expressions
final Widget body = switch (sessionState) {
  SshConnecting(:final attempt, :final maxAttempts, :final secondsLeft) =>
    ReconnectOverlay(attempt: attempt, max: maxAttempts, secondsLeft: secondsLeft,
                     onCancel: () { ... }),
  SshConnected(:final terminal) =>
    TerminalViewWrapper(machineId: machineId, terminal: terminal),
  SshReconnecting(:final terminal, :final attempt, :final maxAttempts, :final secondsLeft) =>
    Stack(children: [
      TerminalViewWrapper(machineId: machineId, terminal: terminal),
      ReconnectBanner(attempt: attempt, max: maxAttempts, secondsLeft: secondsLeft, onCancel: () { ... }),
    ]),
  SshFailed(:final terminal) =>
    Stack(children: [
      TerminalViewWrapper(machineId: machineId, terminal: terminal),
      ReconnectFailedOverlay(onRetry: () { ... }),
    ]),
};
```

### SnackBar post-reconnect (ref.listen pattern)

```dart
// In TerminalScreen — detect reconnection by watching for SshConnected after SshReconnecting
// Source: riverpod.dev/docs/concepts2/reading_providers#using-reflisten-to-react-to-state-changes
ref.listen(sshSessionProvider(machineId), (prev, next) {
  final prevState = prev?.value;
  final nextState = next.value;

  if (prevState is SshReconnecting && nextState is SshConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reconnected'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  if (prevState is SshConnecting && nextState is SshFailed) {
    // All initial attempts exhausted — show Retry button via state (already shown via Stack)
  }
});
```

### AnimatedContainer banner (height animation)

```dart
// Collapses to height 0 when not reconnecting — smooth slide-in/out
// Source: api.flutter.dev/flutter/widgets/AnimatedContainer-class.html
final isReconnecting = sessionState is SshReconnecting;
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  height: isReconnecting ? 40.0 : 0.0,
  color: Theme.of(context).colorScheme.errorContainer,
  child: isReconnecting
    ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Connection lost · Attempt ${(sessionState as SshReconnecting).attempt}/'
                 '${(sessionState as SshReconnecting).maxAttempts} · '
                 'Retry in ${(sessionState as SshReconnecting).secondsLeft}s'),
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      )
    : const SizedBox.shrink(),
)
```

---

## Runtime State Inventory

> This phase is not a rename/refactor/migration phase — no stored data, external service config, or OS-registered state is affected. Omitted.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@Riverpod(retry: false)` (invalid boolean) | `@Riverpod(retry: _noRetry)` where `_noRetry` is a top-level function | Riverpod 3.0 introduced function-based retry | Planning must use function reference, not boolean |
| `AsyncError` on connection drop | `AsyncData(SshFailed(terminal))` | Phase 4 decision | Terminal never unmounts; `ref.listen` SnackBar pattern replaces Dialog |
| Static retry function in annotation | Top-level function only | riverpod_generator 4.x bug | `PrefixedIdentifierImpl` cast error in build_runner for static methods |
| `done.catchError()` routing to `AsyncError` | `done.then(..., onError: ...)` routing to mid-session retry | Phase 4 | Drop triggers reconnection rather than error display |

**Deprecated/outdated:**
- `state = AsyncError(e, StackTrace.current)` after mid-session drop: replaced by `state = AsyncData(SshReconnecting(...))` in Phase 4
- `SshSession.maxAttempts = 3` constant: replaced by two separate constants (`_initialMaxAttempts = 5`, `_midSessionMaxAttempts = 3`)
- Dialog on connection failure (`terminal_screen.dart` lines 53-78): replaced by sealed class UI in Stack

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `reconnect()` public method should keep `_isMidSession` as-is rather than resetting to `false` (manual retry preserves the session context) | Architecture Patterns Pattern 3 | If wrong, manual retry after mid-session exhaustion uses 5 attempts instead of 3, or vice versa — minor UX difference, not a crash |
| A2 | `Terminal(maxLines: 2000)` keeps the same max after promotion to instance field (no change in xterm API needed) | Standard Stack | Confirmed by codebase inspection — xterm 4.0.0 Terminal constructor unchanged |
| A3 | `_permissionController.broadcast()` handles multiple `listen()` calls across reconnects without recreating the controller | Pitfall 6 | If xterm's stdout stream close triggers auto-cancel of the permission listener, permission detection breaks after reconnect. Needs test |

---

## Open Questions

1. **Manual retry attempt count**
   - What we know: `reconnect()` is called after all auto-retries are exhausted. Context shows initial=5 and mid-session=3. The `reconnect()` method re-runs the retry loop.
   - What's unclear: Should manual retry after initial exhaustion attempt 5 more times? Or a fixed 1-attempt (the RECON-04 spec says "attempt one more connection manually")?
   - Recommendation: RECON-04 says "attempt one more" — implement `reconnect()` as a single attempt (1 try, no loop), then emit `SshConnected` or `SshFailed`. Planner should confirm with user if needed.

2. **`_permissionController` across reconnects**
   - What we know: `_permissionController` is created once; `safeWrite` closure is re-registered per `_connectOnce()`. Old listeners auto-cancel when the old SSH session stream closes.
   - What's unclear: Whether broadcast stream listeners from old sessions leave dangling references.
   - Recommendation: Add a `StreamSubscription` field for both stdout and stderr, cancel them explicitly at the start of each `_connectOnce()` call before re-subscribing.

---

## Environment Availability

> No external tools beyond `build_runner` (already in dev_dependencies) are needed. All runtime dependencies are already in `pubspec.yaml`.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `build_runner` | Regenerate `.g.dart` after `@Riverpod` annotation change | ✓ | in dev_dependencies | — |
| `dart:async` Timer | Countdown mechanism | ✓ | SDK (always available) | — |

---

## Validation Architecture

> `nyquist_validation` is explicitly `false` in `.planning/config.json`. Section omitted per config.

---

## Security Domain

> `security_enforcement` not set in config (absent = enabled). Phase 4 changes are purely in-process state management — no new network endpoints, no credential handling, no new storage access, no user input parsing. The reconnect path reuses existing `SSHClient` construction (identical to Phase 1 path). No new ASVS categories are introduced.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No new auth surface | Existing dartssh2 auth unchanged |
| V5 Input Validation | No new user input | Retry/cancel are button taps, not text fields |
| V6 Cryptography | No change | `flutter_secure_storage` unchanged |

**Threat pattern:** The reconnect loop connects with the same stored credentials. If credentials were revoked server-side, retries will fail repeatedly — this is the correct behavior (exhaust attempts, show failure). No credentials are logged or exposed in state.

---

## Sources

### Primary (HIGH confidence)
- Codebase: `lib/features/terminal/providers/ssh_session_provider.dart` — current implementation baseline
- Codebase: `lib/features/terminal/providers/ssh_session_provider.g.dart` — confirms `retry: null` is already generated
- Codebase: `pubspec.yaml` — confirms no new packages needed
- `.planning/phases/04-reconexi-n-robusta/04-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- [Riverpod retry docs](https://riverpod.dev/docs/concepts2/retry) — confirmed `retry` parameter type is `Duration? Function(int, Object)?`
- [Riverpod_annotation pub.dev API](https://pub.dev/documentation/riverpod_annotation/latest/riverpod_annotation/Riverpod-class.html) — confirmed parameter type signature
- [riverpod.dev/docs/3.0_migration](https://riverpod.dev/docs/3.0_migration) — confirmed ProviderException wrapping, retry function pattern
- [riverpod.dev/docs/whats_new](https://riverpod.dev/docs/whats_new) — confirmed retry is function-based in Riverpod 3
- [dartssh2 SSHClient API](https://pub.dev/documentation/dartssh2/latest/dartssh2/SSHClient-class.html) — confirmed `done` Future behavior

### Tertiary (supporting, LOW/MEDIUM confidence)
- [GitHub issue #4332](https://github.com/rrousselGit/riverpod/issues/4332) — static function reference bug in riverpod_generator (confirmed open bug)
- dart.dev/language/class-modifiers#sealed — Dart 3 sealed class syntax [ASSUMED: training knowledge, not verified in this session]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages, codebase verified
- Annotation syntax correction: HIGH — verified via pub.dev official API docs + official Riverpod docs
- Architecture patterns: HIGH — sealed class approach locked in CONTEXT.md, Dart 3 pattern matching is stable
- Pitfalls: HIGH (structural) / MEDIUM (Pitfall 6 streams) — codebase inspection + experience
- Code examples: MEDIUM — patterns are correct but exact field names will be confirmed during implementation

**Research date:** 2026-06-20
**Valid until:** 2026-09-20 (stable APIs — riverpod_annotation and dartssh2 are not fast-moving at these versions)
