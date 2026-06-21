import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/models/machine.dart';
import '../../machines/providers/machines_provider.dart';
import '../models/ssh_session_state.dart';
import '../providers/ssh_session_provider.dart';
import 'folder_picker_sheet.dart';
import 'voice_bottom_sheet.dart';

const _arrowLeft  = [0x1b, 0x5b, 0x44];
const _arrowUp    = [0x1b, 0x5b, 0x41];
const _arrowDown  = [0x1b, 0x5b, 0x42];
const _arrowRight = [0x1b, 0x5b, 0x43];

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

// Control + session merged
const _controlCommands = [
  _Cmd('Ctrl+C', [0x03]),
  _Cmd('Ctrl+D', [0x04]),
  _Cmd('Ctrl+U', [0x15]),
  _Cmd('Ctrl+Z', [0x1a]),
  _Cmd('Ctrl+X', [0x18]),
  _Cmd('ESC',    [0x1b]),
  _Cmd('Tab',    [0x09]),
];

const _controlTextCommands = [
  _TextCmd('exit', 'exit'),
  _TextCmd('q',    'q'),
  _TextCmd('\\q',  '\\q'),
];

// Claude: run / continue / resume first, then slash commands
const _claudeCommands = [
  _TextCmd('run',      'claude --dangerously-skip-permissions'),
  _TextCmd('continue', 'claude --dangerously-skip-permissions --continue'),
  _TextCmd('resume',   'claude --dangerously-skip-permissions --resume'),
  _TextCmd('/compact', '/compact'),
  _TextCmd('/cost',    '/cost'),
  _TextCmd('/model',   '/model'),
];

List<_TextCmd> _shellCommands(RemotePlatform platform) => switch (platform) {
  RemotePlatform.linux => const [
    _TextCmd('cd ~',   'cd ~'),
    _TextCmd('cd ..',  'cd ..'),
    _TextCmd('ls',     'ls'),
    _TextCmd('ls -la', 'ls -la'),
    _TextCmd('pwd',    'pwd'),
    _TextCmd('cat',    'cat'),
    _TextCmd('mkdir',  'mkdir'),
    _TextCmd('rm',     'rm'),
    _TextCmd('grep',   'grep'),
    _TextCmd('ps',     'ps aux'),
    _TextCmd('kill',   'kill'),
    _TextCmd('top',    'top'),
  ],
  RemotePlatform.macos => const [
    _TextCmd('cd ~',   'cd ~'),
    _TextCmd('cd ..',  'cd ..'),
    _TextCmd('ls',     'ls'),
    _TextCmd('ls -la', 'ls -la'),
    _TextCmd('pwd',    'pwd'),
    _TextCmd('open .', 'open .'),
    _TextCmd('cat',    'cat'),
    _TextCmd('mkdir',  'mkdir'),
    _TextCmd('rm',     'rm'),
    _TextCmd('grep',   'grep'),
    _TextCmd('ps',     'ps aux'),
    _TextCmd('kill',   'kill'),
  ],
  RemotePlatform.windows => const [
    _TextCmd('cd ..',      'cd ..'),
    _TextCmd('dir',        'dir'),
    _TextCmd('dir /a',     'dir /a'),
    _TextCmd('cls',        'cls'),
    _TextCmd('type',       'type'),
    _TextCmd('mkdir',      'mkdir'),
    _TextCmd('del',        'del'),
    _TextCmd('findstr',    'findstr'),
    _TextCmd('tasklist',   'tasklist'),
    _TextCmd('taskkill',   'taskkill /f /im'),
    _TextCmd('ipconfig',   'ipconfig'),
    _TextCmd('echo %cd%',  'echo %cd%'),
  ],
};

/// InputBar — expandable command panel + arrow keys + folder picker + mic.
class InputBar extends ConsumerStatefulWidget {
  final String machineId;
  final String tabId;
  const InputBar({super.key, required this.machineId, required this.tabId});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  bool _commandsVisible = false;
  bool _loadingFolders = false;

  final _speech = SpeechToText();
  bool _voiceAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (mounted) setState(() => _voiceAvailable = available);
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  void _openVoiceSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoiceBottomSheet(
        onSend: (text) {
          ref
              .read(sshSessionProvider(widget.machineId, widget.tabId).notifier)
              .sendText(text);
        },
      ),
    );
  }

  Future<void> _showFolderPicker(Machine machine) async {
    if (_loadingFolders) return;
    setState(() => _loadingFolders = true);

    final notifier =
        ref.read(sshSessionProvider(widget.machineId, widget.tabId).notifier);
    final folders = <(String basePath, String name)>[];
    for (final basePath in machine.folderPaths) {
      final names = await notifier.listFolders(basePath);
      for (final name in names) {
        folders.add((basePath, name));
      }
    }

    if (mounted) setState(() => _loadingFolders = false);
    if (folders.isEmpty || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => FolderPickerSheet(
        folders: folders,
        onFolderSelected: (basePath, name) {
          final fullPath = machine.platform.joinPath(basePath, name);
          notifier.sendText('${machine.platform.cdCommand(fullPath)}\n');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stateValue =
        ref.watch(sshSessionProvider(widget.machineId, widget.tabId)).value;
    final isConnected = stateValue is SshConnected;
    final colorScheme = Theme.of(context).colorScheme;

    final machine = ref
        .watch(machineProvider)
        .value
        ?.where((m) => m.id == widget.machineId)
        .firstOrNull;
    final hasFolderPaths = machine?.folderPaths.isNotEmpty == true;
    final platform = machine?.platform ?? RemotePlatform.linux;

    void send(List<int> bytes) {
      if (!isConnected) return;
      ref
          .read(sshSessionProvider(widget.machineId, widget.tabId).notifier)
          .sendBytes(bytes);
    }

    void sendAndClose(List<int> bytes) {
      send(bytes);
      setState(() => _commandsVisible = false);
    }

    void sendText(String text) {
      if (!isConnected) return;
      ref
          .read(sshSessionProvider(widget.machineId, widget.tabId).notifier)
          .sendText(text);
    }

    Widget sectionHeader(String label) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        );

    Widget ctrlChip(_Cmd c) => ActionChip(
          label: Text(c.label, style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          onPressed: isConnected ? () => sendAndClose(c.bytes) : null,
        );

    Widget textChip(_TextCmd c) => ActionChip(
          label: Text(c.label, style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
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

    final shellLabel = switch (platform) {
      RemotePlatform.linux   => 'Shell — Linux',
      RemotePlatform.macos   => 'Shell — macOS',
      RemotePlatform.windows => 'Shell — Windows',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Expandable command panel ──────────────────────────────────
        if (_commandsVisible)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
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
                    // Control + Session merged
                    sectionHeader('Control'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _controlCommands) ctrlChip(cmd),
                        for (final cmd in _controlTextCommands) textChip(cmd),
                      ],
                    ),
                    // Claude
                    sectionHeader('Claude'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _claudeCommands) textChip(cmd),
                      ],
                    ),
                    // Shell (platform-specific)
                    sectionHeader(shellLabel),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final cmd in _shellCommands(platform))
                          textChip(cmd),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Command toggle
              TextButton.icon(
                onPressed: isConnected
                    ? () =>
                        setState(() => _commandsVisible = !_commandsVisible)
                    : null,
                icon: Icon(
                  _commandsVisible ? Icons.expand_less : Icons.expand_more,
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

              // Folder picker button — only when machine has configured paths
              if (hasFolderPaths)
                Semantics(
                  label: 'Pick working folder',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Pick folder',
                      icon: _loadingFolders
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_outlined, size: 20),
                      onPressed: isConnected && !_loadingFolders && machine != null
                          ? () => _showFolderPicker(machine)
                          : null,
                    ),
                  ),
                ),

              // Mic button
              if (_voiceAvailable)
                Semantics(
                  label: 'Start voice input',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Voice input',
                      icon: const Icon(Icons.mic, size: 20),
                      onPressed: isConnected ? _openVoiceSheet : null,
                    ),
                  ),
                ),

              // Arrow keys
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
