import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum _VoiceState { idle, recording, hasResult }

/// Push-to-talk voice sheet.
///
/// Hold the mic button to record, release to stop.
/// When there is transcribed text, shows Send / Cancelar buttons.
class VoiceBottomSheet extends StatefulWidget {
  final void Function(String text) onSend;

  const VoiceBottomSheet({super.key, required this.onSend});

  @override
  State<VoiceBottomSheet> createState() => _VoiceBottomSheetState();
}

class _VoiceBottomSheetState extends State<VoiceBottomSheet> {
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  _VoiceState _state = _VoiceState.idle;
  String _transcript = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(onStatus: (_) {}, onError: (_) {});
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable || _state == _VoiceState.recording) return;
    setState(() {
      _state = _VoiceState.recording;
      _transcript = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _state =
              _transcript.isNotEmpty ? _VoiceState.hasResult : _VoiceState.idle);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 15),
        localeId: null,
      ),
    );
  }

  Future<void> _stopRecording() async {
    if (_state != _VoiceState.recording) return;
    await _speech.stop();
    if (!mounted) return;
    setState(() => _state =
        _transcript.isNotEmpty ? _VoiceState.hasResult : _VoiceState.idle);
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecording = _state == _VoiceState.recording;
    final hasResult = _state == _VoiceState.hasResult;

    return SafeArea(
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
            const SizedBox(height: 24),

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
                  : hasResult
                      ? 'Mantén para dictar de nuevo'
                      : _speechAvailable
                          ? 'Mantén para dictar'
                          : 'Micrófono no disponible',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // Transcription box
            if (_transcript.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _transcript,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                if (hasResult) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      widget.onSend(_transcript);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Enviar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
