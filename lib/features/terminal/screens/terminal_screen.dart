import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../machines/providers/machines_provider.dart';
import '../providers/ssh_session_provider.dart';
import '../widgets/input_bar.dart';
import '../widgets/terminal_view_wrapper.dart';

/// TerminalScreen — SSH terminal view for a single machine.
///
/// Shows connection status in the AppBar, renders ANSI output via TerminalView,
/// and provides the InputBar for sending text and control signals.
class TerminalScreen extends ConsumerWidget {
  final String machineId;

  const TerminalScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sshSessionProvider(machineId));

    // Retrieve machine metadata for display name.
    // Uses .value (nullable) — valueOrNull not available in installed Riverpod version.
    final machines = ref.watch(machineProvider).value;
    final machine = machines?.cast<dynamic>().firstWhere(
      (m) => m.id == machineId,
      orElse: () => null,
    );
    final machineName = (machine?.name as String?) ?? 'Terminal';

    // Error dialog: fires once on transition into error state (T-03-03).
    // — Connection drop while active: brief message, no config link needed.
    // — Failed to connect after 3 retries: offer to open the edit screen.
    ref.listen(sshSessionProvider(machineId), (prev, next) {
      if (next.hasError && !(prev?.hasError ?? false)) {
        final wasConnected = prev?.hasValue ?? false;
        if (wasConnected) {
          // Mid-session drop — light SnackBar, no action required.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection to $machineName lost.')),
          );
          return;
        }
        // Failed to connect after all retries — offer config review.
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Could not connect'),
            content: Text(
              'We tried ${SshSession.maxAttempts} times and could not reach '
              '$machineName. Do you want to review the machine settings?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/machines/$machineId/edit');
                },
                child: const Text('Review settings'),
              ),
            ],
          ),
        );
      }
    });

    // Build status label for AppBar subtitle.
    final statusLabel = sessionAsync.when(
      loading: () => 'Connecting…',
      error: (_, __) => 'Connection failed',
      data: (_) => 'Connected',
    );

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
              // Animated pulsing dot only during connecting state (UI-SPEC).
              if (sessionAsync.isLoading)
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
        body: Column(
          children: [
            // Terminal view — expands to fill remaining space above InputBar.
            Expanded(
              child: sessionAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (terminal) => TerminalViewWrapper(
                  machineId: machineId,
                  terminal: terminal,
                ),
              ),
            ),
            // InputBar — always rendered; its controls disable when not connected.
            InputBar(machineId: machineId),
          ],
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
