import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text('সহায়তা ও নিরাপত্তা', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        const _HelpItem(
          icon: Icons.emergency_outlined,
          title: 'জরুরি নির্দেশনা',
          body: 'সন্দেহ হলে থামুন, পরিচিত নিরাপদ অবস্থান নিন এবং আপনার স্থানীয় জরুরি সহায়তা বা বিশ্বাসযোগ্য ব্যক্তির সঙ্গে যোগাযোগ করুন।',
        ),
        const _HelpItem(
          icon: Icons.privacy_tip_outlined,
          title: 'গোপনীয়তা',
          body: 'ডেমো মোডে কোনো লাইভ ক্যামেরা বা ক্লাউড দৃশ্য-বিশ্লেষণ চালু নেই। রেকর্ডিং ও আপলোডের আগে আলাদা সম্মতি প্রয়োজন হবে।',
        ),
        const _HelpItem(
          icon: Icons.bluetooth_disabled_outlined,
          title: 'ডিভাইস সংযোগ সমস্যা',
          body: 'হার্ডওয়্যার প্রোটোকল এখনো provisional। সংযোগ, সেন্সর প্যাকেট বা firmware update সম্পূর্ণ সমর্থিত নয়।',
        ),
        const _HelpItem(
          icon: Icons.info_outline,
          title: 'অ্যাপের সীমাবদ্ধতা',
          body: 'সিমুলেটেড সতর্কতা বাস্তব পরিবেশের পূর্বাভাস নয়। কোনো AI ফলাফলকে রাস্তা পারাপারের নিরাপত্তার নিশ্চয়তা হিসেবে ব্যবহার করবেন না।',
        ),
        const SizedBox(height: 8),
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
  const _HelpItem({required this.icon, required this.title, required this.body});

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
