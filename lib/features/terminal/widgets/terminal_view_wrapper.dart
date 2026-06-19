import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/ssh_session_provider.dart';

/// TerminalViewWrapper — wraps xterm TerminalView in a LayoutBuilder to wire
/// PTY resize when the keyboard appears/disappears or the screen rotates.
///
/// Uses ConsumerWidget to access the SSH session notifier for resizeTerminal.
class TerminalViewWrapper extends ConsumerWidget {
  final String machineId;
  final Terminal terminal;

  const TerminalViewWrapper({
    super.key,
    required this.machineId,
    required this.terminal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate PTY dimensions from available pixel space.
        // cols: approximate monospace cell width ~8px; clamp to valid range.
        // rows: approximate monospace cell height ~16px; clamp to valid range.
        final cols = (constraints.maxWidth / 8).floor().clamp(40, 220);
        final rows = (constraints.maxHeight / 16).floor().clamp(10, 60);

        // MUST use addPostFrameCallback — calling resizeTerminal directly during
        // build causes setState-during-build errors (Pitfall 2 in RESEARCH.md).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(sshSessionProvider(machineId).notifier)
              .resizeTerminal(cols, rows);
        });

        // ExcludeSemantics: raw terminal output is noise for screen readers.
        // autofocus: false — the InputBar TextField owns keyboard focus.
        return ExcludeSemantics(
          child: TerminalView(
            terminal,
            theme: AppTheme.terminalTheme,
            autofocus: false,
          ),
        );
      },
    );
  }
}
