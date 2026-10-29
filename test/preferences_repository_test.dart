import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/core/persistence/preferences_repository.dart';

void main() {
  test('stores and reads preferences through the repository contract',
      () async {
    final repository = InMemoryPreferencesRepository();
    final updated = (await repository.read()).copyWith(
      language: AppLanguage.english,
      speechRate: 0.7,
      nonCriticalPromptsEnabled: false,
    );

    await repository.write(updated);
    final result = await repository.read();

    expect(result.language, AppLanguage.english);
    expect(result.speechRate, 0.7);
    expect(result.nonCriticalPromptsEnabled, isFalse);
  });
}
