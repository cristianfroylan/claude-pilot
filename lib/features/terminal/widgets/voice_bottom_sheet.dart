import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum _VoiceState { idle, recording, hasResult }

/// Push-to-talk voice sheet.
///
/// Layout (top → bottom):
///   drag handle
///   [text input — editable, scrollable, only when text exists]
///   [Cancelar | Enviar row — only when text exists]
///   mic button (hold to record, release to stop)
///   status label
class VoiceBottomSheet extends StatefulWidget {
  final void Function(String text) onSend;

  const VoiceBottomSheet({super.key, required this.onSend});

  @override
  State<VoiceBottomSheet> createState() => _VoiceBottomSheetState();
}

class _VoiceBottomSheetState extends State<VoiceBottomSheet> {
  final _speech = SpeechToText();
  final _textController = TextEditingController();
  bool _speechAvailable = false;
  _VoiceState _state = _VoiceState.idle;
  // Text accumulated before the current recording session — new words append to this.
  String _baseText = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        // Android's SpeechRecognizer can stop on its own after a short silence.
        // When that happens while we're still in "recording" state, update the
        // button so the user knows dictation has ended.
        if (_state == _VoiceState.recording &&
            (status == 'done' || status == 'notListening')) {
          setState(() => _state = _textController.text.isNotEmpty
              ? _VoiceState.hasResult
              : _VoiceState.idle);
        }
      },
      onError: (_) {
        if (!mounted) return;
        if (_state == _VoiceState.recording) {
          setState(() => _state = _textController.text.isNotEmpty
              ? _VoiceState.hasResult
              : _VoiceState.idle);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable || _state == _VoiceState.recording) return;
    // Snapshot current text — new recognition words will be appended to this.
    _baseText = _textController.text.trim();
    setState(() => _state = _VoiceState.recording);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final newWords = result.recognizedWords;
        if (_baseText.isEmpty) {
          _textController.text = newWords;
        } else if (newWords.isNotEmpty) {
          _textController.text = '$_baseText $newWords';
        }
        if (result.finalResult) {
          setState(() => _state = _textController.text.isNotEmpty
              ? _VoiceState.hasResult
              : _VoiceState.idle);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 10),
        localeId: null,
      ),
    );
  }

  Future<void> _stopRecording() async {
    if (_state != _VoiceState.recording) return;
    await _speech.stop();
    if (!mounted) return;
    setState(() => _state = _textController.text.isNotEmpty
        ? _VoiceState.hasResult
        : _VoiceState.idle);
  }

  void _clearText() {
    _textController.clear();
    _baseText = '';
    setState(() => _state = _VoiceState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecording = _state == _VoiceState.recording;
    final hasText = _textController.text.isNotEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Text input — only when there's text
              if (hasText) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearText,
                        tooltip: 'Limpiar texto',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),

                // Action buttons — Cancelar | Enviar, 50/50
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final text = _textController.text.trim();
                          if (text.isEmpty) return;
                          widget.onSend(text);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Enviar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Push-to-talk button
              Listener(
                onPointerDown: (_) => _startRecording(),
                onPointerUp: (_) => _stopRecording(),
                onPointerCancel: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording
                        ? colorScheme.error
                        : colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 40,
                    color: isRecording
                        ? colorScheme.onError
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Status label
              Text(
                isRecording
                    ? 'Escuchando…'
                    : hasText
                        ? 'Mantén para seguir dictando'
                        : _speechAvailable
                            ? 'Mantén para dictar'
                            : 'Micrófono no disponible',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
