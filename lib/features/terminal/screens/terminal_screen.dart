import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
/// Shows connection status in the AppBar, renders ANSI output via TerminalView,
/// and provides the InputBar for sending text and control signals.
///
/// The body switches on AsyncValue<SshSessionState>. States carrying a terminal
/// (SshConnected, SshReconnecting, SshFailed) render TerminalViewWrapper to
/// keep the xterm PTY mounted and scrollback preserved (RECON-05).
/// Plan 04-03 will add overlay/banner widgets on top of this via a Stack.
class TerminalScreen extends ConsumerStatefulWidget {
  final String machineId;

  const TerminalScreen({super.key, required this.machineId});

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
    final machine = machines?.cast<dynamic>().firstWhere(
      (m) => m.id == widget.machineId,
      orElse: () => null,
    );
    final machineName = (machine?.name as String?) ?? 'Terminal';

    // Transition listener: fire SnackBar on SshReconnecting→SshConnected (RECON-05 "Reconnected")
    // and keep the SshFailed notification for initial-connect exhaustion. No AlertDialog.
    ref.listen(sshSessionProvider(widget.machineId), (prev, next) {
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

      if (nextState is SshFailed && prevState is! SshFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to $machineName.')),
        );
      }

      // PICK-01 / PICK-04: Show folder picker on FIRST SshConnected transition only.
      // _pickerShown guard prevents re-showing on mid-session reconnect (Pitfall 1 in RESEARCH.md).
      if (!_pickerShown && nextState is SshConnected) {
        _pickerShown = true;
        final allMachines = ref.read(machineProvider).value;
        final pickerMachine = allMachines?.cast<dynamic>().firstWhere(
          (m) => m.id == widget.machineId,
          orElse: () => null,
        );
        final paths = pickerMachine?.folderPaths as List<String>?;
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
                  ref
                      .read(sshSessionProvider(widget.machineId).notifier)
                      .sendText('cd $path\n');
                },
              ),
            );
          });
        }
      }
    });

    // Build status label for AppBar subtitle.
    final statusLabel = switch (sessionAsync.value) {
      SshConnecting() => 'Connecting…',
      SshReconnecting() => 'Reconnecting…',
      SshFailed() => 'Connection failed',
      SshConnected() => 'Connected',
      null => 'Connecting…',
    };

    // Whether to show the pulsing dot in the AppBar.
    final isPulsing = sessionAsync.value is SshConnecting ||
        sessionAsync.value is SshReconnecting;

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
        appBar: AppBar(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHigh,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              // Animated pulsing dot during connecting/reconnecting states.
              if (isPulsing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _ConnectingDot(),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(machineName),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Semantics(
              label: 'Disconnect',
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
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

/// Animated dot that oscillates opacity 1.0 ↔ 0.4 while SSH is connecting.
///
/// Implements the "animated dot" specified in UI-SPEC.md interaction contract.
/// Uses AnimationController with repeat(reverse: true) for a smooth pulse.
class _ConnectingDot extends StatefulWidget {
  const _ConnectingDot();

  @override
  State<_ConnectingDot> createState() => _ConnectingDotState();
}

class _ConnectingDotState extends State<_ConnectingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.4).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
