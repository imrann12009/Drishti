import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/persistence/preferences_repository.dart';
import '../../../core/speech/speech_service.dart';
import '../../../core/theme/app_theme.dart';
import '../application/chat_service.dart';
import '../application/voice_input_service.dart';
import '../domain/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.service, this.voiceInput});

  final ChatService? service;
  final VoiceInputService? voiceInput;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _baseUrlValue = String.fromEnvironment('DRISHTI_CHAT_BASE_URL');
  static const _allowHttp = bool.fromEnvironment('DRISHTI_ALLOW_HTTP_CHAT');
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final ChatService _chat;
  late final VoiceInputService _voice;
  final _speech = FlutterTtsSpeechService();
  final List<ChatMessage> _messages = [];
  bool _waiting = false;
  bool _listening = false;
  bool _speaking = false;
  bool _autoRead = false;
  bool _voiceMode = false;
  AppLanguage _voiceLanguage = AppLanguage.bengali;
  String? _error;
  String? _retryText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final endpoint = _baseUrlValue.isEmpty
        ? null
        : Uri.tryParse(_baseUrlValue)?.resolve('/api/chat');
    _chat = widget.service ??
        (endpoint == null
            ? const UnavailableChatService()
            : BackendChatService(
                endpoint: endpoint, allowInsecureHttp: _allowHttp));
    _voice = widget.voiceInput ?? SpeechToTextVoiceInputService();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_stopListening());
      unawaited(_stopSpeaking());
    }
  }

  String get _recognitionLocaleId {
    final language = _input.text.trim().isEmpty
        ? _voiceLanguage
        : RegExp(r'[\u0980-\u09FF]').hasMatch(_input.text)
            ? AppLanguage.bengali
            : AppLanguage.english;
    if (kIsWeb) return language == AppLanguage.bengali ? 'bn-BD' : 'en-US';
    return language == AppLanguage.bengali ? 'bn_BD' : 'en_US';
  }

  Future<void> _send([String? supplied]) async {
    final text = (supplied ?? _input.text).trim();
    if (text.isEmpty || _waiting) {
      if (text.isEmpty) {
        setState(() => _error = 'প্রশ্ন লিখুন বা microphone ব্যবহার করুন।');
      }
      return;
    }
    await _stopListening();
    setState(() {
      _messages.add(_message(ChatAuthor.user, text));
      _input.clear();
      _waiting = true;
      _error = null;
      _retryText = text;
    });
    _scrollToEnd();
    try {
      final response = await _chat.send(_messages);
      if (!mounted) return;
      setState(() {
        _messages.add(_message(ChatAuthor.assistant, response));
        _waiting = false;
        _retryText = null;
      });
      _scrollToEnd();
      if (_autoRead || _voiceMode) unawaited(_speak(response));
    } on ChatException catch (error) {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _waiting = false;
          _error = 'AI উত্তর পাওয়া যায়নি। আবার চেষ্টা করুন।';
        });
      }
    }
  }

  ChatMessage _message(ChatAuthor author, String text) => ChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_messages.length}',
        author: author,
        text: text,
        createdAt: DateTime.now(),
      );

  Future<void> _toggleListening() async {
    if (_listening) return _stopListening();
    if (_waiting || _speaking) return;
    final available = await _voice.initialize(onError: _voiceError);
    if (!available) {
      if (mounted) {
        setState(() => _error =
            'এই device-এ speech recognition পাওয়া যায়নি বা microphone অনুমতি দেওয়া হয়নি।');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _listening = true;
    });
    try {
      await _voice.start(
        localeId: _recognitionLocaleId,
        onResult: (words, isFinal) {
          if (!mounted) return;
          _input.value = TextEditingValue(
              text: words,
              selection: TextSelection.collapsed(offset: words.length));
          if (isFinal) {
            setState(() => _listening = false);
            if (_voiceMode && words.trim().isNotEmpty) unawaited(_send(words));
          }
        },
      );
    } on Object {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = 'কথা শোনা শুরু করা যায়নি। microphone অনুমতি পরীক্ষা করুন।';
        });
      }
    }
  }

  void _voiceError(String error) {
    final isNetworkError = error.toLowerCase().contains('network');
    if (mounted) {
      setState(() {
        _listening = false;
        _error = isNetworkError
            ? 'Browser speech service-এ network সমস্যা হয়েছে। internet চালু আছে কি না দেখুন, Chrome-এর microphone permission Allow করুন, তারপর আবার চেষ্টা করুন।'
            : 'কথা শনাক্ত করা যায়নি: $error';
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    await _voice.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _speak(String text) async {
    await _stopListening();
    final language = RegExp(r'[\u0980-\u09FF]').hasMatch(text)
        ? AppLanguage.bengali
        : AppLanguage.english;
    try {
      final status = await _speech.initialize(language: language);
      if (status == SpeechStatus.unavailable) {
        if (mounted) {
          setState(() => _error = language == AppLanguage.bengali
              ? 'এই device-এ Bengali voice পাওয়া যায়নি। উত্তরটি লেখা হিসেবে পড়ুন।'
              : 'এই device-এ voice output পাওয়া যায়নি।');
        }
        return;
      }
      if (mounted) setState(() => _speaking = true);
      await _speech.speak(SpeechMessage(
          id: 'chat-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          priority: SpeechPriority.normal));
      if (!mounted) return;
      setState(() => _speaking = false);
      if (_voiceMode) unawaited(_toggleListening());
    } on SpeechUnavailableException {
      if (mounted) {
        setState(() {
          _speaking = false;
          _error = 'Voice output পাওয়া যায়নি। লেখা উত্তর ব্যবহার করা যাবে।';
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _speech.stopAll();
    if (mounted) setState(() => _speaking = false);
  }

  void _newChat() {
    unawaited(_stopListening());
    unawaited(_stopSpeaking());
    setState(() {
      _messages.clear();
      _error = null;
      _retryText = null;
      _input.clear();
    });
    _focus.requestFocus();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drishti AI'),
        actions: [
          Semantics(
              label: 'নতুন chat শুরু করুন',
              button: true,
              child: IconButton(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add_comment_outlined),
                  tooltip: 'নতুন chat')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _Header(
                    voiceMode: _voiceMode,
                    listening: _listening,
                    speaking: _speaking),
                Expanded(child: _conversation()),
                if (_error != null)
                  _ErrorBanner(
                      message: _error!,
                      onRetry:
                          _retryText == null ? null : () => _send(_retryText)),
                _controls(),
                _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conversation() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Semantics(
              liveRegion: true,
              child: const Text(
                  'Drishti AI-কে Bangla বা English-এ প্রশ্ন করুন। এটি কোনো camera বা sensor ব্যবহার না করে শুধু আপনার লেখার উত্তর দেবে.',
                  textAlign: TextAlign.center)),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length + (_waiting ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return const _TypingBubble();
        final message = _messages[index];
        return _MessageBubble(
            message: message,
            speaking: _speaking,
            onSpeak: message.author == ChatAuthor.assistant
                ? () => _speak(message.text)
                : null,
            onStop: message.author == ChatAuthor.assistant && _speaking
                ? _stopSpeaking
                : null);
      },
    );
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('উত্তর শুনুন'),
              selected: _autoRead,
              onSelected: (value) => setState(() => _autoRead = value),
            ),
            FilterChip(
              label: const Text('Hands-free voice mode'),
              selected: _voiceMode,
              onSelected: (value) {
                setState(() {
                  _voiceMode = value;
                  _autoRead = value || _autoRead;
                });
                if (value) {
                  unawaited(_toggleListening());
                } else {
                  unawaited(_stopListening());
                }
              },
            ),
            SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(
                  value: AppLanguage.bengali,
                  label: Text('বাংলা'),
                  icon: Icon(Icons.language),
                ),
                ButtonSegment(
                  value: AppLanguage.english,
                  label: Text('English'),
                  icon: Icon(Icons.language),
                ),
              ],
              selected: {_voiceLanguage},
              onSelectionChanged: (value) =>
                  setState(() => _voiceLanguage = value.first),
            ),
            if (_speaking)
              TextButton.icon(
                  onPressed: _stopSpeaking,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('কথা থামান')),
          ],
        ),
      );

  Widget _composer() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: _listening ? 'শোনা বন্ধ করুন' : 'কথা বলে প্রশ্ন করুন',
              child: IconButton.filledTonal(
                onPressed: _waiting || _speaking ? null : _toggleListening,
                icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                iconSize: 28,
                tooltip: _listening ? 'শোনা বন্ধ করুন' : 'কথা বলুন',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                enabled: !_waiting,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                    labelText: 'আপনার প্রশ্ন লিখুন',
                    hintText: 'Bangla বা English-এ লিখুন'),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'AI-কে প্রশ্ন পাঠান',
              child: IconButton.filled(
                onPressed: _waiting ? null : _send,
                icon: const Icon(Icons.send),
                iconSize: 28,
                tooltip: 'পাঠান',
              ),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_voice.cancel());
    unawaited(_speech.stopAll());
    if (_chat is BackendChatService) (_chat).dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.voiceMode,
      required this.listening,
      required this.speaking});
  final bool voiceMode;
  final bool listening;
  final bool speaking;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: listening
            ? 'Drishti AI শুনছে'
            : speaking
                ? 'Drishti AI উত্তর বলছে'
                : voiceMode
                    ? 'Hands-free voice mode চালু'
                    : 'Drishti AI প্রস্তুত',
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.sky, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/images/drishti_vision_wave_logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.record_voice_over, size: 48))),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Drishti AI',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('সংক্ষিপ্ত, সহায়ক Bangla ও English উত্তর')
                ])),
            if (listening || speaking)
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3)),
          ]),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.speaking,
    this.onSpeak,
    this.onStop,
  });
  final ChatMessage message;
  final bool speaking;
  final VoidCallback? onSpeak;
  final VoidCallback? onStop;
  @override
  Widget build(BuildContext context) {
    final user = message.author == ChatAuthor.user;
    return Semantics(
      label:
          '${user ? 'আপনার প্রশ্ন' : 'Drishti AI-এর উত্তর'}: ${message.text}',
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: user ? AppTheme.blue : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: user ? null : Border.all(color: const Color(0xFFD8E1EB))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user ? 'আপনি' : 'Drishti AI',
                style: TextStyle(
                    color: user ? Colors.white : AppTheme.navy,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(message.text,
                style: TextStyle(
                    color: user ? Colors.white : AppTheme.ink,
                    fontSize: 16,
                    height: 1.4)),
            if (onSpeak != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Drishti AI-এর উত্তর শুনুন',
                      child: FilledButton.tonalIcon(
                        onPressed: speaking ? null : onSpeak,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('উত্তর শুনুন'),
                      ),
                    ),
                    if (onStop != null)
                      OutlinedButton.icon(
                        onPressed: onStop,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('থামান'),
                      ),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      label: 'Drishti AI উত্তর তৈরি করছে',
      child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Drishti AI উত্তর তৈরি করছে…')
          ])));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.all(12),
          color: AppTheme.warningSurface,
          child: Row(children: [
            const Icon(Icons.error_outline, color: AppTheme.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('আবার চেষ্টা'))
          ])));
}
