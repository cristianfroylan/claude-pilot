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
import '../widgets/terminal_view_wrapper.dart';

/// TerminalScreen — SSH terminal view for a single tab.
///
/// Each tab has a unique [tabId] so [sshSessionProvider] is independent even
/// when two tabs connect to the same machine (SESS-TAB-01).
///
/// [isActive] gates SnackBar emission for background tabs (SESS-04).
class TerminalScreen extends ConsumerWidget {
  final String machineId;
  final String tabId;
  final bool isActive;

  const TerminalScreen({
    super.key,
    required this.machineId,
    required this.tabId,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sshSessionProvider(machineId, tabId));
    final permissionLine = ref
        .watch(permissionDetectorProvider(machineId, tabId))
        .asData
        ?.value;

    final machineName = ref
            .watch(machineProvider)
            .value
            ?.where((m) => m.id == machineId)
            .firstOrNull
            ?.name ??
        'Terminal';

    ref.listen(sshSessionProvider(machineId, tabId), (prev, next) {
      final prevState = prev?.value;
      final nextState = next.value;

      if (isActive && prevState is SshReconnecting && nextState is SshConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnected'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (isActive && nextState is SshFailed && prevState is! SshFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to $machineName.')),
        );
      }
    });

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
              Expanded(
                child: Builder(
                  builder: (context) {
                    final keyboardHeight =
                        MediaQuery.of(context).viewInsets.bottom;
                    final sessionState = sessionAsync.value;

                    final Widget baseLayer = switch (sessionState) {
                      SshConnected(:final terminal) ||
                      SshReconnecting(:final terminal) ||
                      SshFailed(:final terminal) =>
                        TerminalViewWrapper(
                          key: ValueKey(keyboardHeight),
                          machineId: machineId,
                          tabId: tabId,
                          terminal: terminal,
                        ),
                      SshConnecting() || null => const SizedBox.shrink(),
                    };

                    return Stack(
                      children: [
                        baseLayer,
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
                                  .read(sshSessionProvider(machineId, tabId)
                                      .notifier)
                                  .cancel(),
                            ),
                          ),
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
                                .read(sshSessionProvider(machineId, tabId)
                                    .notifier)
                                .cancel(),
                          ),
                        if (sessionState is SshFailed)
                          ReconnectFailedOverlay(
                            onRetry: () => ref
                                .read(sshSessionProvider(machineId, tabId)
                                    .notifier)
                                .reconnect(),
                          ),
                      ],
                    );
                  },
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: permissionLine != null
                    ? PermissionCard(
                        key: const ValueKey('permission-card'),
                        machineId: machineId,
                        tabId: tabId,
                        line: permissionLine,
                      )
                    : const SizedBox.shrink(key: ValueKey('no-card')),
              ),
              InputBar(machineId: machineId, tabId: tabId),
            ],
          ),
        ),
      ),
    );
  }
}
