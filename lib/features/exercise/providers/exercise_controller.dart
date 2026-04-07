import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/exercise/data/exercise_config.dart';
import 'package:harmonia_ai/features/exercise/services/exercise_analyzer.dart';
import 'package:harmonia_ai/features/exercise/services/exercise_tflite_service.dart';
import 'package:harmonia_ai/features/exercise/services/posture_tflite_service.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';

class ExerciseState {
  const ExerciseState({
    required this.exerciseLabel,
    required this.exerciseKind,
    required this.reps,
    required this.leftReps,
    required this.rightReps,
    required this.sets,
    required this.isRunning,
    required this.currentAngle,
    required this.stage,
    required this.postureScore,
    required this.feedback,
    required this.formQuality,
    required this.orientationWarning,
    required this.plankHoldSeconds,
  });

  final String exerciseLabel;
  final ExerciseKind exerciseKind;
  final int reps;
  final int leftReps;
  final int rightReps;
  final int sets;
  final bool isRunning;
  final double currentAngle;
  final String stage;
  final int postureScore;
  final String feedback;
  final String formQuality;
  final String orientationWarning;
  final int plankHoldSeconds;

  ExerciseState copyWith({
    String? exerciseLabel,
    ExerciseKind? exerciseKind,
    int? reps,
    int? leftReps,
    int? rightReps,
    int? sets,
    bool? isRunning,
    double? currentAngle,
    String? stage,
    int? postureScore,
    String? feedback,
    String? formQuality,
    String? orientationWarning,
    int? plankHoldSeconds,
  }) {
    return ExerciseState(
      exerciseLabel: exerciseLabel ?? this.exerciseLabel,
      exerciseKind: exerciseKind ?? this.exerciseKind,
      reps: reps ?? this.reps,
      leftReps: leftReps ?? this.leftReps,
      rightReps: rightReps ?? this.rightReps,
      sets: sets ?? this.sets,
      isRunning: isRunning ?? this.isRunning,
      currentAngle: currentAngle ?? this.currentAngle,
      stage: stage ?? this.stage,
      postureScore: postureScore ?? this.postureScore,
      feedback: feedback ?? this.feedback,
      formQuality: formQuality ?? this.formQuality,
      orientationWarning: orientationWarning ?? this.orientationWarning,
      plankHoldSeconds: plankHoldSeconds ?? this.plankHoldSeconds,
    );
  }
}

class ExerciseController extends AsyncNotifier<ExerciseState> {
  final ExerciseAnalyzer _analyzer = ExerciseAnalyzer();
  final ExerciseTfliteService _exerciseTflite = ExerciseTfliteService();
  final PostureTfliteService _postureTflite = PostureTfliteService();
  int _elapsedSeconds = 0;
  bool _exerciseKindLocked = false;
  ExerciseKind? _lastPredictedKind;
  int _stablePredictionFrames = 0;
  bool _autoDetectEnabled = true;

  @override
  Future<ExerciseState> build() async {
    ref.onDispose(() {
      _exerciseTflite.dispose();
      _postureTflite.dispose();
    });

    return const ExerciseState(
      exerciseLabel: 'Select Exercise',
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
  }

  Future<void> selectExercise(ExerciseConfig config) async {
    final current = await future;
    _analyzer.reset();
    _elapsedSeconds = 0;
    _exerciseKindLocked = true;
    state = AsyncData(
      current.copyWith(
        exerciseKind: config.kind,
        exerciseLabel: config.label,
        reps: 0,
        leftReps: 0,
        rightReps: 0,
        stage: 'UP',
        currentAngle: 0,
      ),
    );
  }

  Future<void> startSession() async {
    await startSessionWithMode(autoDetect: true);
  }

  Future<void> startSessionWithMode({required bool autoDetect}) async {
    final current = await future;
    _analyzer.reset();
    _elapsedSeconds = 0;
    _autoDetectEnabled = autoDetect;
    _exerciseKindLocked = !autoDetect;
    _lastPredictedKind = null;
    _stablePredictionFrames = 0;
    state = AsyncData(
      current.copyWith(
        isRunning: true,
        reps: 0,
        leftReps: 0,
        rightReps: 0,
        stage: 'UP',
      ),
    );
  }

  Future<void> pauseSession() async {
    state = AsyncData((await future).copyWith(isRunning: false));
  }

  Future<void> completeSession() async {
    _analyzer.reset();
    _elapsedSeconds = 0;
    _autoDetectEnabled = true;
    _exerciseKindLocked = false;
    _lastPredictedKind = null;
    _stablePredictionFrames = 0;
    state = AsyncData(
      (await future).copyWith(
        isRunning: false,
        reps: 0,
        leftReps: 0,
        rightReps: 0,
        stage: 'UP',
        currentAngle: 0,
        exerciseLabel: 'Select Exercise',
        exerciseKind: ExerciseKind.squat,
      ),
    );
  }

  Future<void> endSession() async {
    _exerciseKindLocked = false;
    state = AsyncData((await future).copyWith(isRunning: false));
  }

  Future<void> analyzeLandmarks(List<PoseLandmarkData> landmarks) async {
    final ExerciseState current = await future;
    if (!current.isRunning) {
      return;
    }

    _elapsedSeconds += 1;
    final normalized = _normalizeLandmarks(landmarks);
    final prediction = await _exerciseTflite.predict(normalized);
    final predictedExercise = prediction.label;
    final posturePrediction = await _postureTflite.predictFromLandmarks(landmarks);

    ExerciseKind activeKind = current.exerciseKind;
    final ExerciseKind? predictedKind = _kindFromModelLabel(predictedExercise);
    final confident = prediction.confidence >= 0.55;
    if (_autoDetectEnabled && !_exerciseKindLocked && predictedKind != null && confident) {
      if (_lastPredictedKind == predictedKind) {
        _stablePredictionFrames += 1;
      } else {
        _lastPredictedKind = predictedKind;
        _stablePredictionFrames = 1;
      }
    }
    if (_autoDetectEnabled &&
      !_exerciseKindLocked &&
        predictedKind != null &&
        confident &&
        _stablePredictionFrames >= 5) {
      activeKind = predictedKind;
      _analyzer.reset();
      _elapsedSeconds = 0;
      _exerciseKindLocked = true;
    }

    final ExerciseAnalysisResult result = _analyzer.analyze(
      kind: activeKind,
      landmarks: landmarks,
      elapsedSeconds: _elapsedSeconds,
    );

    final mergedFeedback = '${result.feedback} ${posturePrediction.feedback}'.trim();

    state = AsyncData(
      current.copyWith(
        exerciseKind: activeKind,
        exerciseLabel: _labelFromKind(activeKind),
        stage: result.stage,
        reps: result.reps,
        leftReps: result.leftReps,
        rightReps: result.rightReps,
        currentAngle: result.currentAngle,
        postureScore: posturePrediction.score,
        feedback: mergedFeedback,
        formQuality: posturePrediction.label,
        orientationWarning: result.orientationWarning,
        plankHoldSeconds: result.holdSeconds,
      ),
    );
  }

  List<double> _normalizeLandmarks(List<PoseLandmarkData> landmarks) {
    final points = List<PoseLandmarkData?>.filled(33, null);
    for (final lm in landmarks) {
      if (lm.index >= 0 && lm.index < 33) {
        points[lm.index] = lm;
      }
    }

    final leftHip = points[23];
    final rightHip = points[24];
    final leftShoulder = points[11];
    final rightShoulder = points[12];
    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return List<double>.filled(99, 0);
    }

    final midHipX = (leftHip.x + rightHip.x) / 2;
    final midHipY = (leftHip.y + rightHip.y) / 2;
    final midHipZ = (leftHip.z + rightHip.z) / 2;
    final midShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
    final midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final midShoulderZ = (leftShoulder.z + rightShoulder.z) / 2;

    final torsoNorm = math.sqrt(
      math.pow(midShoulderX - midHipX, 2) +
          math.pow(midShoulderY - midHipY, 2) +
          math.pow(midShoulderZ - midHipZ, 2),
    );
    final scale = torsoNorm == 0 ? 1.0 : torsoNorm;

    final output = <double>[];
    for (int i = 0; i < 33; i++) {
      final lm = points[i];
      if (lm == null) {
        output.addAll([0, 0, 0]);
      } else {
        output.add((lm.x - midHipX) / scale);
        output.add((lm.y - midHipY) / scale);
        output.add((lm.z - midHipZ) / scale);
      }
    }
    return output;
  }

  ExerciseKind? _kindFromModelLabel(String? label) {
    if (label == null || label.trim().isEmpty) {
      return null;
    }
    final key = label.toLowerCase().replaceAll('-', ' ').trim();
    if (key.contains('squat')) return ExerciseKind.squat;
    if (key.contains('push up')) return ExerciseKind.pushUp;
    if (key.contains('curl')) return ExerciseKind.bicepCurl;
    if (key.contains('shoulder press')) return ExerciseKind.shoulderPress;
    if (key.contains('lunge')) return ExerciseKind.lunge;
    if (key.contains('deadlift')) return ExerciseKind.deadlift;
    if (key.contains('lateral raise')) return ExerciseKind.lateralRaise;
    if (key.contains('pull up') || key.contains('lat pulldown') || key.contains('t bar row')) {
      return ExerciseKind.pullUp;
    }
    if (key.contains('plank')) return ExerciseKind.plank;
    if (key.contains('jumping jack')) return ExerciseKind.jumpingJack;
    return null;
  }

  String _labelFromKind(ExerciseKind kind) {
    return ExerciseConfig.all
            .where((config) => config.kind == kind)
            .map((config) => config.label)
            .firstOrNull ??
        'Exercise';
  }
}

final exerciseControllerProvider =
    AsyncNotifierProvider<ExerciseController, ExerciseState>(
        ExerciseController.new);
