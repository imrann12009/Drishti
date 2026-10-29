import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static final _feedbackUri = Uri.https(
    'github.com',
    '/imrann12009/Drishti/issues/new',
    {
      'title': 'Drishti feedback',
      'body':
          'Please describe your feedback or support request. Do not share passwords, payment details, or other sensitive information.',
    },
  );
  String? _contactError;

  Future<void> _openFeedback() async {
    try {
      final opened = await launchUrl(
        _feedbackUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() =>
            _contactError = 'Message page খোলা যায়নি। পরে আবার চেষ্টা করুন।');
      }
    } on Object {
      if (mounted) {
        setState(() =>
            _contactError = 'Message page খোলা যায়নি। পরে আবার চেষ্টা করুন।');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text('সহায়তা ও নিরাপত্তা',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        const _HelpItem(
          icon: Icons.emergency_outlined,
          title: 'জরুরি নির্দেশনা',
          body:
              'সন্দেহ হলে থামুন, পরিচিত নিরাপদ অবস্থান নিন এবং আপনার স্থানীয় জরুরি সহায়তা বা বিশ্বাসযোগ্য ব্যক্তির সঙ্গে যোগাযোগ করুন।',
        ),
        const _HelpItem(
          icon: Icons.privacy_tip_outlined,
          title: 'গোপনীয়তা',
          body:
              'ডেমো মোডে কোনো লাইভ ক্যামেরা বা ক্লাউড দৃশ্য-বিশ্লেষণ চালু নেই। রেকর্ডিং ও আপলোডের আগে আলাদা সম্মতি প্রয়োজন হবে।',
        ),
        const _HelpItem(
          icon: Icons.person_outline,
          title: 'প্রতিষ্ঠাতার তথ্য',
          body:
              'Drishti-এর প্রতিষ্ঠাতা Imran Ahmad। তিনি Gono Bishwabidyalay-এর CSE বিভাগে পড়াশোনা করেন এবং সাভারে থাকেন। তাঁর উচ্চতা ৫ ফুট ৫ ইঞ্চি, relationship status single এবং জানানো net worth ০ টাকা।',
        ),
        const _HelpItem(
          icon: Icons.bluetooth_disabled_outlined,
          title: 'ডিভাইস সংযোগ সমস্যা',
          body:
              'হার্ডওয়্যার প্রোটোকল এখনো provisional। সংযোগ, সেন্সর প্যাকেট বা firmware update সম্পূর্ণ সমর্থিত নয়।',
        ),
        const _HelpItem(
          icon: Icons.info_outline,
          title: 'অ্যাপের সীমাবদ্ধতা',
          body:
              'সিমুলেটেড সতর্কতা বাস্তব পরিবেশের পূর্বাভাস নয়। কোনো AI ফলাফলকে রাস্তা পারাপারের নিরাপত্তার নিশ্চয়তা হিসেবে ব্যবহার করবেন না।',
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Help section: প্রতিষ্ঠাতাকে message করুন',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                    'Feedback পাঠাতে GitHub issue form খুলবে। আপনার GitHub account লাগবে এবং messageটি public হবে; password, payment বা সংবেদনশীল তথ্য লিখবেন না। প্রতিষ্ঠাতা repository-এর Issues tab-এ message পড়তে পারবেন।'),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'প্রতিষ্ঠাতাকে public feedback পাঠান',
                  child: FilledButton.icon(
                    onPressed: _openFeedback,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Message / feedback পাঠান'),
                  ),
                ),
                if (_contactError != null) ...[
                  const SizedBox(height: 8),
                  Semantics(liveRegion: true, child: Text(_contactError!)),
                ],
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.description_outlined),
          label: const Text('সম্পূর্ণ ব্যবহার নির্দেশিকা — শীঘ্রই'),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
