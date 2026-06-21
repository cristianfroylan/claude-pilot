import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../machines/providers/machines_provider.dart';
import '../../terminal/models/ssh_session_state.dart';
import '../../terminal/providers/ssh_session_provider.dart';
import '../../terminal/screens/terminal_screen.dart';
import '../models/session_tab.dart';
import '../providers/sessions_provider.dart';
import '../widgets/machine_selection_sheet.dart';

/// Multi-tab SSH sessions screen.
///
/// Hosts a horizontal tab strip and an IndexedStack of TerminalScreen widgets.
/// All TerminalScreen instances stay mounted — IndexedStack preserves xterm
/// scrollback and SSH state across tab switches (SESS-01, SESS-03).
///
/// PopScope(canPop: false) suppresses the Android back gesture (UI-SPEC contract).
class SessionsScreen extends ConsumerStatefulWidget {
  /// Machine to open a tab for on first render.
  ///
  /// Passed from the /sessions route builder when navigating from MachineListScreen.
  /// Null when navigating to /sessions without a specific machine (e.g. from empty state).
  final String? initialMachineId;

  const SessionsScreen({super.key, this.initialMachineId});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _lastInitialMachineId;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open tab for initialMachineId on first build only.
    // Guard prevents duplicate tab when SessionsScreen rebuilds.
    if (widget.initialMachineId != null) {
      _lastInitialMachineId = widget.initialMachineId;
      // Schedule after frame so sessionsProvider is accessible in build context.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(sessionsProvider.notifier).openTab(widget.initialMachineId!);
      });
    }
  }

  @override
  void didUpdateWidget(SessionsScreen old) {
    super.didUpdateWidget(old);
    // Handle new machine ID arriving via query param after screen is already showing.
    final newId = widget.initialMachineId;
    if (newId != null && newId != _lastInitialMachineId) {
      _lastInitialMachineId = newId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(sessionsProvider.notifier).openTab(newId);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    final tabs = sessions.tabs;
    final activeIndex = sessions.activeIndex;

    // Listen for new tab added to scroll tab strip into view.
    ref.listen(sessionsProvider, (prev, next) {
      if ((prev?.tabs.length ?? 0) < next.tabs.length) {
        // New tab added — scroll to show it after frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHigh,
          automaticallyImplyLeading: false,
          title: const Text(
            'Sessions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.computer),
              tooltip: 'Machines',
              onPressed: () => context.push('/machines'),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New session',
              onPressed: () => _showMachineSelectionSheet(context),
            ),
          ],
        ),
        body: tabs.isEmpty
            ? _buildEmptyState(context)
            : Column(
                children: [
                  // Tab strip row — 44 dp height.
                  SizedBox(
                    height: 44,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...List.generate(
                              tabs.length,
                              (i) => _TabChip(
                                tab: tabs[i],
                                isActive: i == activeIndex,
                                onTap: () => ref
                                    .read(sessionsProvider.notifier)
                                    .setActiveTab(i),
                                onClose: () => _closeTab(context, i),
                              ),
                            ),
                            // Add button at end of strip.
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                color:
                                    Theme.of(context).colorScheme.primary,
                                tooltip: 'New session',
                                onPressed: () =>
                                    _showMachineSelectionSheet(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Terminal area — IndexedStack keeps all TerminalScreen widgets mounted.
                  Expanded(
                    child: IndexedStack(
                      index: activeIndex.clamp(
                          0, tabs.isEmpty ? 0 : tabs.length - 1),
                      children: List.generate(tabs.length, (i) {
                        final isActive = i == activeIndex;
                        final screen = TerminalScreen(
                          key: ValueKey(tabs[i].id),
                          machineId: tabs[i].machineId,
                          tabId: tabs[i].id,
                          isActive: isActive,
                        );
                        return isActive
                            ? screen
                            : Visibility(
                                visible: false,
                                maintainState: true,
                                child: ExcludeSemantics(child: screen),
                              );
                      }),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _closeTab(BuildContext context, int index) {
    ref.read(sessionsProvider.notifier).closeTab(index);
    // No navigation needed — SessionsScreen is home and shows empty state
    // when all tabs are closed.
  }

  void _showMachineSelectionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => MachineSelectionSheet(
        onMachineTap: (machineId) {
          ref.read(sessionsProvider.notifier).openTab(machineId);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final machines = ref.watch(machineProvider).value ?? [];
    final hasMachines = machines.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasMachines ? Icons.terminal : Icons.computer_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              hasMachines ? 'No active sessions' : 'No machines yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              hasMachines
                  ? 'Open the machines panel and tap a machine to connect'
                  : 'Add a machine to start using Claude Code remotely',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasMachines)
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New Session'),
                onPressed: () => _showMachineSelectionSheet(context),
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.computer),
                label: const Text('Add Machine'),
                onPressed: () => context.push('/machines'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single tab chip in the horizontal strip.
///
/// Displays machine name, 8dp status dot (pulsing when connecting), and a close button.
/// Active tab: primaryContainer background, primary label, bottom border.
/// Inactive tab: surfaceContainerHigh background, onSurfaceVariant label.
class _TabChip extends ConsumerWidget {
  final SessionTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Read machine name for display.
    final machines = ref.watch(machineProvider).value;
    final machine = machines?.where((m) => m.id == tab.machineId).firstOrNull;
    final machineName = machine?.name ?? tab.machineId;

    // Watch SSH state for status dot.
    final sessionAsync = ref.watch(sshSessionProvider(tab.machineId, tab.id));
    final sessionState = sessionAsync.value;

    // Derive status dot color.
    final Color dotColor = switch (sessionState) {
      SshConnected() => Colors.green.shade400,
      SshFailed() => colorScheme.error,
      _ => colorScheme.secondary, // SshConnecting, SshReconnecting, null
    };

    // Whether dot should pulse (connecting/reconnecting).
    final bool dotPulsing =
        sessionState is SshConnecting || sessionState is SshReconnecting;

    // Chip background and label color change based on active state.
    final chipBg =
        isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh;
    final labelColor =
        isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final closeColor =
        isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border(
                  bottom: BorderSide(color: colorScheme.primary, width: 2))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left padding sm (8 dp) before dot.
            const SizedBox(width: 8),
            // Status dot — 8 dp circle. Pulse animation when connecting.
            Semantics(
              label: switch (sessionState) {
                SshConnected() => 'Connected',
                SshFailed() => 'Connection failed',
                _ => 'Connecting',
              },
              child: dotPulsing
                  ? _PulsingDot(color: dotColor)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
            ),
            // xs gap (4 dp) between dot and label.
            const SizedBox(width: 4),
            // Machine name label — truncates with ellipsis.
            Flexible(
              child: Text(
                machineName,
                style: TextStyle(fontSize: 12, color: labelColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            // xs gap (4 dp) between label and close button.
            const SizedBox(width: 4),
            // Close button — 32 dp effective tap target.
            Semantics(
              label: 'Close $machineName session',
              child: GestureDetector(
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: closeColor),
                ),
              ),
            ),
            // Right padding sm (8 dp).
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Pulsing dot widget for connecting/reconnecting state in tab chips.
///
/// Replicates the animation pattern from _ConnectingDot in terminal_screen.dart
/// but parameterized by color (secondary color, not primary).
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
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
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
