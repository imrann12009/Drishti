import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/chat_message.dart';

abstract interface class ChatService {
  Future<String> send(List<ChatMessage> messages);
}

/// HTTPS client for DRISHTI's server-side AI gateway. Provider credentials are
/// never accepted or stored by this Flutter client.
final class BackendChatService implements ChatService {
  BackendChatService({
    required this.endpoint,
    this.authorizationTokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.allowInsecureHttp = false,
  }) : _client = client ?? http.Client();

  final Uri endpoint;
  final Future<String?> Function()? authorizationTokenProvider;
  final http.Client _client;
  final Duration timeout;

  /// Development-only support for Android emulator or trusted-LAN HTTP.
  final bool allowInsecureHttp;

  @override
  Future<String> send(List<ChatMessage> messages) async {
    if (!messages.any((message) => message.author == ChatAuthor.user)) {
      throw const ChatException('empty_input', 'কোনো প্রশ্ন লেখা হয়নি।');
    }
    if (endpoint.scheme != 'https' && !allowInsecureHttp) {
      throw const ChatException(
          'insecure_endpoint', 'AI server-এর HTTPS address প্রয়োজন।');
    }
    try {
      final token = await authorizationTokenProvider?.call();
      final values = messages.toList(growable: false);
      final recent = values.skip(values.length > 20 ? values.length - 20 : 0);
      final response = await _client
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
              if (token != null && token.isNotEmpty)
                'authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'messages':
                  recent.map((message) => message.toRequestMap()).toList()
            }),
          )
          .timeout(timeout);
      final body = _readJson(response.body);
      if (response.statusCode == 401) {
        throw const ChatException(
            'unauthorized', 'AI chat ব্যবহারের জন্য নিরাপদ সাইন-ইন প্রয়োজন।');
      }
      if (response.statusCode == 429) {
        throw const ChatException(
            'rate_limited', 'অনেক অনুরোধ হয়েছে। একটু পরে আবার চেষ্টা করুন।');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatException(
            'backend_error',
            _safeError(body) ??
                'AI এখন উত্তর দিতে পারছে না। আবার চেষ্টা করুন।');
      }
      final reply = body?['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const ChatException(
            'invalid_response', 'AI server থেকে গ্রহণযোগ্য উত্তর পাওয়া যায়নি।');
      }
      return reply.trim();
    } on TimeoutException {
      throw const ChatException(
          'timeout', 'AI উত্তর দিতে বেশি সময় নিচ্ছে। আবার চেষ্টা করুন।');
    } on ChatException {
      rethrow;
    } on Object {
      throw const ChatException('network_error',
          'AI server-এর সঙ্গে সংযোগ করা যায়নি। ইন্টারনেট পরীক্ষা করুন।');
    }
  }

  Map<String, dynamic>? _readJson(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _safeError(Map<String, dynamic>? body) {
    final error = body?['error'];
    return error is String && error.length <= 160 ? error : null;
  }

  void dispose() => _client.close();
}

final class UnavailableChatService implements ChatService {
  const UnavailableChatService();

  @override
  Future<String> send(List<ChatMessage> messages) async =>
      throw const ChatException(
        'not_configured',
        'AI chat server এখনো configure করা হয়নি।',
      );
}

final class ChatException implements Exception {
  const ChatException(this.code, this.message);

  final String code;
  final String message;
}
