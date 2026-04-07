import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/exercise/data/exercise_config.dart';
import 'package:harmonia_ai/features/dashboard/providers/dashboard_data_provider.dart';
import 'package:harmonia_ai/features/exercise/providers/exercise_controller.dart';
import 'package:harmonia_ai/core/utils/snackbars.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/services/ml/mlkit_pose_service.dart';
import 'package:harmonia_ai/shared/providers/activity_session_provider.dart';

/// Simplified Exercise Screen - straightforward state management
class ExerciseScreenV2 extends ConsumerStatefulWidget {
  const ExerciseScreenV2({super.key});

  @override
  ConsumerState<ExerciseScreenV2> createState() => _ExerciseScreenV2State();
}

class _ExerciseScreenV2State extends ConsumerState<ExerciseScreenV2> {
  late CameraController _cameraController;
  final MlKitPoseService _poseService = MlKitPoseService();
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _isProcessing = false;
  bool _cameraReady = false;
  String? _errorMessage;
  Rect? _poseBounds;
  DateTime? _sessionStartedAt;
  bool _sessionSaved = false;
  String? _selectedExerciseMode;

  @override
  void initState() {
    super.initState();
    debugPrint('═════════════════════════════════════════');
    debugPrint('[Exercise V2] initState - initializing camera');
    debugPrint('═════════════════════════════════════════');
    _initCamera(preferredLens: CameraLensDirection.front);
  }

  Future<void> _initCamera({required CameraLensDirection preferredLens}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera available';
        });
        return;
      }

      final targetCamera = cameras.firstWhere(
        (c) => c.lensDirection == preferredLens,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _currentLensDirection = targetCamera.lensDirection;

      await _cameraController.initialize();
      debugPrint('[Exercise V2] ✓ Camera initialized');

      // Start image stream immediately
      await _cameraController.startImageStream(_onFrameAvailable);
      debugPrint('[Exercise V2] ✓ Image stream started');

      setState(() {
        _cameraReady = true;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[Exercise V2] ✗ Camera init error: $e');
      setState(() {
        _errorMessage = 'Camera error: $e';
      });
    }
  }

  Future<void> _switchCameraForSelection(String? selectedMode) async {
    if (!_cameraReady) {
      return;
    }

    CameraLensDirection preferred = CameraLensDirection.front;
    if (selectedMode != null && selectedMode != 'auto') {
      final config = ExerciseConfig.all.firstWhere(
        (c) => c.label == selectedMode,
        orElse: () => ExerciseConfig.all.first,
      );
      preferred = config.cameraPreference == CameraPreference.side
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    }

    if (preferred == _currentLensDirection) {
      return;
    }

    try {
      await _cameraController.stopImageStream();
      await _cameraController.dispose();
    } catch (_) {}

    setState(() {
      _cameraReady = false;
      _poseBounds = null;
    });
    await _initCamera(preferredLens: preferred);
  }

  void _onFrameAvailable(CameraImage image) {
    final state = ref.read(exerciseControllerProvider).valueOrNull;

    // Only process if session is running
    if (state == null || !state.isRunning || _isProcessing) {
      return;
    }

    _isProcessing = true;
    _processPose(image).then((_) {
      _isProcessing = false;
    });
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
            .read(exerciseControllerProvider.notifier)
            .analyzeLandmarks(landmarks);
      } else if (_poseBounds != null && mounted) {
        setState(() {
          _poseBounds = null;
        });
      }
    } catch (e) {
      debugPrint('[Exercise V2] Pose processing error: $e');
    }
  }

  Rect _computeBounds(List<PoseLandmarkData> landmarks) {
    var minX = 1.0;
    var minY = 1.0;
    var maxX = 0.0;
    var maxY = 0.0;

    for (final point in landmarks) {
      final x = point.x;
      final y = point.y;
      minX = x < minX ? x : minX;
      minY = y < minY ? y : minY;
      maxX = x > maxX ? x : maxX;
      maxY = y > maxY ? y : maxY;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _handleStartPressed() {
    if (_selectedExerciseMode == null) {
      showAppSnackBar(context, 'Select an exercise mode first.');
      return;
    }

    final currentState = ref.read(exerciseControllerProvider).valueOrNull;
    final sessionState = ref.read(activitySessionProvider);
    if (sessionState.activeActivity == ActivityType.exercise &&
        (currentState == null || !currentState.isRunning)) {
      ref.read(activitySessionProvider.notifier).complete(ActivityType.exercise);
    }

    final activitySession = ref.read(activitySessionProvider.notifier);
    if (!activitySession.tryStart(ActivityType.exercise)) {
      final activeLabel = ref.read(activitySessionProvider).activeLabel;
      if (mounted) {
        showAppSnackBar(
          context,
          'Complete ${activeLabel ?? 'the current activity'} first.',
        );
      }
      return;
    }

    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║    START BUTTON CLICKED                ║');
    debugPrint('╚════════════════════════════════════════╝');

    _countdownTimer?.cancel();

    setState(() {
      _countdownSeconds = 3;
    });

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      debugPrint('[Exercise V2] Countdown: $_countdownSeconds');

      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownSeconds <= 0) {
        timer.cancel();
        debugPrint('[Exercise V2] ✓ Starting session!');
        unawaited(_startSelectedSession());
        _sessionStartedAt = DateTime.now();
        _sessionSaved = false;
        setState(() {
          _countdownSeconds = 0;
        });
        return;
      }

      setState(() {
        _countdownSeconds--;
      });
    });
  }

  Future<void> _startSelectedSession() async {
    final controller = ref.read(exerciseControllerProvider.notifier);
    final selected = _selectedExerciseMode;
    if (selected == 'auto') {
      await controller.startSessionWithMode(autoDetect: true);
      return;
    }

    final config = ExerciseConfig.all.firstWhere(
      (c) => c.label == selected,
      orElse: () => ExerciseConfig.all.first,
    );
    await controller.selectExercise(config);
    await controller.startSessionWithMode(autoDetect: false);
  }

  void _handlePausePressed() async {
    debugPrint('[Exercise V2] Pause button clicked');
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 0;
    });
    await ref.read(exerciseControllerProvider.notifier).pauseSession();
    await _persistSession(status: 'paused');
    ref.read(activitySessionProvider.notifier).complete(ActivityType.exercise);
  }

  Future<void> _handleCompletePressed() async {
    debugPrint('[Exercise V2] Complete button clicked');
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 0;
    });
    await ref.read(exerciseControllerProvider.notifier).completeSession();
    await _persistSession(status: 'completed');
    ref.read(activitySessionProvider.notifier).complete(ActivityType.exercise);
    setState(() {
      _selectedExerciseMode = null;
      _poseBounds = null;
    });
  }

  Future<void> _persistSession({required String status}) async {
    if (_sessionSaved || _sessionStartedAt == null) {
      return;
    }
    final state = ref.read(exerciseControllerProvider).valueOrNull;
    if (state == null) {
      return;
    }
    final duration = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    if (duration < 5 && state.reps == 0) {
      return;
    }
    final service = ref.read(dashboardDataServiceProvider);
    if (service == null) {
      return;
    }
    await service.saveActivitySession(
      activity: 'exercise',
      label: state.exerciseLabel,
      durationSeconds: duration,
      reps: state.reps,
      holdSeconds: state.plankHoldSeconds,
      status: status,
    );
    _sessionSaved = true;
  }

  @override
  void dispose() {
    unawaited(_persistSession(status: 'interrupted'));
    ref.read(activitySessionProvider.notifier).complete(ActivityType.exercise);
    _countdownTimer?.cancel();
    _cameraController.stopImageStream();
    _cameraController.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(exerciseControllerProvider);
    final state = asyncState.valueOrNull ??
        const ExerciseState(
          exerciseLabel: 'Squat',
          exerciseKind: ExerciseKind.squat,
          reps: 0,
          leftReps: 0,
          rightReps: 0,
          sets: 0,
          isRunning: false,
          currentAngle: 0,
          stage: 'UP',
          postureScore: 100,
          feedback: 'Keep your back straight',
          formQuality: 'GOOD',
          orientationWarning: '',
          plankHoldSeconds: 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Mode'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : !_cameraReady
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    _buildCamera(),
                    _buildOverlay(state),
                    if (_countdownSeconds > 0) _buildCountdown(),
                  ],
                ),
    );
  }

  Widget _buildCamera() {
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: 1 / _cameraController.value.aspectRatio,
          child: CameraPreview(_cameraController),
        ),
        if (_poseBounds != null)
          CustomPaint(
            painter: _PoseBoxPainter(_poseBounds!),
          ),
      ],
    );
  }

  Widget _buildOverlay(ExerciseState state) {
    final activitySession = ref.watch(activitySessionProvider);
    final bool showCompleteButton =
        activitySession.activeActivity == ActivityType.exercise;

    return Align(
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
              value: _selectedExerciseMode,
              dropdownColor: Colors.grey.shade900,
              hint: const Text('Select exercise mode', style: TextStyle(color: Colors.white70)),
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
                ...ExerciseConfig.all.map(
                  (config) => DropdownMenuItem<String>(
                    value: config.label,
                    child: Text(config.label),
                  ),
                ),
              ],
              onChanged: state.isRunning
                  ? null
                  : (value) {
                      setState(() {
                        _selectedExerciseMode = value;
                      });
                      unawaited(_switchCameraForSelection(value));
                    },
            ),
            const SizedBox(height: 10),
            Text(
              state.exerciseLabel,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reps: ${state.reps}',
                    style: const TextStyle(fontSize: 18)),
                Text('${state.stage}',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.yellowAccent)),
              ],
            ),
            const SizedBox(height: 12),
            Text(state.feedback, maxLines: 2),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    state.isRunning ? _handlePausePressed : _handleStartPressed,
                icon: Icon(state.isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(state.isRunning ? 'PAUSE' : 'START'),
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
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
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
