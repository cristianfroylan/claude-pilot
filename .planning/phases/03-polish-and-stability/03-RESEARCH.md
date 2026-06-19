# Phase 3: Polish and Stability - Research

**Researched:** 2026-06-19
**Domain:** Flutter mobile hardening — SSH keepalive, PTY resize, SafeArea, layout overflow
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**PTY Resize**
- Root cause: `LayoutBuilder` fires on widget rebuild, but keyboard-triggered inset changes may not always propagate through to the terminal's `LayoutBuilder` subtree in all Flutter versions
- Fix: Wrap `TerminalScreen`'s `Scaffold` body in a `MediaQuery`-aware widget that explicitly listens to `viewInsets` changes and forces a `TerminalViewWrapper` rebuild when the keyboard height changes
- Orientation: Allow both portrait and landscape; PTY cols/rows formula already adapts via `LayoutBuilder` — no change needed to the formula itself
- Keep `resizeToAvoidBottomInset: true` on Scaffold (already set in Phase 1)

**SSH Keepalive**
- Add `keepAliveInterval: const Duration(seconds: 30)` to `SSHClient` constructor in `ssh_session_provider.dart`
- This is the standard SSH keepalive mechanism and prevents iOS from silently dropping the TCP connection during brief backgrounding
- Android: no additional work needed for LAN connections

**Visual Polish**
- Add `SafeArea` wrapper around the Scaffold body (above AppBar) if not already present — prevents notch/status-bar clipping on iOS
- Audit `PermissionCard` for text overflow: the 80-char truncation should prevent long-line issues, but add `overflow: TextOverflow.ellipsis` to the excerpt `Text` widget
- Audit `VoiceBottomSheet` for small-screen overflow: ensure the sheet is scrollable if content exceeds available height
- `InputBar` on small screens: the Command panel's `ConstrainedBox(maxHeight: 240)` from Phase 1 already prevents overflow; confirm it works in landscape
- Font: xterm.dart uses its own monospace renderer — no Flutter font override needed; confirm it renders correctly on iOS (no tofu/fallback characters)
- Remove any remaining debug artifacts (e.g., excessive rebuild logs)

### Claude's Discretion
- Exact `keepAliveInterval` value (30s is standard; adjust if testing reveals a better value)
- Whether to add `countOfAvailableLines` to the terminal scrollback limit or leave at 2000
- Exact `SafeArea` placement (top only vs all sides)

### Deferred Ideas (OUT OF SCOPE)
- Reconnect on drop (RECON-01..03) — v2
- iOS keepAlive beyond 30s (background app refresh) — v2
- Custom theme settings — v2
- Multiple simultaneous sessions — v2
</user_constraints>

---

## Summary

Phase 3 is a cross-cutting stability pass with no new user-facing features. The five concrete changes are: SSH keepalive interval override, PTY resize on keyboard/rotation, `SafeArea` on `TerminalScreen`, `PermissionCard` text overflow guard, and `VoiceBottomSheet` scroll wrapper. Research confirmed the exact API signatures, current widget states, and one important pre-existing fact that changes the keepalive implementation intent.

**Primary finding — keepalive already active:** dartssh2 2.18.0 `SSHClient` defaults `keepAliveInterval` to `const Duration(seconds: 10)`. The current `ssh_session_provider.dart` does not pass `keepAliveInterval`, so the 10-second default is already active. The CONTEXT.md decision to "add `keepAliveInterval: const Duration(seconds: 30)`" will change the interval from 10s to 30s — the intent documented in CONTEXT.md (prevent iOS TCP drop) is correct, but 30s is less aggressive than the existing default. The planner should add the explicit parameter as specified by the user.

**Primary finding — PTY resize already partially wired:** `TerminalViewWrapper` uses `LayoutBuilder` with `addPostFrameCallback`. `LayoutBuilder` fires when its parent constraints change — this includes both keyboard-triggered `viewInsets` changes (because `Scaffold` with `resizeToAvoidBottomInset: true` shrinks the body, changing `LayoutBuilder` constraints) and device rotation (which changes the viewport dimensions). The concern in CONTEXT.md about `viewInsets` not propagating is a valid edge case in some Flutter versions; the fix (explicit `MediaQuery` dependency) is the correct defense.

**Primary finding — SafeArea absent:** No `SafeArea` exists anywhere in `terminal_screen.dart`. The `Scaffold` body is a bare `Column`. Adding `SafeArea` to the body protects against notch/home-indicator overlap on both iOS and Android without interfering with the AppBar (which handles its own safe area insets automatically).

**Primary finding — PermissionCard overflow already handled:** `PermissionCard` already has `overflow: TextOverflow.ellipsis` on the `Text` widget (line 57 of `permission_card.dart`). No change needed here — the task is a verify-and-confirm, not a code edit.

**Primary finding — VoiceBottomSheet missing scroll:** `VoiceBottomSheet` uses `mainAxisSize: MainAxisSize.min` on a `Column` with a `SelectableText` transcript block. It already accounts for keyboard inset via `viewInsets.bottom` padding. On very small screens or with long transcripts, the column could overflow. A `SingleChildScrollView` wrapper is the correct fix per CONTEXT.md.

**Primary recommendation:** Five targeted edits; the largest is the `MediaQuery`-listener pattern in `TerminalScreen` body. All other changes are single-property or single-wrapper additions.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SSH keepalive | Provider (dart) | — | `SSHClient` lives in `SshSession` notifier; keepalive is a transport-layer concern |
| PTY resize on keyboard | Widget (TerminalViewWrapper) | Provider (dart) | LayoutBuilder triggers resize callback; provider executes `resizeTerminal` |
| PTY resize on rotation | Widget (TerminalViewWrapper) | — | LayoutBuilder fires on constraint change from rotation — same code path |
| SafeArea | Widget (TerminalScreen) | — | Layout concern, belongs at the screen/Scaffold body level |
| PermissionCard overflow | Widget (PermissionCard) | — | Text rendering property, single widget concern |
| VoiceBottomSheet scroll | Widget (VoiceBottomSheet) | — | Layout wrapper, single widget concern |

---

## Standard Stack

### Core (already in pubspec.yaml — no new dependencies)

| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `dartssh2` | 2.18.0 | SSH transport + keepalive | `keepAliveInterval` confirmed in source [VERIFIED: pub-cache source] |
| `xterm` | 4.0.0 | Terminal renderer + keyboard events | `TerminalView.autofocus`, `hardwareKeyboardOnly` confirmed [VERIFIED: pub-cache source] |
| `flutter_riverpod` | 3.3.1 | State management | No changes needed this phase |
| `flutter` | >=3.38.0 | Framework + `SafeArea`, `LayoutBuilder`, `MediaQuery` | Standard widgets confirmed [ASSUMED] |

**No new packages to install this phase.** All changes are to existing code.

---

## Package Legitimacy Audit

No packages are added in this phase. This section is not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
Device rotation / keyboard appear
        |
        v
Scaffold (resizeToAvoidBottomInset: true)
        |
        v
SafeArea (body wrapper) — NEW in Phase 3
        |
        v
Column
  ├── Expanded
  │     └── MediaQuery listener (viewInsets observer) — NEW in Phase 3
  │               |
  │               v
  │         TerminalViewWrapper (LayoutBuilder)
  │               |
  │               v (constraints change → postFrameCallback)
  │         SshSession.resizeTerminal(cols, rows)
  │               |
  │               v
  │         SSHSession.resizeTerminal() → dartssh2 PTY resize packet
  │
  ├── AnimatedSwitcher → PermissionCard (overflow: ellipsis — already set)
  └── InputBar (ConstrainedBox maxHeight: 240 for command panel)

SSHClient (background)
  └── keepAliveInterval: Duration(seconds: 30) — CHANGED from default 10s
        |
        v (every 30s)
  SSH Global Request "keepalive@openssh.com" → server → prevents TCP drop

VoiceBottomSheet (modal)
  └── SingleChildScrollView wrapper — NEW in Phase 3
        └── Column (mainAxisSize: min)
```

### Recommended Project Structure

No structural changes. All edits are within existing files:

```
lib/features/terminal/
├── providers/
│   └── ssh_session_provider.dart    # keepAliveInterval parameter
├── screens/
│   └── terminal_screen.dart         # SafeArea + MediaQuery body wrapper
├── widgets/
│   ├── terminal_view_wrapper.dart   # optional: explicit key if needed
│   ├── permission_card.dart         # VERIFY ONLY — already has ellipsis
│   ├── voice_bottom_sheet.dart      # SingleChildScrollView wrapper
│   └── input_bar.dart               # VERIFY ONLY — ConstrainedBox landscape
```

### Pattern 1: SSH keepAliveInterval Override

**What:** Pass explicit `keepAliveInterval` to `SSHClient` constructor to override the 10s default with 30s.

**When to use:** Any `SSHClient` construction where session longevity during iOS backgrounding is needed.

**Critical detail:** dartssh2 2.18.0 already defaults to 10s. The user's decision is to set 30s explicitly. The parameter name is `keepAliveInterval` (camelCase, `Duration?`). Setting `null` disables keepalive entirely — do NOT do that.

```dart
// Source: dartssh2-2.18.0/lib/src/ssh_client.dart (pub-cache, verified)
_client = SSHClient(
  await SSHSocket.connect(host, port),
  username: username,
  onPasswordRequest: () => password ?? '',
  keepAliveInterval: const Duration(seconds: 30), // override default 10s
);
```

### Pattern 2: MediaQuery viewInsets Listener for PTY Resize

**What:** Wrap the `TerminalViewWrapper` in a widget that rebuilds explicitly when `viewInsets.bottom` changes, ensuring `LayoutBuilder` receives updated constraints even if the propagation path is interrupted.

**When to use:** When `Scaffold` with `resizeToAvoidBottomInset: true` may not reliably propagate inset changes down to a nested `LayoutBuilder`.

**Key insight:** `MediaQuery.of(context)` in a `build` method creates a dependency — when `MediaQuery` updates (keyboard appears/disappears, rotation), Flutter rebuilds the widget. This guarantees the `LayoutBuilder` subtree sees new constraints.

```dart
// Pattern: read viewInsets in the build method to create rebuild dependency
// Source: Flutter docs (flutter.dev/ui/adaptive-responsive/safearea-mediaquery) [CITED]
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Reading viewInsets.bottom here creates a MediaQuery dependency.
  // When keyboard appears/disappears, this widget rebuilds, which rebuilds
  // TerminalViewWrapper's LayoutBuilder with the updated constraints.
  final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

  return TerminalViewWrapper(
    key: ValueKey(keyboardHeight), // force subtree rebuild on height change
    machineId: machineId,
    terminal: terminal,
  );
}
```

**Alternative (also valid):** Use a `ValueKey(keyboardHeight)` on `TerminalViewWrapper` to force a full subtree rebuild rather than relying on constraint propagation. The CONTEXT.md decision says "explicit MediaQuery dependency" — both approaches satisfy this, but `ValueKey` is more aggressive (full rebuild vs. constraint update).

**LayoutBuilder + rotation:** `LayoutBuilder` fires whenever its parent's constraints change. Device rotation changes the viewport dimensions, which flows through `Scaffold` → `Column` → `Expanded` → `LayoutBuilder`. This is automatic — no `OrientationBuilder` needed. [CITED: flutter.dev/cookbook/design/orientation]

### Pattern 3: SafeArea on Scaffold Body

**What:** Wrap the `Scaffold` `body` content in `SafeArea` to prevent content from appearing under the notch, status bar, or home indicator.

**When to use:** Any full-screen `Scaffold` without a `bottomNavigationBar` that needs notch/bar protection.

**Correct placement:** Inside `body:`, NOT around the `Scaffold` itself. The `AppBar` handles its own safe area; wrapping the full `Scaffold` in `SafeArea` would add double-padding under the AppBar. [CITED: docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery]

```dart
// Source: Flutter official docs (docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery)
body: SafeArea(
  child: Column(
    children: [
      Expanded(child: TerminalViewWrapper(...)),
      // PermissionCard, InputBar...
    ],
  ),
),
```

**Note on sides:** `SafeArea` by default applies to all four sides. For landscape mode where the terminal extends edge-to-edge, `SafeArea(bottom: false, child: ...)` may be preferable to avoid side padding reducing the terminal width. This is in Claude's Discretion per CONTEXT.md.

### Pattern 4: VoiceBottomSheet Scroll Wrapper

**What:** Wrap the `Column` inside `VoiceBottomSheet` in `SingleChildScrollView` to prevent overflow on small screens or with long transcripts.

**When to use:** Bottom sheets with `mainAxisSize: MainAxisSize.min` that contain potentially tall content (transcript text).

**Current state:** `VoiceBottomSheet` already accounts for keyboard via `viewInsets.bottom` padding. The `SelectableText` transcript could push total height past available space on small devices.

```dart
// Source: current voice_bottom_sheet.dart structure, with scroll wrapper added
return Padding(
  padding: EdgeInsets.fromLTRB(
    16, 8, 16,
    16 + MediaQuery.of(context).viewInsets.bottom,
  ),
  child: SingleChildScrollView(           // ADD: prevents overflow on small screens
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // drag handle, heading, transcript container, action row...
      ],
    ),
  ),
);
```

### Anti-Patterns to Avoid

- **`SafeArea` wrapping the full `Scaffold`:** Creates double-padding under the AppBar. Always wrap `body:` content, not the Scaffold itself. [CITED: docs.flutter.dev]
- **`OrientationBuilder` for PTY resize:** Unnecessary; `LayoutBuilder` already fires on rotation. Adding `OrientationBuilder` creates duplicate resize calls without benefit.
- **`keepAliveInterval: null`:** Disables keepalive entirely. Do not pass null. Omitting the parameter uses the 10s default; passing `Duration(seconds: 30)` sets 30s.
- **`ValueKey` on `TerminalViewWrapper` keyed to a continuously changing value:** Keying to `keyboardHeight` (a double) is safe because keyboard height only changes at distinct events. Do not key to `DateTime.now()` or frame counters.
- **`resizeToAvoidBottomInset: false`:** Currently `true` — do not change. Without it, `Scaffold` does not shrink its body for the keyboard, which would break the entire PTY resize chain.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSH keepalive packets | Custom TCP heartbeat timer | `keepAliveInterval` on `SSHClient` | dartssh2 sends SSH Global Request keepalive (RFC 4254); a raw TCP timer won't prevent SSH layer timeouts |
| Keyboard height detection | `WidgetsBindingObserver.didChangeMetrics` | `MediaQuery.of(context).viewInsets.bottom` in `build` | MediaQuery is the Flutter-idiomatic reactive approach; the observer approach is imperative and requires manual widget lifecycle management |
| Notch/bar intrusion detection | `Platform.isIOS` + custom inset math | `SafeArea` | SafeArea handles notch, rounded corners, status bar, and home indicator on both platforms |
| Bottom sheet scroll | Manual height calculation + `SizedBox` | `SingleChildScrollView` | Avoids fragile hard-coded height math |

---

## Common Pitfalls

### Pitfall 1: keepAliveInterval Already Active — Don't Set to null

**What goes wrong:** Developer reads "add keepAliveInterval" and accidentally passes `null` to disable it.
**Why it happens:** The parameter is `Duration?` — `null` is valid Dart.
**How to avoid:** Always pass a positive `Duration`. The change is `keepAliveInterval: const Duration(seconds: 30)`.
**Warning signs:** No keepalive packets visible in SSH server logs after the change.

### Pitfall 2: SafeArea Double-Padding Under AppBar

**What goes wrong:** Wrapping the `Scaffold` (not its body) in `SafeArea` adds a top padding equal to the status bar height, on top of the AppBar's own safe area handling, creating a visible gap.
**Why it happens:** `Scaffold` + `AppBar` already handles the status bar safe area for the AppBar. Adding `SafeArea` at the `Scaffold` level applies it again.
**How to avoid:** Always wrap `body:` content, never the `Scaffold` itself.
**Warning signs:** Visible dark band between status bar and AppBar in the running app.

### Pitfall 3: LayoutBuilder Not Firing on Keyboard (edge case)

**What goes wrong:** On some Flutter versions, the `viewInsets` change from keyboard appearance does not propagate through all layout phases before `LayoutBuilder` is evaluated, so `LayoutBuilder` fires with stale constraints.
**Why it happens:** Frame scheduling; `LayoutBuilder` runs during layout pass, but `MediaQuery` may update in a later pass.
**How to avoid:** Add `MediaQuery.of(context).viewInsets.bottom` read in the parent `build` method (creating a reactive dependency) AND/OR use `ValueKey(keyboardHeight)` on `TerminalViewWrapper` to force a full rebuild.
**Warning signs:** Terminal text does not reflow when keyboard appears — bottom rows hidden under the keyboard.

### Pitfall 4: TerminalView autofocus: true Conflicts with SafeArea

**What goes wrong:** `TerminalView` has `autofocus: true` (current code). Adding `SafeArea` does not affect focus behavior, but the comment in `terminal_view_wrapper.dart` says "autofocus: false — the InputBar TextField owns keyboard focus" while the code says `true`. This is a **stale comment** — the `InputBar` has no `TextField`. The actual input path is: user taps TerminalView → TerminalView takes focus → soft keyboard opens → xterm handles key input. This is correct behavior for a mobile terminal emulator.
**How to avoid:** Do not change `autofocus: true`. Do update the stale comment.
**Warning signs:** Keyboard never appears on terminal tap if `autofocus` is changed to `false`.

### Pitfall 5: SingleChildScrollView + mainAxisSize: min Interaction

**What goes wrong:** `SingleChildScrollView` wrapping a `Column(mainAxisSize: MainAxisSize.min)` can result in the column taking infinite height if `SingleChildScrollView` doesn't have a constrained parent.
**Why it happens:** `SingleChildScrollView` gives its child unbounded height; `mainAxisSize: min` then tries to be as small as possible but with no upper bound.
**How to avoid:** The `VoiceBottomSheet` is shown via `showModalBottomSheet` with `isScrollControlled: true` — the bottom sheet framework constrains the available height. The pattern is safe in this context. Do not add `SingleChildScrollView` to Columns that are inside unconstrained contexts.
**Warning signs:** `RenderBox was not laid out` exceptions.

---

## Code Examples

### keepAliveInterval in SSHClient constructor

```dart
// Source: dartssh2-2.18.0/lib/src/ssh_client.dart (verified in pub-cache)
// Current code (line 81-85 of ssh_session_provider.dart) — BEFORE:
_client = SSHClient(
  await SSHSocket.connect(host, port),
  username: username,
  onPasswordRequest: () => password ?? '',
);

// AFTER — explicit 30s keepalive:
_client = SSHClient(
  await SSHSocket.connect(host, port),
  username: username,
  onPasswordRequest: () => password ?? '',
  keepAliveInterval: const Duration(seconds: 30),
);
```

### MediaQuery viewInsets dependency pattern (TerminalScreen body)

```dart
// Source: Flutter docs pattern for MediaQuery reactive dependency
// In terminal_screen.dart, inside the data: branch of sessionAsync.when():
data: (terminal) {
  // Reading viewInsets.bottom here registers a MediaQuery dependency.
  // When the keyboard shows/hides, this build() re-runs, TerminalViewWrapper
  // gets a new key, and LayoutBuilder fires with updated constraints.
  final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
  return TerminalViewWrapper(
    key: ValueKey(keyboardHeight),
    machineId: machineId,
    terminal: terminal,
  );
},
```

### SafeArea wrapping the Scaffold body

```dart
// Source: docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery [CITED]
// In terminal_screen.dart — wrap the Column in body:
body: SafeArea(
  child: Column(
    children: [
      Expanded(
        child: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (terminal) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            return TerminalViewWrapper(
              key: ValueKey(keyboardHeight),
              machineId: machineId,
              terminal: terminal,
            );
          },
        ),
      ),
      AnimatedSwitcher(...),
      InputBar(machineId: machineId),
    ],
  ),
),
```

### VoiceBottomSheet with SingleChildScrollView

```dart
// Source: current voice_bottom_sheet.dart with scroll wrapper added
return Padding(
  padding: EdgeInsets.fromLTRB(
    16, 8, 16,
    16 + MediaQuery.of(context).viewInsets.bottom,
  ),
  child: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ... existing children unchanged
      ],
    ),
  ),
);
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Manual SSH keepalive (custom Timer) | `keepAliveInterval` on `SSHClient` (dartssh2 built-in) | No code needed beyond the constructor parameter |
| `resizeToAvoidBottomInset` alone for PTY resize | `resizeToAvoidBottomInset` + explicit `MediaQuery.viewInsets` dependency | Guarantees LayoutBuilder fires on keyboard transitions |
| No `SafeArea` (most common mistake in new Flutter apps) | `SafeArea` wrapping `body:` content | Prevents notch/home-indicator overlap |

**Deprecated/outdated:**
- Passing `hardwareKeyboardOnly: true` on `TerminalView` as a workaround for mobile focus issues: not needed; `autofocus: true` with the soft keyboard approach is the correct mobile pattern for xterm.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `LayoutBuilder` fires on device rotation (constraint change path from Scaffold through Expanded) | Architecture Patterns, Pitfalls | If wrong, PTY stays at portrait dimensions in landscape; fix would require `OrientationBuilder` addition |
| A2 | `MediaQuery.of(context).viewInsets.bottom` read in `build()` reliably creates a reactive dependency that triggers rebuild on keyboard show/hide across Flutter >=3.38.0 | Architecture Patterns | If wrong, the `ValueKey` approach (also included) serves as the reliable fallback |
| A3 | `showModalBottomSheet` with `isScrollControlled: true` constrains the child height sufficiently to make `SingleChildScrollView` + `Column(mainAxisSize: min)` safe | Common Pitfalls | If wrong, layout exceptions at runtime when sheet opens |

**A1 and A2 both have in-code fallbacks specified in the plan patterns above, so risk is low even if assumptions are incorrect.**

---

## Open Questions

1. **SafeArea sides in landscape mode**
   - What we know: `SafeArea` with default sides applies to all four edges; in landscape on notched devices, the side insets can reduce terminal width by 30-50px per side.
   - What's unclear: Whether the user prefers full side protection or maximum terminal width in landscape.
   - Recommendation: Default to `SafeArea(child: ...)` (all sides); this is in Claude's Discretion per CONTEXT.md. The planner can note this as a tunable constant.

2. **stale comment in terminal_view_wrapper.dart**
   - What we know: Line 41 says "autofocus: false — the InputBar TextField owns keyboard focus" but the code is `autofocus: true` and `InputBar` has no `TextField`.
   - What's unclear: The comment is misleading but functionally harmless. Whether to update it is a minor housekeeping call.
   - Recommendation: Update the comment as part of Phase 3 polish. No behavior change.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is purely in-app code changes. No new external tools, services, CLIs, runtimes, or databases are required. All dependencies (dartssh2, xterm, flutter_riverpod, flutter) are already installed.

---

## Security Domain

> `security_enforcement` not set to false in config.json — section required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | SSH credentials unchanged — no new auth surface |
| V3 Session Management | no | Keepalive is transport-layer; does not change session auth model |
| V4 Access Control | no | No new access controls introduced |
| V5 Input Validation | no | No new input surfaces; existing SSH text input unchanged |
| V6 Cryptography | no | No new crypto; SSH transport uses dartssh2 defaults |

**Security impact of keepalive change:** Setting `keepAliveInterval: 30s` increases the interval between keepalive packets (was 10s). This is less aggressive, meaning a dropped connection may go undetected for up to 30s before the next missed keepalive triggers an error. No security downside — keepalive packets are standard SSH Global Requests, not new attack surfaces.

**Security impact of SafeArea:** UI-only change. No security implications.

---

## Sources

### Primary (HIGH confidence)
- `dartssh2-2.18.0` pub-cache source at `/home/cristian/.pub-cache/hosted/pub.dev/dartssh2-2.18.0/lib/src/ssh_client.dart` — `keepAliveInterval` field (line 183), default value (line 219), SSHKeepAlive implementation [VERIFIED: pub-cache source]
- `xterm-4.0.0` pub-cache source at `/home/cristian/.pub-cache/hosted/pub.dev/xterm-4.0.0/lib/src/terminal_view.dart` — `autofocus`, `hardwareKeyboardOnly`, `KeyboardVisibilty` (sic) widget [VERIFIED: pub-cache source]
- `lib/features/terminal/providers/ssh_session_provider.dart` — current SSHClient constructor (no keepAliveInterval), resizeTerminal implementation [VERIFIED: codebase]
- `lib/features/terminal/widgets/terminal_view_wrapper.dart` — LayoutBuilder + postFrameCallback pattern [VERIFIED: codebase]
- `lib/features/terminal/screens/terminal_screen.dart` — Scaffold structure, no SafeArea present [VERIFIED: codebase]
- `lib/features/terminal/widgets/permission_card.dart` — `overflow: TextOverflow.ellipsis` already on line 57 [VERIFIED: codebase]
- `lib/features/terminal/widgets/voice_bottom_sheet.dart` — Column without SingleChildScrollView [VERIFIED: codebase]
- `android/app/src/main/AndroidManifest.xml` — `windowSoftInputMode="adjustResize"`, RecognitionService query intent present [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- [Flutter SafeArea docs](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery) — wrap body, not Scaffold [CITED]
- [Flutter orientation cookbook](https://docs.flutter.dev/cookbook/design/orientation) — LayoutBuilder fires on constraint changes [CITED]
- [dartssh2 pub.dev API docs](https://pub.dev/documentation/dartssh2/latest/dartssh2/SSHClient-class.html) — `keepAliveInterval` default confirmed [CITED]

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- keepAliveInterval API: HIGH — verified directly in pub-cache source
- PTY resize LayoutBuilder behavior: HIGH (codebase) + MEDIUM (Flutter docs general) + A1 assumption for rotation
- SafeArea placement: HIGH — Flutter official docs + codebase verification (currently absent)
- PermissionCard overflow: HIGH — already present in codebase; task is verify-only
- VoiceBottomSheet scroll: HIGH — codebase confirms missing wrapper; pattern is standard Flutter

**Research date:** 2026-06-19
**Valid until:** 2026-07-19 (stable APIs; dartssh2 and xterm are pinned in pubspec.yaml)
