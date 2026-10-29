import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../application/object_detection_service.dart';
import '../domain/vision_result.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  CameraDescription? _description;
  final _detector = ObjectDetectionService();
  VisionResult? _result;
  String? _error;
  bool _streaming = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('কোনো ক্যামেরা পাওয়া যায়নি।');
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _description = description;
        _camera = controller;
        _error = null;
      });
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _initializing = false;
    }
  }

  Future<void> _toggleStream() async {
    final camera = _camera;
    final description = _description;
    if (camera == null || description == null || !camera.value.isInitialized) return;
    if (_streaming || camera.value.isStreamingImages) {
      await _stopStream(camera);
      return;
    }
    try {
      await camera.startImageStream((image) async {
        try {
          final result = await _detector.process(image, description);
          if (mounted && result != null) setState(() => _result = result);
        } catch (_) {
          // A detector failure must not turn an unknown scene into a result.
          if (mounted) setState(() => _error = 'AI object detection ব্যর্থ হয়েছে। আবার চেষ্টা করুন।');
        }
      });
      if (mounted) setState(() => _streaming = true);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'ক্যামেরার image stream চালু করা যায়নি।');
    }
  }

  Future<void> _stopStream(CameraController camera) async {
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _cameraError(error));
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(_stopStream(camera));
      unawaited(camera.dispose());
      _camera = null;
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      unawaited(_initialize());
    }
  }

  String _cameraError(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'ক্যামেরা অনুমতি দেওয়া হয়নি।';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'ক্যামেরা অনুমতি Settings থেকে চালু করুন।';
      default:
        return 'ক্যামেরা চালু করা যায়নি: ${error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('লাইভ ক্যামেরা ও AI পরীক্ষা')),
      body: _error != null
          ? _ErrorView(message: _error!)
          : camera == null || !camera.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Semantics(
                      label: 'লাইভ ক্যামেরা প্রিভিউ। কোনো নিরাপদ পথের নিশ্চয়তা নয়।',
                      child: AspectRatio(
                        aspectRatio: camera.value.aspectRatio,
                        child: CameraPreview(camera),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _toggleStream,
                      icon: Icon(_streaming ? Icons.stop : Icons.center_focus_strong),
                      label: Text(_streaming ? 'AI বিশ্লেষণ বন্ধ করুন' : 'AI object detection শুরু করুন'),
                    ),
                    const SizedBox(height: 12),
                    _ResultCard(result: _result),
                    const SizedBox(height: 12),
                    const Card(
                      color: AppTheme.warningSurface,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'এই পরীক্ষায় 2-D object label দেখানো হয়। Depth, গর্ত, সিঁড়ি, free space বা রাস্তা নিরাপদ—এমন কোনো সিদ্ধান্ত এখানে দেওয়া হয় না।',
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final camera = _camera;
    if (camera != null) unawaited(_stopStream(camera));
    unawaited(camera?.dispose() ?? Future<void>.value());
    unawaited(_detector.close());
    super.dispose();
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final VisionResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('AI ফলাফলের অপেক্ষায়…')));
    }
    if (result!.detections.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('এই frame-এ object label পাওয়া যায়নি।')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI ফলাফল', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result!.detections.take(8).map(
              (detection) => Text(
                '${detection.label} · ${(detection.confidence * 100).round()}% confidence',
              ),
            ),
            const SizedBox(height: 8),
            const Text('Depth: অজানা — আলাদা depth sensor/model প্রয়োজন।'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
