# Research Summary — claude-pilot v2.0

**Synthesized:** 2026-06-20
**Sources:** STACK.md · FEATURES.md · ARCHITECTURE.md · PITFALLS.md
**Overall confidence:** HIGH — all four files based on direct codebase inspection + verified package research

---

## Executive Summary

claude-pilot v2.0 extends a working v1.0 Flutter SSH remote control with four power-user features: multi-session tabs, a session start picker, biometric app lock, and robust reconnection with exponential backoff. The v1.0 architecture (dartssh2 + xterm + Riverpod 3 + GoRouter) is solid and carries forward unchanged. v2.0 adds exactly one new package (`local_auth: ^3.0.1`); every other feature is built with existing stack primitives, pure Dart, and Flutter's native widget library.

The most important architectural insight is that the four features are not independent: Feature 4 (Reconnection) introduces a sealed class `SshSessionState` that changes the return type of `sshSessionProvider` from `AsyncValue<Terminal>` to `AsyncValue<SshSessionState>`. This change breaks three existing consumers (TerminalScreen, InputBar, PermissionDetector). Feature 1 (Tabs) then builds on top of this stable type, and any tab consumer that touches `sshSessionProvider` must already be written against `SshSessionState`, not `Terminal`. Building tabs before reconnection forces a second migration pass across everything already built. This dependency drives the build order: Reconnection → Biometric → Picker → Tabs.

The highest-risk pitfalls are all architectural: `autoDispose` silently killing sessions on tab switches, `AsyncLoading` destroying the xterm Terminal scrollback buffer during reconnection, and biometric platform config (Info.plist + FlutterFragmentActivity) crashing the app silently before any Dart code runs. None of these are subtle logic bugs — they are missed setup steps or provider lifecycle mismatches that cause complete feature failure. All are preventable by doing platform config first and following the patterns documented in PITFALLS.md.

---

## Key Findings

### From STACK.md

- **One new package only:** `local_auth: ^3.0.1` (flutter.dev publisher, verified). All other v2.0 features use existing packages or pure Dart.
- **Android minSdk rises from 23 to 24** due to `local_auth` requiring API 24. Set `minSdk = 24` explicitly in `build.gradle.kts` — Flutter's default resolves to 21 and will not catch this.
- **Tabs use native Flutter `TabController` + `IndexedStack`**, not a package. `go_router StatefulShellRoute` was rejected because SSH sessions are created at runtime — static branch counts are incompatible. `dynamic_tabbar` was rejected as stale (18 months, unverified).
- **Reconnection backoff uses pure Dart `Future.delayed` loop**, not the `retry` package (google.dev). The `retry` package hides internal state; the UI needs attempt count, delay countdown, and a cancel signal — all require external state control that `retry` cannot expose.
- **Folder listing uses SFTP `client.sftp().listdir(path)`**, not shell `ls` parsing. Structured `SftpName` objects eliminate parsing fragility (spaces in names, symlinks, color codes, locale differences).
- **Complete v2.0 pubspec delta:** add `local_auth: ^3.0.1` and change `minSdk = 24` in `build.gradle.kts`. No other changes.

### From FEATURES.md

**Must-have for v2.0 (table stakes per feature):**

| Feature | Non-negotiable behaviors |
|---------|--------------------------|
| Tabs | Tab strip always visible; machine name on each tab; tap switches without disconnecting; close button per tab; add-tab button; dead tab stays open (red dot), does not disrupt others |
| Session Picker | Sheet appears after SSH is ready (not before); "Start blank" always one dismiss away; configured folders shown first; tapping a folder sends `cd <path>\n` |
| Biometric Lock | Cold launch gate; OS native dialog (no custom UI); PIN fallback via `biometricOnly: false`; re-lock after background grace period; gate machine edit/delete |
| Reconnection | Attempt counter + countdown shown; cancel button throughout; manual retry after exhaustion; mid-session reconnect shows inline banner (not modal); Terminal scrollback preserved on success |

**Defer to v3.0:**
- Tab reorder by long-press drag (high complexity, low frequency)
- Git branch display in session picker (high complexity, good v3 candidate)
- Swipe left/right on terminal body to switch tabs (conflicts with xterm horizontal scroll)
- Push notifications on Claude finish (background execution limits)

**Anti-features confirmed unchanged:** No SFTP file browser, no recursive directory browser, no session recording, no per-connection biometric re-prompts, no auto-send on voice transcription.

### From ARCHITECTURE.md

**Build order conflict resolved:**

FEATURES.md suggested "Tabs first" (biggest structural change). ARCHITECTURE.md analysis shows "Reconnection first" because `SshSessionState` sealed class change breaks ALL downstream consumers, including the tab consumers that do not exist yet. The correct sequence:

```
Phase A (must be sequential):
  Feature 4: Reconnection — establishes SshSessionState sealed class
  All three existing consumers updated: TerminalScreen, InputBar, PermissionDetector

Phase B (independent, order flexible):
  Feature 3: Biometric Lock — new providers + LockScreen + app.dart wrapper
  Feature 2: Session Picker — Machine model extension + new screen/route

Phase C (must come last):
  Feature 1: Tabs — builds ShellRoute on stable SshSessionState; absorbs app.dart changes from B
```

**Key architectural patterns:**
- `SshSession.build()` emits `AsyncData(SshConnecting(...))` during retry — replaces `AsyncLoading` which would wipe the xterm Terminal
- `ref.keepAlive()` in `SshSession.build()` + `keepAliveLink.close()` on tab close — explicit control over session lifetime
- `TabsNotifier` (Riverpod `@Riverpod(keepAlive: true)`) holds `Map<String, KeepAliveLink>` as private state
- `biometricAuthProvider` declared `@Riverpod(keepAlive: true)` — auth state must be global singleton
- Biometric gate uses widget-layer Consumer wrapping `MaterialApp.router`, not GoRouter redirect (redirect is synchronous, biometric auth is async)
- `SessionStartScreen` watches `sshSessionProvider(id)` to start the connection early; terminal inherits the already-connected session (no double-connect)

**File change summary:**

| Feature | New files | Key modified files |
|---------|-----------|-------------------|
| Reconnection | `ssh_session_state.dart` | `ssh_session_provider.dart`, `terminal_screen.dart`, `permission_detector_provider.dart`, `input_bar.dart` |
| Biometric | `biometric_service.dart`, `biometric_auth_provider.dart`, `biometric_auth_state.dart`, `lock_screen.dart` | `app.dart`, `add_edit_machine_screen.dart` |
| Picker | `session_start_screen.dart`, `folder_list_tile.dart` | `machine.dart`, `add_edit_machine_screen.dart`, `app.dart`, `machine_list_screen.dart` |
| Tabs | `tabs_notifier.dart`, `tabs_state.dart`, `tab_shell.dart`, `tab_bar_strip.dart` | `app.dart`, `machine_list_screen.dart`, `ssh_session_provider.dart` |

### From PITFALLS.md

**Critical pitfalls (cause complete feature failure if missed):**

1. **autoDispose kills sessions on tab switch** — Use `StatefulShellRoute` + `ref.keepAlive()` in `SshSession.build()`. Call `ref.invalidate(sshSessionProvider(id))` on explicit tab close to prevent resource leaks.

2. **`AsyncLoading` destroys Terminal scrollback** — During reconnection, never emit `AsyncLoading`. Use `AsyncData(SshReconnecting(...))` to keep the xterm `Terminal` object alive. The `Terminal` instance must be reused across SSH transport rebuilds.

3. **`NSFaceIDUsageDescription` missing causes silent crash on iOS** — Add to `Info.plist` before writing any `local_auth` code. The OS crashes the app at the native layer; no Dart exception is catchable.

4. **`MainActivity` must extend `FlutterFragmentActivity`** — `BiometricPrompt` requires a `FragmentActivity` context. With `FlutterActivity`, the biometric dialog silently fails to appear (not a crash, harder to debug).

5. **Riverpod 3 auto-retry conflicts with custom retry loop** — Disable with `@Riverpod(retry: false)` on `SshSession`. Without this, Riverpod's built-in exponential backoff stacks with the custom loop.

6. **`biometricAuthProvider` must be `keepAlive: true`** — An `autoDispose` auth provider silently resets to "locked" whenever no widget is watching it during navigation transitions.

**Moderate pitfalls to prevent per phase:**
- Picker: await `client.authenticated` before SFTP; `try/finally sftp.close()` after `listdir`; store `_startDirectory` in notifier so reconnection re-applies `cd`
- Reconnection: guard every `await` with `if (_disposed) return`; cancel timers in `ref.onDispose` before creation
- Integration: sequence on `AppLifecycleState.resumed` as lock → authenticate → reconnect (single lifecycle observer, not two racing)

---

## Implications for Roadmap

### Recommended Phase Structure

**Phase 1: Reconnection Foundation**

Rationale: Changes `sshSessionProvider` return type from `Terminal` to `SshSessionState`. Every other v2.0 consumer depends on this type. Doing this first means all subsequent features build against the stable union type.

Delivers: exponential backoff (2s→4s→8s→16s→30s, max 8 attempts), inline reconnect banner preserving Terminal scrollback, attempt counter + countdown + cancel, `SshConnecting / SshConnected / SshReconnecting / SshFailed` sealed class.

Must-avoid pitfalls: T4-01 (timer not cancelled on dispose), T4-02 (async race after dispose), T4-03 (AsyncLoading wipes Terminal), T4-05 (Riverpod 3 auto-retry double loop).

Files: `ssh_session_state.dart` (new), `ssh_session_provider.dart`, `terminal_screen.dart`, `permission_detector_provider.dart`, `input_bar.dart`.

Research flag: NONE — pattern fully specified in ARCHITECTURE.md with verified Riverpod 3 API.

---

**Phase 2: Biometric Lock**

Rationale: Fully orthogonal to Reconnection (no `SshSessionState` involvement). Should be built before Tabs because both Biometric and Tabs modify `app.dart` — doing Biometric before Tabs lets the Tabs phase absorb the biometric Consumer wrapper cleanly.

Platform config required before any code: add `NSFaceIDUsageDescription` to `Info.plist`, add `USE_BIOMETRIC` to `AndroidManifest.xml`, change `MainActivity` to extend `FlutterFragmentActivity`, set `minSdk = 24` in `build.gradle.kts`.

Delivers: cold launch gate, re-lock after background grace period (default 10 min via `WidgetsBindingObserver`), machine edit/delete gates, device-unavailable degradation.

Must-avoid pitfalls: T3-01 (Info.plist crash), T3-02 (FlutterFragmentActivity), T3-04 (re-lock not automatic), T3-05 (keepAlive: true required), T3-06 (stickyAuth / persistAcrossBackgrounding).

Files: 4 new files under `lib/features/auth/` and `lib/core/services/`; modify `app.dart`, `add_edit_machine_screen.dart`.

Research flag: LOW — `local_auth 3.0.1` API verified. Note: PITFALLS T3-06 references `stickyAuth` (old 2.x name); verify current 3.0.1 uses `persistAcrossBackgrounding` as documented in STACK.md.

---

**Phase 3: Session Start Picker**

Rationale: Extends `Machine` model with `workingFolders` (backward-compatible JSON field). Adds a new route and screen. Does not touch `SshSessionState`. Sequential after Phase 2 (both touch `add_edit_machine_screen.dart` and `app.dart`).

Delivers: bottom sheet after SSH connects (not before), configured folder list, SFTP `listdir` fallback when no folders configured, `cd <path>\n` sent as first shell command.

Must-avoid pitfalls: T2-01 (await `client.authenticated`), T2-02 (SFTP not ls), T2-03 (store `_startDirectory` for reconnection), T2-04 (close SFTP after listdir).

Files: 2 new files under `lib/features/session_start/`; modify `machine.dart`, `add_edit_machine_screen.dart`, `app.dart`, `machine_list_screen.dart`.

Research flag: NONE for configured-folders path. SFTP `listdir` is confirmed dartssh2 API.

---

**Phase 4: Multi-Session Tabs**

Rationale: Largest structural change in v2.0 — rewrites `app.dart` from push-based routes to `ShellRoute` + `IndexedStack`. Must come last: absorbs `app.dart` changes from Phases 2 and 3; consumes `SshSessionState` from Phase 1; modifies `machine_list_screen.dart` which was also touched by Phase 3.

Delivers: dynamic tab strip, independent SSH session per tab via `.family` + `ref.keepAlive()`, connection-state dot per tab, add-tab and close-tab controls.

Must-avoid pitfalls: T1-01 (autoDispose kills sessions), T1-03 (SSHClient leak on tab close), T1-04 (push route disposes all sessions), I-01 (biometric + reconnect race on resume), I-03 (SSH session limit — test with `who` on server).

Files: 4 new files under `lib/features/tabs/`; modify `app.dart`, `machine_list_screen.dart`, `ssh_session_provider.dart`.

Research flag: MEDIUM — `StatefulShellRoute` + Riverpod 3 TickerMode interaction (T1-02) should be verified on a physical device before finalizing the tab architecture. Pattern is documented but has known edge cases in go_router GitHub issues.

---

### Final Build Order

```
Phase 1: Reconnection  — SshSessionState foundation; enables all downstream consumers
Phase 2: Biometric     — orthogonal; platform config done here; app.dart wrapped before Tabs
Phase 3: Picker        — Machine model + new route; app.dart additions absorbed by Tabs
Phase 4: Tabs          — structural rewrite; absorbs all prior app.dart changes; builds on stable types
```

This order differs from FEATURES.md recommendation (1→4→2→3). ARCHITECTURE.md type-dependency analysis is authoritative: Reconnection must precede Tabs, not follow it.

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Stack (packages) | HIGH | All packages verified via pub.dev + Context7; one new package with full API documentation |
| Features (scope) | HIGH | Spec explicit; table stakes vs differentiators clearly separated; anti-features confirmed |
| Architecture (Phases 1-3) | HIGH | Based on direct codebase inspection of all relevant files |
| Architecture (Phase 4 tabs) | MEDIUM | ShellRoute + Riverpod 3 TickerMode interaction documented but has known edge cases |
| Pitfalls (critical) | HIGH | Platform facts or confirmed bugs with reproducible symptoms |
| Pitfalls (integration) | MEDIUM | Sequencing depends on final implementation choices |

**Gaps requiring attention during planning:**

1. **Riverpod 3 `@Riverpod(retry: false)` annotation syntax** — PITFALLS.md flags this as needing verification. The annotation API for disabling auto-retry may differ from the snippet shown.

2. **`StatefulShellRoute.indexedStack` + Riverpod 3 TickerMode** — Verify on physical device during Phase 4 planning. Pitfall T1-02 documents this as acceptable behavior (buffered catch-up on tab return) but edge cases exist.

3. **`stickyAuth` vs `persistAcrossBackgrounding` naming** — PITFALLS T3-06 uses `stickyAuth: true` but STACK.md documents the 3.0.0 breaking change to `persistAcrossBackgrounding`. Confirm current 3.0.1 API name before Phase 2 implementation.

---

## Sources (aggregated)

**Packages verified via pub.dev + Context7:**
- dartssh2 2.18.0: pub.dev/packages/dartssh2 · github.com/TerminalStudio/dartssh2
- xterm 4.0.0: pub.dev/packages/xterm
- flutter_riverpod 3.3.2: pub.dev/packages/flutter_riverpod
- flutter_secure_storage 10.3.1: pub.dev/packages/flutter_secure_storage
- speech_to_text 7.4.0: pub.dev/packages/speech_to_text
- shared_preferences 2.5.5: pub.dev/packages/shared_preferences
- local_auth 3.0.1: pub.dev/packages/local_auth (NEW in v2.0)

**Architecture sources:**
- Direct codebase inspection: `app.dart`, `machine.dart`, `ssh_session_provider.dart`, `terminal_screen.dart`, `permission_detector_provider.dart`, `input_bar.dart`, `machine_list_screen.dart`, `main.dart`
- Riverpod 3 docs: riverpod.dev/docs/concepts2/auto_dispose, riverpod.dev/docs/whats_new
- GoRouter docs: ShellRoute, StatefulShellRoute.indexedStack
- Riverpod GitHub Discussion #4293 (autoDispose after first await)

**Feature sources:**
- Chrome mobile tab management (Android + iOS docs)
- Claude Desktop session picker pitfalls: github.com/anthropics/claude-code/issues/30642, /56688
- Mobile approval system: dev.to/coa00/how-i-built-a-mobile-approval-system-for-claude-code

**Pitfall sources:**
- dartssh2 GitHub Issue #86 (SSHStateError on transport close)
- flutter_secure_storage GitHub Issue #1037 (minSdkVersion enforcement)
- local_auth flutter/flutter GitHub Issues #108945, #112796
- Apple Developer Forums (iOS background TCP suspension)
- Android biometric auth docs: developer.android.com/identity/sign-in/biometric-auth
- StatefulShellRoute go_router GitHub issues #150837, #164187
