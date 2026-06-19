import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ssh_session_provider.dart';

const _arrowLeft  = [0x1b, 0x5b, 0x44];
const _arrowUp    = [0x1b, 0x5b, 0x41];
const _arrowDown  = [0x1b, 0x5b, 0x42];
const _arrowRight = [0x1b, 0x5b, 0x43];

const _commands = [
  _Cmd('Interrupt  [Ctrl+C]',  [0x03]),
  _Cmd('Exit / EOF  [Ctrl+D]', [0x04]),
  _Cmd('Escape  [ESC]',        [0x1b]),
  _Cmd('Tab  [Tab]',           [0x09]),
];

class _Cmd {
  final String label;
  final List<int> bytes;
  const _Cmd(this.label, this.bytes);
}

class _TextCmd {
  final String label;
  final String command;
  const _TextCmd(this.label, this.command);
}

const _claudeCommands = [
  _TextCmd('/clear',   '/clear'),
  _TextCmd('/compact', '/compact'),
  _TextCmd('/help',    '/help'),
  _TextCmd('/cost',    '/cost'),
  _TextCmd('/gsd',     '/gsd'),
];

const _shellCommands = [
  _TextCmd('cd ~',  'cd ~'),
  _TextCmd('cd ..', 'cd ..'),
  _TextCmd('ls',    'ls'),
  _TextCmd('pwd',   'pwd'),
];

const _sessionCommands = [
  _TextCmd('claude',   'claude'),
  _TextCmd('claude .', 'claude .'),
  _TextCmd('exit',     'exit'),
  _TextCmd('q',        'q'),
  _TextCmd('\\q',      '\\q'),
];

/// InputBar — expandable Command panel + arrow keys + mic placeholder.
///
/// Tapping "Command" expands a row of chips inline (no route push, no focus
/// loss) so the soft keyboard stays open while selecting a control signal.
class InputBar extends ConsumerStatefulWidget {
  final String machineId;
  const InputBar({super.key, required this.machineId});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  bool _commandsVisible = false;

  @override
  Widget build(BuildContext context) {
    final isConnected =
        ref.watch(sshSessionProvider(widget.machineId)).hasValue;
    final colorScheme = Theme.of(context).colorScheme;

    void send(List<int> bytes) {
      if (!isConnected) return;
      ref
          .read(sshSessionProvider(widget.machineId).notifier)
          .sendBytes(bytes);
    }

    void sendAndClose(List<int> bytes) => send(bytes);

    void sendText(String text) {
      if (!isConnected) return;
      ref
          .read(sshSessionProvider(widget.machineId).notifier)
          .sendText(text);
    }

    Widget sectionHeader(String label) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );

    Widget textChip(_TextCmd c) => ActionChip(
          label: Text(c.label, style: const TextStyle(fontSize: 12)),
          onPressed: isConnected ? () => sendText('${c.command}\n') : null,
        );

    Widget arrowBtn(IconData icon, List<int> bytes) => SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 18),
            onPressed: isConnected ? () => send(bytes) : null,
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Expandable command panel (sectioned, scrollable) ─────────
        if (_commandsVisible)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Container(
                color: colorScheme.surfaceContainerHighest,
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Control section
                    sectionHeader('Control'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _commands)
                          ActionChip(
                            label: Text(cmd.label,
                                style: const TextStyle(fontSize: 12)),
                            onPressed: isConnected
                                ? () => sendAndClose(cmd.bytes)
                                : null,
                          ),
                      ],
                    ),
                    // Claude section
                    sectionHeader('Claude'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _claudeCommands) textChip(cmd),
                      ],
                    ),
                    // Shell section
                    sectionHeader('Shell'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _shellCommands) textChip(cmd),
                      ],
                    ),
                    // Session section
                    sectionHeader('Session'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _sessionCommands) textChip(cmd),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Main bar ─────────────────────────────────────────────────
        Container(
          color: colorScheme.surfaceContainerHigh,
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Command toggle
              TextButton.icon(
                onPressed: isConnected
                    ? () =>
                        setState(() => _commandsVisible = !_commandsVisible)
                    : null,
                icon: Icon(
                  _commandsVisible
                      ? Icons.expand_more
                      : Icons.expand_less,
                  size: 16,
                ),
                label: const Text('Command',
                    style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              const Spacer(),

              // Arrow keys (right-aligned)
              arrowBtn(Icons.arrow_back,     _arrowLeft),
              arrowBtn(Icons.arrow_upward,   _arrowUp),
              arrowBtn(Icons.arrow_downward, _arrowDown),
              arrowBtn(Icons.arrow_forward,  _arrowRight),
            ],
          ),
        ),
      ],
    );
  }
}
