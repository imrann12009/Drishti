import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/preferences_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../vision/presentation/camera_screen.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../device/presentation/device_connection_screen.dart';
import '../../help/presentation/help_screen.dart';
import '../../navigation/application/navigation_controller.dart';
import '../../navigation/domain/navigation_session.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final NavigationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NavigationController()..addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startDemo() {
    _controller.startDemo();
  }

  Future<void> _stopSession() async {
    await _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardContent(
        state: _controller.state,
        source: _controller.source,
        latestAlert: _controller.latestAlert,
        alertHistory: _controller.alertHistory,
        onStartDemo: _startDemo,
        onStop: () => unawaited(_stopSession()),
        onPause: _controller.pause,
        onResume: _controller.resume,
        onClearWarning: _controller.clearWarning,
        onOpenDevice: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const DeviceConnectionScreen()),
        ),
        onOpenCamera: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
        ),
        onOpenChat: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
        ),
        onOpenSettings: () => setState(() => _selectedIndex = 1),
        onShowUpdateInfo: () => _showComingSoon(context, 'আপডেট ব্যবস্থা'),
      ),
      SettingsScreen(
        repository: SharedPreferencesRepository(SharedPreferencesAsync()),
      ),
      const HelpScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DRISHTI'),
        actions: [
          Semantics(
            label: 'প্রোফাইল ও অ্যাপের তথ্য',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'অ্যাপের তথ্য',
              onPressed: () => _showAbout(context),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'সেটিংস',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: 'সহায়তা',
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '$feature এখনো প্রস্তুত নয় — হার্ডওয়্যার আসার পর সংযোগ করা হবে।')),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DRISHTI',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('প্রোটোটাইপ সংস্করণ 0.1.0+1'),
              SizedBox(height: 12),
              Text(
                  'ডেমো মোড চালু আছে। কোনো বাস্তব ক্যামেরা, সেন্সর, সাবস্ক্রিপশন বা OTA আপডেট এখনো সংযুক্ত নয়।'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.state,
    required this.source,
    required this.latestAlert,
    required this.alertHistory,
    required this.onStartDemo,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    required this.onClearWarning,
    required this.onOpenDevice,
    required this.onOpenCamera,
    required this.onOpenChat,
    required this.onOpenSettings,
    required this.onShowUpdateInfo,
  });

  final NavigationSessionState state;
  final NavigationSource source;
  final NavigationAlert? latestAlert;
  final List<NavigationAlert> alertHistory;
  final VoidCallback onStartDemo;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onClearWarning;
  final VoidCallback onOpenDevice;
  final VoidCallback onOpenCamera;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowUpdateInfo;

  @override
  Widget build(BuildContext context) {
    final active = state != NavigationSessionState.idle;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text('শুভেচ্ছা', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text('আজ কোথায় যেতে চান?',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        _DemoBanner(active: active, source: source),
        if (latestAlert != null) ...[
          const SizedBox(height: 12),
          _AlertBanner(alert: latestAlert!, onDismiss: onClearWarning),
        ],
        const SizedBox(height: 20),
        if (active) ...[
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_stateLabel(state)),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                state == NavigationSessionState.paused ? onResume : onPause,
            icon: Icon(state == NavigationSessionState.paused
                ? Icons.play_arrow
                : Icons.pause),
            label: Text(state == NavigationSessionState.paused
                ? 'ডেমো চালু করুন'
                : 'ডেমো বিরতি দিন'),
          ),
        ] else
          FilledButton.icon(
            onPressed: onStartDemo,
            icon: const Icon(Icons.play_arrow),
            label: const Text('ডেমো ন্যাভিগেশন শুরু করুন'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenDevice,
          icon: const Icon(Icons.bluetooth_disabled_outlined),
          label: const Text('ডিভাইস সংযোগ — শীঘ্রই'),
        ),
        if (alertHistory.isNotEmpty) ...[
          const SizedBox(height: 24),
          _EventHistory(events: alertHistory),
        ],
        const SizedBox(height: 24),
        Text('দ্রুত প্রবেশ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _QuickActionGrid(
          onVoice: onOpenSettings,
          onAlerts: onOpenSettings,
          onEntitlements: onOpenSettings,
          onUpdates: onShowUpdateInfo,
          onCamera: onOpenCamera,
          onChat: onOpenChat,
        ),
        const SizedBox(height: 24),
        const _SafetyCard(),
      ],
    );
  }

  String _stateLabel(NavigationSessionState state) {
    switch (state) {
      case NavigationSessionState.starting:
        return 'শুরু হচ্ছে — থামাতে চাপুন';
      case NavigationSessionState.demoActive:
        return 'ডেমো চলছে — থামান';
      case NavigationSessionState.warning:
        return 'সতর্কতা চলছে — থামান';
      default:
        return 'ন্যাভিগেশন থামান';
    }
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.active, required this.source});

  final bool active;
  final NavigationSource source;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: active ? 'ন্যাভিগেশন চলছে' : 'ন্যাভিগেশন প্রস্তুত',
      child: Card(
        color: AppTheme.sky,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(active ? Icons.play_circle : Icons.science_outlined,
                  color: AppTheme.blue, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active
                          ? (source == NavigationSource.device
                              ? 'ডিভাইস ন্যাভিগেশন চলছে'
                              : 'ডেমো ন্যাভিগেশন চলছে')
                          : 'ডেমো মোড',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      source == NavigationSource.device
                          ? 'ডিভাইস সংযোগের তথ্য যাচাই করা হচ্ছে।'
                          : 'এখানে দেখানো ইভেন্টগুলো সিমুলেটেড। এটি লাইভ ক্যামেরা বা সেন্সর ডেটা নয়।',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alert, required this.onDismiss});

  final NavigationAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.isCritical;
    return Semantics(
      liveRegion: true,
      label: isCritical ? 'জরুরি সতর্কতা: ${alert.message}' : alert.message,
      child: Card(
        color: isCritical ? AppTheme.warningSurface : AppTheme.sky,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCritical ? Icons.warning_amber : Icons.info_outline,
                color: isCritical ? AppTheme.warning : AppTheme.blue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(alert.message)),
              IconButton(
                onPressed: onDismiss,
                tooltip: 'সতর্কতা সরান',
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventHistory extends StatelessWidget {
  const _EventHistory({required this.events});

  final List<NavigationAlert> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.blue),
                const SizedBox(width: 10),
                Text('ডেমো ইভেন্ট ইতিহাস',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...events.take(4).map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      event.isCritical
                          ? Icons.warning_amber
                          : Icons.info_outline,
                      color:
                          event.isCritical ? AppTheme.warning : AppTheme.blue,
                    ),
                    title: Text(event.message),
                    subtitle: const Text('সিমুলেটেড · লাইভ সেন্সর ডেটা নয়'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.onVoice,
    required this.onAlerts,
    required this.onEntitlements,
    required this.onUpdates,
    required this.onCamera,
    required this.onChat,
  });

  final VoidCallback onVoice;
  final VoidCallback onAlerts;
  final VoidCallback onEntitlements;
  final VoidCallback onUpdates;
  final VoidCallback onCamera;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.record_voice_over_outlined, 'ভয়েস সেটিংস', onVoice),
      (Icons.warning_amber_outlined, 'সতর্কতা', onAlerts),
      (Icons.workspace_premium_outlined, 'ফ্রি / প্রো', onEntitlements),
      (Icons.system_update_outlined, 'আপডেট তথ্য', onUpdates),
      (Icons.camera_alt_outlined, 'লাইভ ক্যামেরা ও AI', onCamera),
      (Icons.auto_awesome_outlined, 'Drishti AI Chat', onChat),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final (icon, label, onTap) = actions[index];
        return Semantics(
          button: true,
          label: label,
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppTheme.blue, size: 30),
                    const SizedBox(height: 8),
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warningSurface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.health_and_safety_outlined,
                color: AppTheme.warning, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'নিরাপত্তা মনে রাখুন: DRISHTI কোনো রাস্তা নিরাপদ বলে নিশ্চিত করে না। সতর্ক থাকুন এবং আপনার প্রতিষ্ঠিত চলাচল-পদ্ধতি অনুসরণ করুন।',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
