import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:harmonia_ai/core/utils/snackbars.dart';
import 'package:harmonia_ai/features/dashboard/providers/dashboard_data_provider.dart';
import 'package:harmonia_ai/features/focus/providers/focus_controller.dart';
import 'package:harmonia_ai/features/focus/services/face_analyzer.dart';
import 'package:harmonia_ai/features/focus/services/pomodoro_timer.dart';
import 'package:harmonia_ai/shared/providers/activity_session_provider.dart';

class FocusScreenSimple extends ConsumerStatefulWidget {
  const FocusScreenSimple({super.key});

  @override
  ConsumerState<FocusScreenSimple> createState() => _FocusScreenSimpleState();
}

class _FocusScreenSimpleState extends ConsumerState<FocusScreenSimple> {
  late CameraController _cameraController;
  final FaceAnalyzer _faceAnalyzer = FaceAnalyzer();

  Timer? _countdownTimer;
  Timer? _tickTimer;
  int _countdownSeconds = 0;
  bool _isProcessing = false;
  bool _cameraReady = false;
  String? _errorMessage;
  bool _faceDetected = false;
  bool _latestFocused = true;
  DateTime? _sessionStartedAt;
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Focus] Initializing camera...');
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
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController.initialize();
      await _cameraController.startImageStream(_onFrameAvailable);

      setState(() {
        _cameraReady = true;
        _errorMessage = null;
      });
      debugPrint('[Focus] ✓ Camera ready');
    } catch (e) {
      debugPrint('[Focus] ✗ Error: $e');
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  void _onFrameAvailable(CameraImage image) {
    if (_isProcessing) return;

    _isProcessing = true;
    _processFace(image).then((_) => _isProcessing = false);
  }

  Future<void> _processFace(CameraImage image) async {
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceAnalyzer.faceDetector.processImage(inputImage);
      final signal = _faceAnalyzer.evaluateFaceSamples(faces);

      _latestFocused = signal.isFocused;

      if (mounted) {
        setState(() {
          _faceDetected = signal.faceDetected;
        });

        if (signal.primaryFeedback.isNotEmpty) {
          ref.read(focusControllerProvider.notifier).updateFeedback(
                signal.primaryFeedback,
              );
        }
      }
    } catch (e) {
      debugPrint('[Focus] Error: $e');
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    if (image.planes.isEmpty) return null;

    final rotation = InputImageRotationValue.fromRawValue(
            _cameraController.description.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final bytes = _convertYuv420ToNv21(image);

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    int offset = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final int chromaHeight = height ~/ 2;
    final int chromaWidth = width ~/ 2;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < chromaHeight; row++) {
      for (int col = 0; col < chromaWidth; col++) {
        final int vIndex = row * vPlane.bytesPerRow + col * vPixelStride;
        final int uIndex = row * uPlane.bytesPerRow + col * uPixelStride;
        nv21[offset++] = vPlane.bytes[vIndex];
        nv21[offset++] = uPlane.bytes[uIndex];
      }
    }

    return nv21;
  }

  void _handleStartPressed() {
    debugPrint('[Focus] START clicked');

    if (!_faceDetected) {
      if (mounted) {
        showAppSnackBar(context, 'No face detected. Look at the camera first.');
      }
      return;
    }

    final currentState = ref.read(focusControllerProvider).valueOrNull;
    final sessionState = ref.read(activitySessionProvider);
    if (sessionState.activeActivity == ActivityType.focus &&
        (currentState == null || !currentState.isRunning)) {
      ref.read(activitySessionProvider.notifier).complete(ActivityType.focus);
    }

    final activitySession = ref.read(activitySessionProvider.notifier);
    if (!activitySession.tryStart(ActivityType.focus)) {
      final activeLabel = ref.read(activitySessionProvider).activeLabel;
      if (mounted) {
        showAppSnackBar(
          context,
          'Complete ${activeLabel ?? 'the current activity'} first.',
        );
      }
      return;
    }

    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 3);

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownSeconds <= 0) {
        timer.cancel();
        final targetMinutes = ref.read(dailyMetricsProvider).valueOrNull?.focusTargetMinutes;
        ref.read(focusControllerProvider.notifier).startSession(
              workMinutes: targetMinutes,
            );
        _sessionStartedAt = DateTime.now();
        _sessionSaved = false;
        _startTicking();
        setState(() => _countdownSeconds = 0);
        return;
      }

      setState(() => _countdownSeconds--);
    });
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(Duration(seconds: 1), (_) {
      final state = ref.read(focusControllerProvider).valueOrNull;
      if (state == null || !state.isRunning) return;

      ref.read(focusControllerProvider.notifier).tick(
            focused: _latestFocused,
            feedback: _faceDetected ? 'Face detected' : 'No face detected',
          );
    });
  }

  void _handlePausePressed() async {
    debugPrint('[Focus] PAUSE clicked');
    _countdownTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _countdownSeconds = 0);
    await ref.read(focusControllerProvider.notifier).pauseSession();
    await _persistSession(status: 'paused');
    ref.read(activitySessionProvider.notifier).complete(ActivityType.focus);
  }

  Future<void> _handleCompletePressed() async {
    debugPrint('[Focus] COMPLETE clicked');
    _countdownTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _countdownSeconds = 0);
    await ref.read(focusControllerProvider.notifier).completeSession();
    await _persistSession(status: 'completed');
    ref.read(activitySessionProvider.notifier).complete(ActivityType.focus);
    _latestFocused = true;
    if (mounted) {
      setState(() {
        _faceDetected = false;
      });
    }
  }

  Future<void> _persistSession({required String status}) async {
    if (_sessionSaved || _sessionStartedAt == null) {
      return;
    }
    final state = ref.read(focusControllerProvider).valueOrNull;
    if (state == null) {
      return;
    }
    final duration = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    if (duration < 5 && state.totalSeconds == 0) {
      return;
    }
    final service = ref.read(dashboardDataServiceProvider);
    if (service == null) {
      return;
    }
    await service.saveActivitySession(
      activity: 'focus',
      label: 'Pomodoro',
      durationSeconds: duration,
      focusPercent: state.focusPercent,
      status: status,
    );
    _sessionSaved = true;
  }

  @override
  void dispose() {
    unawaited(_persistSession(status: 'interrupted'));
    ref.read(activitySessionProvider.notifier).complete(ActivityType.focus);
    _countdownTimer?.cancel();
    _tickTimer?.cancel();
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _faceAnalyzer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusControllerProvider).valueOrNull ??
        const FocusState(
          focusPercent: 0,
          distractionEvents: 0,
          pomodorosCompleted: 0,
          isRunning: false,
          totalSeconds: 0,
          focusedSeconds: 0,
          statusLabel: 'FOCUSED',
          feedbackBanner: '',
          mode: PomodoroState.work,
          modeRemainingSeconds: PomodoroTimerMachine.defaultWorkSeconds,
          modeTotalSeconds: PomodoroTimerMachine.defaultWorkSeconds,
          longestFocusStreakSeconds: 0,
          currentFocusStreakSeconds: 0,
          distractionTimeline: [],
          notifications: [],
        );
    final activitySession = ref.watch(activitySessionProvider);
    final bool showCompleteButton =
        activitySession.activeActivity == ActivityType.focus;

    return PopScope(
      canPop: !state.isRunning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.isRunning && mounted) {
          showAppSnackBar(context, 'Complete focus session before leaving this screen.');
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Focus Mode'),
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
                      child: CameraPreview(_cameraController),
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
                            Text(
                              'Focus: ${state.focusPercent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _PomodoroCircle(
                              remainingSeconds: state.modeRemainingSeconds,
                              totalSeconds: state.modeTotalSeconds,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Face: ${_faceDetected ? "✓ Detected" : "✗ Not detected"}',
                            ),
                            const SizedBox(height: 12),
                            Text(state.feedbackBanner),
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
      ),
    );
  }
}

class _PomodoroCircle extends StatelessWidget {
  const _PomodoroCircle({
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  final int remainingSeconds;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final safeTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final progress = (remainingSeconds / safeTotal).clamp(0.0, 1.0);
    final mm = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CustomPaint(
                painter: _PomodoroCirclePainter(progress: progress),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$mm:$ss',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Pomodoro Left',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PomodoroCirclePainter extends CustomPainter {
  const _PomodoroCirclePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final bg = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final fg = Paint()
      ..color = const Color(0xFF2ED573)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _PomodoroCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
