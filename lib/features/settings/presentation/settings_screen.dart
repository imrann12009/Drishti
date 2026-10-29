import 'package:flutter/material.dart';
import '../../../core/persistence/preferences_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../subscription/presentation/subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository});

  final PreferencesRepository? repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final bool _criticalAlerts = true;
  bool _nonCriticalPrompts = true;
  bool _demoMode = true;
  double _speed = 0.5;
  double _volume = 0.8;
  bool _loading = true;
  late final PreferencesRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InMemoryPreferencesRepository();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await _repository.read();
    if (!mounted) return;
    setState(() {
      _nonCriticalPrompts = preferences.nonCriticalPromptsEnabled;
      _demoMode = preferences.demoModeEnabled;
      _speed = preferences.speechRate;
      _volume = preferences.volume;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _repository.write(
      AppPreferences(
        speechRate: _speed,
        volume: _volume,
        nonCriticalPromptsEnabled: _nonCriticalPrompts,
        demoModeEnabled: _demoMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text('সেটিংস', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'ভয়েস ও ভাষা',
          icon: Icons.record_voice_over_outlined,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('ভাষা'),
              subtitle: Text('বাংলা (প্রস্তাবিত) · ইংরেজি ঐচ্ছিক'),
              trailing: Icon(Icons.chevron_right),
            ),
            _SliderTile(
              label: 'কথার গতি',
              value: _speed,
               onChanged: (value) {
                 setState(() => _speed = value);
                 _persist();
               },

            ),
            _SliderTile(
              label: 'ভলিউম',
              value: _volume,
               onChanged: (value) {
                 setState(() => _volume = value);
                 _persist();
               },

            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('ভয়েস সার্ভিস'),
              subtitle: Text('ফোনে কনফিগার করা TTS পাওয়া গেলে ব্যবহার হবে; অফলাইন সমর্থন এখনো যাচাই করা হয়নি।'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'সতর্কতা',
          icon: Icons.warning_amber_outlined,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('জরুরি সতর্কতা'),
              subtitle: const Text('বন্ধ করা যাবে না; নিরাপত্তার জন্য সবসময় চালু থাকবে।'),
              value: _criticalAlerts,
              onChanged: (_) {},
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('অ-জরুরি ভয়েস প্রম্পট'),
              value: _nonCriticalPrompts,
               onChanged: (value) {
                 setState(() => _nonCriticalPrompts = value);
                 _persist();
               },

            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'পরীক্ষা ও অ্যাক্সেস',
          icon: Icons.developer_mode_outlined,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('ডেমো মোড'),
              subtitle: const Text('সিমুলেটেড ইভেন্ট ব্যবহার করুন; এটি বাস্তব সেন্সর ডেটা নয়।'),
              value: _demoMode,
               onChanged: (value) {
                 setState(() => _demoMode = value);
                 _persist();
               },

            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('সাবস্ক্রিপশন'),
              subtitle: const Text('Google Play catalog ও secure verification setup দেখুন।'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Card(
          color: AppTheme.sky,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('অনুমতি প্রয়োজন হলে আগে সহজ বাংলায় কারণ জানানো হবে। ক্যামেরা, মাইক্রোফোন, ব্লুটুথ বা লোকেশন ডিফল্টভাবে চাওয়া হবে না।'),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.blue),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Slider(
          value: value,
          onChanged: onChanged,
          label: '${(value * 100).round()}%',
        ),
      ],
    );
  }
}
