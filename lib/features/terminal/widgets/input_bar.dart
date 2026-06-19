import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ssh_session_provider.dart';

// Control signal byte constants — raw bytes sent directly to SSH stdin.
const _ctrlC = [0x03]; // SIGINT — interrupt running process
const _ctrlD = [0x04]; // EOF — close stdin / exit shell
const _esc = [0x1b]; // Escape key

/// InputBar widget — displays control chips (Ctrl+C/D/ESC) and a text input row.
///
/// Uses ConsumerStatefulWidget to hold the TextEditingController locally while
/// accessing the SSH session provider via ref.
class InputBar extends ConsumerStatefulWidget {
  final String machineId;

  const InputBar({super.key, required this.machineId});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref
        .read(sshSessionProvider(widget.machineId).notifier)
        .sendText('$text\n');
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sshSessionProvider(widget.machineId));
    final isConnected = sessionAsync.hasValue;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Control signal chips (Ctrl+C, Ctrl+D, ESC)
          Row(
            children: [
              for (final (label, bytes) in [
                ('Ctrl+C', _ctrlC),
                ('Ctrl+D', _ctrlD),
                ('ESC', _esc),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: isConnected
                        ? () => ref
                              .read(
                                sshSessionProvider(widget.machineId).notifier,
                              )
                              .sendBytes(bytes)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Text input field + Send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => isConnected ? _send() : null,
                  enabled: isConnected,
                  decoration: const InputDecoration(
                    hintText: 'Type a prompt…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Send',
                child: IconButton(
                  icon: const Icon(Icons.send),
                  color: colorScheme.primary,
                  onPressed: isConnected ? _send : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
