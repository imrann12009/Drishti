import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/updates/android_apk_installer.dart';
import '../../../core/updates/update_configuration.dart';
import '../../../core/updates/update_manager.dart';

class UpdateInfoScreen extends StatefulWidget {
  const UpdateInfoScreen({super.key, required this.manager});

  final UpdateManager manager;

  @override
  State<UpdateInfoScreen> createState() => _UpdateInfoScreenState();
}

class _UpdateInfoScreenState extends State<UpdateInfoScreen>
    with WidgetsBindingObserver {
  late final AndroidApkInstaller _installer;
  UpdateSnapshot? _snapshot;
  String? _actionMessage;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _installer = AndroidApkInstaller()..progress.addListener(_refresh);
    unawaited(_load(refresh: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load(refresh: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _installer
      ..progress.removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool refresh = false}) async {
    try {
      final result = await widget.manager.check(refresh: refresh);
      if (mounted) {
        setState(() => _snapshot = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionMessage = 'বর্তমান সংস্করণ পড়া যায়নি।');
      }
    }
  }

  Future<void> _apply() async {
    final snapshot = _snapshot;
    final config = snapshot?.configuration;
    if (snapshot == null || config == null || !snapshot.canUpdate) return;
    setState(() {
      _applying = true;
      _actionMessage = null;
    });
    try {
      if (config.distribution == UpdateDistribution.googlePlay) {
        await _startGooglePlayUpdate();
      } else {
        final result = await _installer.downloadVerifyAndOpen(
          configuration: config,
          installed: snapshot.installed,
        );
        if (!mounted) {
          return;
        }
        _actionMessage = switch (result.status) {
          ApkInstallStatus.installationStarted =>
            'Android-এর installation confirmation screen খোলা হয়েছে। ইনস্টল সম্পন্ন হলে অ্যাপে ফিরে আসুন।',
          ApkInstallStatus.permissionRequired =>
            'এই উৎস থেকে অ্যাপ ইনস্টলের অনুমতি দিন, তারপর আবার “আপডেট করুন” চাপুন।',
          ApkInstallStatus.failed => result.message,
        };
      }
    } catch (_) {
      if (mounted) {
        _actionMessage = 'আপডেট শুরু করা যায়নি। পরে আবার চেষ্টা করুন।';
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _startGooglePlayUpdate() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        _actionMessage = 'Google Play update শুধু Android-এ পাওয়া যায়।';
      }
      return;
    }
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      if (mounted) {
        _actionMessage = 'Google Play-এ এখন কোনো উপলব্ধ আপডেট পাওয়া যায়নি।';
      }
      return;
    }
    await InAppUpdate.performImmediateUpdate();
    if (mounted) {
      _actionMessage = 'Google Play update শুরু হয়েছে। নির্দেশনা অনুসরণ করুন।';
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('আপডেট তথ্য')),
      body: snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _StatusCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  if (snapshot.configuration case final config?)
                    _ReleaseDetails(snapshot: snapshot, configuration: config),
                  if (snapshot.message != null) ...[
                    const SizedBox(height: 16),
                    _Notice(message: snapshot.message!),
                  ],
                  if (_actionMessage != null) ...[
                    const SizedBox(height: 16),
                    _Notice(message: _actionMessage!),
                  ],
                  const SizedBox(height: 24),
                  if (_applying ||
                      _installer.progress.value.stage != ApkDownloadStage.idle)
                    _DownloadProgress(progress: _installer.progress.value),
                  if (snapshot.canUpdate) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _applying ? null : _apply,
                      icon: Icon(_applying
                          ? Icons.hourglass_top
                          : Icons.system_update_alt),
                      label: Text(
                          _applying ? 'আপডেট প্রস্তুত হচ্ছে…' : 'আপডেট করুন'),
                    ),
                    if (_installer.progress.value.stage ==
                        ApkDownloadStage.downloading)
                      TextButton.icon(
                        onPressed: _installer.cancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('ডাউনলোড বাতিল করুন'),
                      ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'নিরাপত্তার জন্য Android ইনস্টল করার আগে আপনার সম্মতি চাইবে। অচেনা উৎসের অনুমতি কেবল DRISHTI-এর অফিসিয়াল signed APK-এর জন্য দিন।',
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});
  final UpdateSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final required = snapshot.status == UpdateStatus.required;
    final available = snapshot.status == UpdateStatus.available || required;
    final title = switch (snapshot.status) {
      UpdateStatus.upToDate => 'আপনার DRISHTI অ্যাপটি সর্বশেষ ভার্সনে রয়েছে।',
      UpdateStatus.available => 'DRISHTI-এর একটি নতুন আপডেট পাওয়া গেছে।',
      UpdateStatus.required => 'DRISHTI চালিয়ে যেতে একটি আপডেট প্রয়োজন।',
      UpdateStatus.unavailable =>
        'এখন কোনো ব্যবহারযোগ্য আপডেট পাওয়া যাচ্ছে না।',
      UpdateStatus.error => 'আপডেট তথ্য পাওয়া যায়নি।',
      UpdateStatus.checking => 'আপডেট দেখা হচ্ছে…',
    };
    return Card(
      color: required ? AppTheme.warningSurface : AppTheme.sky,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              required
                  ? Icons.warning_amber_rounded
                  : available
                      ? Icons.system_update_alt
                      : Icons.verified_outlined,
              color: required ? AppTheme.warning : AppTheme.blue,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseDetails extends StatelessWidget {
  const _ReleaseDetails({required this.snapshot, required this.configuration});
  final UpdateSnapshot snapshot;
  final UpdateConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(configuration.updateTitle,
                style: Theme.of(context).textTheme.titleLarge),
            if (configuration.updateDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(configuration.updateDescription),
            ],
            const SizedBox(height: 14),
            _Detail(
                label: 'বর্তমান ভার্সন',
                value:
                    '${snapshot.installed.versionName} (${snapshot.installed.versionCode})'),
            _Detail(
                label: 'নতুন ভার্সন',
                value:
                    '${configuration.latestVersionName} (${configuration.latestVersionCode})'),
            _Detail(
                label: 'আপডেট প্রকাশের তারিখ',
                value: configuration.releaseDate.isEmpty
                    ? 'তথ্য দেওয়া হয়নি'
                    : configuration.releaseDate),
            if (configuration.apkSizeBytes != null)
              _Detail(
                  label: 'আপডেটের আকার',
                  value: _formatBytes(configuration.apkSizeBytes!)),
            if (configuration.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('নতুন ফিচার, বাগ ফিক্স ও উন্নতি',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...configuration.releaseNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('• $note'),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 145, child: Text(label)),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: AppTheme.warningSurface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppTheme.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ]),
        ),
      );
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress});
  final ApkDownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    final percentage = progress.percentage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(progress.stage == ApkDownloadStage.verifying
            ? 'APK-এর নিরাপত্তা যাচাই করা হচ্ছে…'
            : 'ডাউনলোড হচ্ছে${percentage == null ? '' : ': $percentage%'}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: percentage == null ? null : percentage / 100),
      ],
    );
  }
}
