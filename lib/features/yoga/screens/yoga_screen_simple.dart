import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/core/utils/snackbars.dart';
import 'package:harmonia_ai/features/dashboard/providers/dashboard_data_provider.dart';
import 'package:harmonia_ai/features/yoga/data/yoga_config.dart';
import 'package:harmonia_ai/features/yoga/providers/yoga_controller.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/providers/activity_session_provider.dart';
import 'package:harmonia_ai/shared/services/ml/mlkit_pose_service.dart';

class YogaScreenSimple extends ConsumerStatefulWidget {
  const YogaScreenSimple({super.key});

  @override
  ConsumerState<YogaScreenSimple> createState() => _YogaScreenSimpleState();
}

class _YogaScreenSimpleState extends ConsumerState<YogaScreenSimple> {
  late CameraController _cameraController;
  final MlKitPoseService _poseService = MlKitPoseService();

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _isProcessing = false;
  bool _cameraReady = false;
  String? _errorMessage;
  Rect? _poseBounds;
  DateTime? _sessionStartedAt;
  bool _sessionSaved = false;
  String? _selectedYogaMode;

  @override
  void initState() {
    super.initState();
    debugPrint('[Yoga] Initializing camera...');
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController.initialize();
      await _cameraController.startImageStream(_onFrameAvailable);

      setState(() {
        _cameraReady = true;
        _errorMessage = null;
      });
      debugPrint('[Yoga] ✓ Camera ready');
    } catch (e) {
      debugPrint('[Yoga] ✗ Error: $e');
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  void _onFrameAvailable(CameraImage image) {
    final state = ref.read(yogaControllerProvider).valueOrNull;
    if (state == null || !state.isRunning || _isProcessing) return;

    _isProcessing = true;
    _processPose(image).then((_) => _isProcessing = false);
  }

  Future<void> _processPose(CameraImage image) async {
    try {
      final landmarks = await _poseService.detectLandmarks(
        image,
        _cameraController.description,
      );

      if (landmarks.isNotEmpty) {
        final bounds = _computeBounds(landmarks);
        if (mounted) {
          setState(() {
            _poseBounds = bounds;
          });
        }
        await ref
            .read(yogaControllerProvider.notifier)
            .analyzeLandmarks(landmarks);
      } else if (_poseBounds != null && mounted) {
        setState(() {
          _poseBounds = null;
        });
      }
    } catch (e) {
      debugPrint('[Yoga] Error: $e');
    }
  }

  Rect _computeBounds(List<PoseLandmarkData> landmarks) {
    var minX = 1.0;
    var minY = 1.0;
    var maxX = 0.0;
    var maxY = 0.0;

    for (final point in landmarks) {
      minX = point.x < minX ? point.x : minX;
      minY = point.y < minY ? point.y : minY;
      maxX = point.x > maxX ? point.x : maxX;
      maxY = point.y > maxY ? point.y : maxY;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _handleStartPressed() {
    if (_selectedYogaMode == null) {
      showAppSnackBar(context, 'Select a yoga mode first.');
      return;
    }

    final currentState = ref.read(yogaControllerProvider).valueOrNull;
    final sessionState = ref.read(activitySessionProvider);
    if (sessionState.activeActivity == ActivityType.yoga &&
        (currentState == null || !currentState.isRunning)) {
      ref.read(activitySessionProvider.notifier).complete(ActivityType.yoga);
    }

    final activitySession = ref.read(activitySessionProvider.notifier);
    if (!activitySession.tryStart(ActivityType.yoga)) {
      final activeLabel = ref.read(activitySessionProvider).activeLabel;
      if (mounted) {
        showAppSnackBar(
          context,
          'Complete ${activeLabel ?? 'the current activity'} first.',
        );
      }
      return;
    }

    debugPrint('[Yoga] START clicked');
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 3);

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownSeconds <= 0) {
        timer.cancel();
        unawaited(_startSelectedSession());
        _sessionStartedAt = DateTime.now();
        _sessionSaved = false;
        setState(() => _countdownSeconds = 0);
        return;
      }

      setState(() => _countdownSeconds--);
    });
  }

  Future<void> _startSelectedSession() async {
    final controller = ref.read(yogaControllerProvider.notifier);
    final selected = _selectedYogaMode;
    if (selected == 'auto') {
      await controller.startSession(autoDetect: true);
      return;
    }

    if (selected != null) {
      await controller.selectPose(selected);
      await controller.startSession(autoDetect: false);
    }
  }

  void _handlePausePressed() async {
    debugPrint('[Yoga] PAUSE clicked');
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 0);
    await ref.read(yogaControllerProvider.notifier).pauseSession();
    await _persistSession(status: 'paused');
    ref.read(activitySessionProvider.notifier).complete(ActivityType.yoga);
  }

  Future<void> _handleCompletePressed() async {
    debugPrint('[Yoga] COMPLETE clicked');
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 0);
    await ref.read(yogaControllerProvider.notifier).completeSession();
    await _persistSession(status: 'completed');
    ref.read(activitySessionProvider.notifier).complete(ActivityType.yoga);
    setState(() {
      _selectedYogaMode = null;
      _poseBounds = null;
    });
  }

  Future<void> _persistSession({required String status}) async {
    if (_sessionSaved || _sessionStartedAt == null) {
      return;
    }
    final state = ref.read(yogaControllerProvider).valueOrNull;
    if (state == null) {
      return;
    }
    final duration = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    if (duration < 5 && state.holdSeconds == 0) {
      return;
    }
    final service = ref.read(dashboardDataServiceProvider);
    if (service == null) {
      return;
    }
    await service.saveActivitySession(
      activity: 'yoga',
      label: state.poseName,
      durationSeconds: duration,
      holdSeconds: state.holdSeconds,
      status: status,
    );
    _sessionSaved = true;
  }

  @override
  void dispose() {
    unawaited(_persistSession(status: 'interrupted'));
    ref.read(activitySessionProvider.notifier).complete(ActivityType.yoga);
    _countdownTimer?.cancel();
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(yogaControllerProvider).valueOrNull ??
        const YogaState(
          poseName: 'Mountain',
          accuracy: 0,
          stability: 0,
          symmetry: 0,
          totalAccuracy: 0,
          holdSeconds: 0,
          isRunning: false,
          feedback: 'Find your center',
        );
    final activitySession = ref.watch(activitySessionProvider);
    final bool showCompleteButton =
        activitySession.activeActivity == ActivityType.yoga;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yoga Mode'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : !_cameraReady
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1 / _cameraController.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_cameraController),
                          if (_poseBounds != null)
                            CustomPaint(
                              painter: _PoseBoxPainter(_poseBounds!),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedYogaMode,
                              dropdownColor: Colors.grey.shade900,
                              hint: const Text('Select yoga mode', style: TextStyle(color: Colors.white70)),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.white24),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'auto',
                                  child: Text('Auto Detect Category'),
                                ),
                                ...YogaPoseConfig.all.map(
                                  (pose) => DropdownMenuItem<String>(
                                    value: pose.label,
                                    child: Text(pose.label),
                                  ),
                                ),
                              ],
                              onChanged: state.isRunning
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedYogaMode = value;
                                      });
                                    },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              state.poseName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Accuracy: ${state.accuracy}% | Stability: ${state.stability}%',
                            ),
                            const SizedBox(height: 12),
                            Text(state.feedback),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: state.isRunning
                                    ? _handlePausePressed
                                    : _handleStartPressed,
                                icon: Icon(state.isRunning
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                label:
                                    Text(state.isRunning ? 'PAUSE' : 'START'),
                              ),
                            ),
                            if (showCompleteButton) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _handleCompletePressed,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('COMPLETE'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_countdownSeconds > 0)
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$_countdownSeconds',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _PoseBoxPainter extends CustomPainter {
  const _PoseBoxPainter(this.normalizedRect);

  final Rect normalizedRect;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.right * size.width,
      normalizedRect.bottom * size.height,
    );

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _PoseBoxPainter oldDelegate) {
    return oldDelegate.normalizedRect != normalizedRect;
  }
}
