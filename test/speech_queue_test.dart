import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/core/persistence/preferences_repository.dart';
import 'package:drishti/core/speech/speech_service.dart';

void main() {
  test('speech queue suppresses repeated messages', () async {
    final service = _RecordingSpeechService();
    var now = DateTime.utc(2026, 1, 1, 12);
    final queue = SpeechQueue(service: service, now: () => now);
    const message = SpeechMessage(
      id: 'same-warning',
      text: 'Obstacle ahead',
      priority: SpeechPriority.warning,
      repeatAfter: Duration(seconds: 10),
    );

    await queue.enqueue(message);
    await queue.enqueue(message);
    expect(service.messages, hasLength(1));

    now = now.add(const Duration(seconds: 11));
    await queue.enqueue(message);
    expect(service.messages, hasLength(2));
  });
}

final class _RecordingSpeechService implements SpeechService {
  final List<SpeechMessage> messages = <SpeechMessage>[];

  @override
  Future<SpeechStatus> initialize({required AppLanguage language}) async =>
      SpeechStatus.ready;

  @override
  Future<void> speak(SpeechMessage message) async => messages.add(message);

  @override
  Future<void> stopNonCritical() async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<SpeechStatus> getStatus() async => SpeechStatus.ready;
}
