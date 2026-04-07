import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/exercise/data/exercise_config.dart';
import 'package:harmonia_ai/features/exercise/providers/exercise_controller.dart';
import 'package:harmonia_ai/shared/services/camera/camera_service_provider.dart';
import 'package:harmonia_ai/shared/widgets/shared_camera_view.dart';
import 'package:harmonia_ai/shared/services/ml/mlkit_pose_service.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  final MlKitPoseService _poseService = MlKitPoseService();

  Timer? _countdownTimer;
  int _countdown = 0;
  bool _isProcessing = false;
  bool _hasPose = false;
  DateTime? _lastPoseAt;
  DateTime? _lastFrameAt;

  @override
  void initState() {
    super.initState();
    // Register this screen's callback with shared camera service
    Future.microtask(() {
      final cameraService = ref.read(sharedCameraServiceProvider);
      cameraService.setExerciseCallback(_onCameraImage);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _poseService.dispose();
    // Unregister callback
    try {
      ref.read(sharedCameraServiceProvider).setExerciseCallback(null);
    } catch (e) {
      debugPrint('Error unregistering exercise callback: $e');
    }
    super.dispose();
  }

  Future<void> _toggleStartPause(ExerciseState state) async {
    if (state.isRunning) {
      _countdownTimer?.cancel();
      setState(() {
        _countdown = 0;
      });
      debugPrint('Exercise paused by user');
      await ref.read(exerciseControllerProvider.notifier).pauseSession();
      return;
    }

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _hasPose = false;
    });
    debugPrint('Exercise countdown started');

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
        debugPrint('Exercise session started');
        ref.read(exerciseControllerProvider.notifier).startSession();
        return;
      }

      setState(() {
        _countdown -= 1;
      });
    });
  }

  Future<void> _onCameraImage(
    CameraImage image,
    CameraDescription description,
  ) async {
    final ExerciseState? state =
        ref.read(exerciseControllerProvider).valueOrNull;
    if (state == null || !state.isRunning || _isProcessing) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastFrameAt != null && now.difference(_lastFrameAt!).inMilliseconds < 250) {
      return;
    }
    _lastFrameAt = now;

    _isProcessing = true;
    try {
      final landmarks = await _poseService.detectLandmarks(image, description);
      if (landmarks.isNotEmpty) {
        _lastPoseAt = DateTime.now();
        if (mounted && !_hasPose) {
          setState(() {
            _hasPose = true;
          });
        }
        await ref
            .read(exerciseControllerProvider.notifier)
            .analyzeLandmarks(landmarks);
      }
    } catch (e) {
      debugPrint('Exercise frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(sharedCameraServiceProvider);
    final asyncState = ref.watch(exerciseControllerProvider);
    final ExerciseState state = asyncState.valueOrNull ??
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

    final bool showNoPoseWarning = state.isRunning &&
        (_lastPoseAt == null ||
            DateTime.now().difference(_lastPoseAt!).inSeconds >= 2);

    return Scaffold(
      body: Stack(
        children: [
          SharedCameraView(
            cameraService: cameraService,
            onCameraReady: () {
              debugPrint('Exercise camera ready');
            },
            overlay: _ExerciseOverlay(
              state: state,
              countdown: _countdown,
              hasPose: _hasPose,
              showNoPoseWarning: showNoPoseWarning,
              onStartPausePressed: () => _toggleStartPause(state),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AppBar(
                title: const Text('Exercise Mode'),
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

class _ExerciseOverlay extends StatelessWidget {
  const _ExerciseOverlay({
    required this.state,
    required this.countdown,
    required this.hasPose,
    required this.showNoPoseWarning,
    required this.onStartPausePressed,
  });

  final ExerciseState state;
  final int countdown;
  final bool hasPose;
  final bool showNoPoseWarning;
  final VoidCallback onStartPausePressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.exerciseLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Reps ${state.reps}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                state.stage,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Angle ${state.currentAngle.toStringAsFixed(0)}°  |  Posture ${state.postureScore}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.feedback,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (state.orientationWarning.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            state.orientationWarning,
                            style: const TextStyle(color: Colors.amberAccent),
                          ),
                        ],
                        if (showNoPoseWarning) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'No full body detected. Step back so your body fits in frame.',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ] else if (state.isRunning && hasPose) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Pose detected and analyzing live.',
                            style: TextStyle(color: Colors.greenAccent),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onStartPausePressed,
                            icon: Icon(
                                state.isRunning ? Icons.pause : Icons.play_arrow),
                            label: Text(state.isRunning ? 'Pause' : 'Start'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
