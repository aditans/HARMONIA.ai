import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:harmonia_ai/features/focus/providers/focus_controller.dart';
import 'package:harmonia_ai/features/focus/services/face_analyzer.dart';
import 'package:harmonia_ai/features/focus/services/pomodoro_timer.dart';
import 'package:harmonia_ai/shared/services/camera/camera_service_provider.dart';
import 'package:harmonia_ai/shared/widgets/shared_camera_view.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final FaceAnalyzer _faceAnalyzer = FaceAnalyzer();

  Timer? _countdownTimer;
  Timer? _tickTimer;
  int _countdown = 0;
  bool _isProcessing = false;
  bool _faceDetected = false;
  DateTime? _lastFrameAt;
  bool _latestFocused = true;
  String _latestFeedback = '';

  @override
  void initState() {
    super.initState();
    // Register this screen's callback with shared camera service
    Future.microtask(() {
      final cameraService = ref.read(sharedCameraServiceProvider);
      cameraService.setFocusCallback(_onCameraImage);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tickTimer?.cancel();
    _faceAnalyzer.dispose();
    // Unregister callback
    try {
      ref.read(sharedCameraServiceProvider).setFocusCallback(null);
    } catch (e) {
      debugPrint('Error unregistering focus callback: $e');
    }
    super.dispose();
  }

  Future<void> _toggleStartPause(FocusState state) async {
    if (state.isRunning) {
      _countdownTimer?.cancel();
      _tickTimer?.cancel();
      setState(() {
        _countdown = 0;
      });
      debugPrint('Focus paused by user');
      await ref.read(focusControllerProvider.notifier).pauseSession();
      return;
    }
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _faceDetected = false;
      _latestFocused = true;
      _latestFeedback = '';
    });
    debugPrint('Focus countdown started');

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown <= 1) {
        timer.cancel();
        setState(() {
          _countdown = 0;
        });
        ref.read(focusControllerProvider.notifier).startSession();
        _startTickLoop();
        debugPrint('Focus session started');
        return;
      }

      setState(() {
        _countdown -= 1;
      });
    });
  }

  void _startTickLoop() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final FocusState? state = ref.read(focusControllerProvider).valueOrNull;
      if (state == null || !state.isRunning) {
        return;
      }
      ref.read(focusControllerProvider.notifier).tick(
            focused: _latestFocused,
            feedback: _latestFeedback,
          );
    });
  }

  Future<void> _onCameraImage(
    CameraImage image,
    CameraDescription description,
  ) async {
    final FocusState? state = ref.read(focusControllerProvider).valueOrNull;
    if (state == null || !state.isRunning || _isProcessing) {
      return;
    }

    final now = DateTime.now();
    if (_lastFrameAt != null && now.difference(_lastFrameAt!).inMilliseconds < 250) {
      return;
    }
    _lastFrameAt = now;

    final inputImage = _toInputImage(image, description);
    if (inputImage == null) {
      return;
    }

    _isProcessing = true;
    try {
      final faces = await _faceAnalyzer.faceDetector.processImage(inputImage);
      final signal = _faceAnalyzer.evaluateFaceSamples(faces);
      _latestFocused = signal.isFocused;
      _latestFeedback = signal.primaryFeedback;
      if (mounted) {
        setState(() {
          _faceDetected = signal.faceDetected;
        });
      }
    } catch (e) {
      debugPrint('Focus frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription description,
  ) {
    if (image.planes.isEmpty) {
      return null;
    }

    final rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  String _modeLabel(PomodoroState mode) {
    switch (mode) {
      case PomodoroState.work:
        return 'Work';
      case PomodoroState.shortBreak:
        return 'Short Break';
      case PomodoroState.longBreak:
        return 'Long Break';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(sharedCameraServiceProvider);
    final asyncState = ref.watch(focusControllerProvider);
    final FocusState state = asyncState.valueOrNull ??
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

    return Scaffold(
      body: Stack(
        children: [
          SharedCameraView(
            cameraService: cameraService,
            onCameraReady: () {
              debugPrint('Focus camera ready');
            },
            overlay: _FocusOverlay(
              state: state,
              countdown: _countdown,
              faceDetected: _faceDetected,
              onStartPausePressed: () => _toggleStartPause(state),
              modeLabel: _modeLabel(state.mode),
              remaining: _formatDuration(state.modeRemainingSeconds),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AppBar(
                title: const Text('Study Focus'),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusOverlay extends StatelessWidget {
  const _FocusOverlay({
    required this.state,
    required this.countdown,
    required this.faceDetected,
    required this.onStartPausePressed,
    required this.modeLabel,
    required this.remaining,
  });

  final FocusState state;
  final int countdown;
  final bool faceDetected;
  final VoidCallback onStartPausePressed;
  final String modeLabel;
  final String remaining;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.statusLabel} ${faceDetected ? '| Face detected' : '| No face'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$modeLabel | $remaining | Pomodoro ${state.pomodorosCompleted}/4',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Focus ${state.focusPercent.toStringAsFixed(0)}% | Distractions ${state.distractionEvents}',
                  ),
                  if (state.feedbackBanner.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      state.feedbackBanner,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onStartPausePressed,
                      icon:
                          Icon(state.isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(state.isRunning ? 'Pause' : 'Start'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (countdown > 0)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      '$countdown',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
