import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/yoga/providers/yoga_controller.dart';
import 'package:harmonia_ai/shared/services/camera/camera_service_provider.dart';
import 'package:harmonia_ai/shared/widgets/shared_camera_view.dart';
import 'package:harmonia_ai/shared/services/ml/mlkit_pose_service.dart';

class YogaScreen extends ConsumerStatefulWidget {
  const YogaScreen({super.key});

  @override
  ConsumerState<YogaScreen> createState() => _YogaScreenState();
}

class _YogaScreenState extends ConsumerState<YogaScreen> {
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
      cameraService.setYogaCallback(_onCameraImage);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _poseService.dispose();
    // Unregister callback
    try {
      ref.read(sharedCameraServiceProvider).setYogaCallback(null);
    } catch (e) {
      debugPrint('Error unregistering yoga callback: $e');
    }
    super.dispose();
  }

  Future<void> _toggleStartPause(YogaState state) async {
    if (state.isRunning) {
      _countdownTimer?.cancel();
      setState(() {
        _countdown = 0;
      });
      debugPrint('Yoga paused by user');
      await ref.read(yogaControllerProvider.notifier).pauseSession();
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
    debugPrint('Yoga countdown started');

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
        debugPrint('Yoga session started');
        ref.read(yogaControllerProvider.notifier).startSession();
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
    final YogaState? state = ref.read(yogaControllerProvider).valueOrNull;
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
        await ref.read(yogaControllerProvider.notifier).analyzeLandmarks(landmarks);
      }
    } catch (e) {
      debugPrint('Yoga frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(sharedCameraServiceProvider);
    final asyncState = ref.watch(yogaControllerProvider);
    final YogaState state = asyncState.valueOrNull ??
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

    final bool showNoPoseWarning = state.isRunning &&
        (_lastPoseAt == null ||
            DateTime.now().difference(_lastPoseAt!).inSeconds >= 2);

    return Scaffold(
      body: Stack(
        children: [
          SharedCameraView(
            cameraService: cameraService,
            onCameraReady: () {
              debugPrint('Yoga camera ready');
            },
            overlay: _YogaOverlay(
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
                title: const Text('Yoga Mode'),
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

class _YogaOverlay extends StatelessWidget {
  const _YogaOverlay({
    required this.state,
    required this.countdown,
    required this.hasPose,
    required this.showNoPoseWarning,
    required this.onStartPausePressed,
  });

  final YogaState state;
  final int countdown;
  final bool hasPose;
  final bool showNoPoseWarning;
  final VoidCallback onStartPausePressed;

  String _formatHold(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.poseName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accuracy ${state.accuracy.toStringAsFixed(0)}% | Stability ${state.stability.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Symmetry ${state.symmetry.toStringAsFixed(0)}% | Total ${state.totalAccuracy.toStringAsFixed(0)}% | Hold ${_formatHold(state.holdSeconds)}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.feedback,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
