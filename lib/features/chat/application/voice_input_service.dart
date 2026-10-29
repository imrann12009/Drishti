import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract interface class VoiceInputService {
  Future<bool> initialize({required void Function(String error) onError});
  Future<void> start(
      {required String localeId,
      required void Function(String words, bool isFinal) onResult});
  Future<void> stop();
  Future<void> cancel();
}

/// Platform speech recognition adapter. Its availability and permissions are
/// determined by the device; the app treats a failure as non-fatal.
final class SpeechToTextVoiceInputService implements VoiceInputService {
  SpeechToTextVoiceInputService({SpeechToText? engine})
      : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;
  void Function(String)? _onError;

  @override
  Future<bool> initialize(
      {required void Function(String error) onError}) async {
    _onError = onError;
    return _engine.initialize(
      onError: (SpeechRecognitionError error) => _onError?.call(error.errorMsg),
    );
  }

  @override
  Future<void> start(
      {required String localeId,
      required void Function(String words, bool isFinal) onResult}) async {
    await _engine.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (SpeechRecognitionResult result) =>
          onResult(result.recognizedWords, result.finalResult),
    );
  }

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> cancel() => _engine.cancel();
}
