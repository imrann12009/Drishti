import 'dart:convert';

import 'package:drishti/features/chat/application/chat_service.dart';
import 'package:drishti/features/chat/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  ChatMessage message(String text) => ChatMessage(
        id: 'message',
        author: ChatAuthor.user,
        text: text,
        createdAt: DateTime.utc(2026),
      );

  test('rejects blank chat input before a network request', () async {
    final service = BackendChatService(
        endpoint: Uri.parse('https://chat.example.test/v1/chat'));
    await expectLater(
      service.send(const []),
      throwsA(isA<ChatException>()
          .having((error) => error.code, 'code', 'empty_input')),
    );
    service.dispose();
  });

  test('sends conversation context and returns a backend reply', () async {
    final client = _Client((request) async {
      expect(request.url.path, '/v1/chat');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect((body['messages'] as List).length, 2);
      return http.Response(
          jsonEncode({'reply': 'The founder of Drishti is Imran Ahmad.'}), 200);
    });
    final service = BackendChatService(
      endpoint: Uri.parse('https://chat.example.test/v1/chat'),
      client: client,
    );
    final reply = await service.send([
      message('Who is the founder of Drishti?'),
      ChatMessage(
          id: 'assistant',
          author: ChatAuthor.assistant,
          text: 'I can help.',
          createdAt: DateTime.utc(2026)),
    ]);
    expect(reply, 'The founder of Drishti is Imran Ahmad.');
  });
}

final class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final copied = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await request.finalize().toBytes();
    final response = await handler(copied);
    return http.StreamedResponse(
        Stream.value(response.bodyBytes), response.statusCode,
        headers: response.headers);
  }
}
