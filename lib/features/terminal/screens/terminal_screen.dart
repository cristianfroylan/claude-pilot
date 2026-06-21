import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../machines/providers/machines_provider.dart';
import '../models/ssh_session_state.dart';
import '../providers/permission_detector_provider.dart';
import '../providers/ssh_session_provider.dart';
import '../widgets/input_bar.dart';
import '../widgets/permission_card.dart';
import '../widgets/reconnect_banner.dart';
import '../widgets/reconnect_overlay.dart';
import '../widgets/session_picker_sheet.dart';
import '../widgets/terminal_view_wrapper.dart';

/// TerminalScreen — SSH terminal view for a single machine.
///
/// Pure terminal widget — no AppBar. The AppBar and tab strip are owned by
/// SessionsScreen which embeds TerminalScreen inside an IndexedStack.
///
/// The isActive flag gates SnackBar emission for background tabs (SESS-04):
/// only the active tab shows the 'Could not connect' SnackBar. The status dot
/// on the tab chip changes color independently via sshSessionProvider state.
///
/// The body switches on AsyncValue<SshSessionState>. States carrying a terminal
/// (SshConnected, SshReconnecting, SshFailed) render TerminalViewWrapper to
/// keep the xterm PTY mounted and scrollback preserved (RECON-05).
class TerminalScreen extends ConsumerStatefulWidget {
  final String machineId;
  final bool isActive; // gates SnackBar emission for background tabs (SESS-04)

  const TerminalScreen({super.key, required this.machineId, this.isActive = true});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  // PICK-01: guard prevents picker from re-appearing on mid-session reconnect
  // (Pitfall 1 in RESEARCH.md). Reset only when ConsumerState is reconstructed
  // (i.e., user navigates away and opens a new session).
  bool _pickerShown = false;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sshSessionProvider(widget.machineId));

    // Watch the permission detector — emits the matched line or null.
    // Use .asData?.value — .valueOrNull is not available in the installed Riverpod version.
    final permissionLine =
        ref.watch(permissionDetectorProvider(widget.machineId)).asData?.value;

    // Retrieve machine metadata for display name.
    // Uses .value (nullable) — valueOrNull not available in installed Riverpod version.
    final machines = ref.watch(machineProvider).value;
    final machine =
        machines?.where((m) => m.id == widget.machineId).firstOrNull;
    final machineName = machine?.name ?? 'Terminal';

    // Transition listener: fire SnackBar on SshReconnecting→SshConnected (RECON-05 "Reconnected")
    // and keep the SshFailed notification for initial-connect exhaustion. No AlertDialog.
    ref.listen(sshSessionProvider(widget.machineId), (prev, next) {
      final prevState = prev?.value;
      final nextState = next.value;

      if (widget.isActive && prevState is SshReconnecting && nextState is SshConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnected'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (widget.isActive && nextState is SshFailed && prevState is! SshFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to $machineName.')),
        );
        // Reset so picker shows again if user manually reconnects after retry exhaustion.
        _pickerShown = false;
      }

      // PICK-01 / PICK-04: Show folder picker on FIRST SshConnected transition only.
      // _pickerShown guard prevents re-showing on mid-session reconnect (Pitfall 1 in RESEARCH.md).
      if (!_pickerShown && nextState is SshConnected) {
        _pickerShown = true;
        final allMachines = ref.read(machineProvider).value;
        final pickerMachine =
            allMachines?.where((m) => m.id == widget.machineId).firstOrNull;
        final paths = pickerMachine?.folderPaths;
        if (paths != null && paths.isNotEmpty) {
          // addPostFrameCallback prevents "setState during build" assertion (Pitfall 2 in RESEARCH.md).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showModalBottomSheet<void>(
              context: context,
              isDismissible: false,
              enableDrag: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              builder: (_) => SessionPickerSheet(
                folderPaths: paths,
                onFolderSelected: (path) {
                  final cmd = pickerMachine?.platform.cdCommand(path) ?? 'cd "$path"';
                  ref
                      .read(sshSessionProvider(widget.machineId).notifier)
                      .sendText('$cmd\n');
                },
              ),
            );
          });
        }
      }
    });

    // Clamp text scale factor to 1.3 to prevent terminal layout overflow
    // when the user has a large system font size (UI-SPEC.md).
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.of(context).textScaler.scale(1).clamp(1.0, 1.3),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: true,
          bottom: false,
          left: false,
          right: false,
          child: Column(
            children: [
              // Terminal view with reconnection UI layers.
              // A Stack keeps TerminalViewWrapper always mounted so xterm scrollback
              // is never destroyed during a reconnection cycle (RECON-05).
              Expanded(
                child: Builder(
                  builder: (context) {
                    final keyboardHeight =
                        MediaQuery.of(context).viewInsets.bottom;
                    final sessionState = sessionAsync.value;

                    // Base layer: terminal when we have one, spinner during initial connect.
                    final Widget baseLayer = switch (sessionState) {
                      SshConnected(:final terminal) ||
                      SshReconnecting(:final terminal) ||
                      SshFailed(:final terminal) =>
                        TerminalViewWrapper(
                          key: ValueKey(keyboardHeight),
                          machineId: widget.machineId,
                          terminal: terminal,
                        ),
                      SshConnecting() || null =>
                        const Center(child: CircularProgressIndicator()),
                    };

                    return Stack(
                      children: [
                        // Layer 1 — always present terminal (or spinner).
                        baseLayer,

                        // Layer 2 — mid-session banner pinned to top.
                        if (sessionState
                            case SshReconnecting(
                              :final attempt,
                              :final maxAttempts,
                              :final secondsLeft,
                            ))
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: ReconnectBanner(
                              attempt: attempt,
                              maxAttempts: maxAttempts,
                              secondsLeft: secondsLeft,
                              onCancel: () => ref
                                  .read(
                                      sshSessionProvider(widget.machineId).notifier)
                                  .cancel(),
                            ),
                          ),

                        // Layer 3 — initial-connect overlay.
                        if (sessionState
                            case SshConnecting(
                              :final attempt,
                              :final maxAttempts,
                              :final secondsLeft,
                            ))
                          ReconnectOverlay(
                            attempt: attempt,
                            maxAttempts: maxAttempts,
                            secondsLeft: secondsLeft,
                            onCancel: () => ref
                                .read(sshSessionProvider(widget.machineId).notifier)
                                .cancel(),
                          ),

                        // Layer 4 — failed/retry overlay.
                        if (sessionState is SshFailed)
                          ReconnectFailedOverlay(
                            onRetry: () => ref
                                .read(sshSessionProvider(widget.machineId).notifier)
                                .reconnect(),
                          ),
                      ],
                    );
                  },
                ),
              ),
              // Permission card — slides in above InputBar when Claude Code shows
              // a permission prompt. AnimatedSwitcher requires distinct ValueKeys
              // on both children so it recognizes the widget type has changed.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: permissionLine != null
                    ? PermissionCard(
                        key: const ValueKey('permission-card'),
                        machineId: widget.machineId,
                        line: permissionLine,
                      )
                    : const SizedBox.shrink(key: ValueKey('no-card')),
              ),
              // InputBar — always rendered; its controls disable when not connected.
              InputBar(machineId: widget.machineId),
            ],
          ),
        ),
      ),
    );
  }
}

