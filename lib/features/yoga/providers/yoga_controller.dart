import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/yoga/data/yoga_config.dart';
import 'package:harmonia_ai/features/yoga/services/tflite_service.dart';
import 'package:harmonia_ai/features/yoga/services/yoga_analyzer.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';

class YogaState {
  const YogaState({
    required this.poseName,
    required this.accuracy,
    required this.stability,
    required this.symmetry,
    required this.totalAccuracy,
    required this.holdSeconds,
    required this.isRunning,
    required this.feedback,
  });

  final String poseName;
  final double accuracy;
  final double stability;
  final double symmetry;
  final double totalAccuracy;
  final int holdSeconds;
  final bool isRunning;
  final String feedback;

  YogaState copyWith({
    String? poseName,
    double? accuracy,
    double? stability,
    double? symmetry,
    double? totalAccuracy,
    int? holdSeconds,
    bool? isRunning,
    String? feedback,
  }) {
    return YogaState(
      poseName: poseName ?? this.poseName,
      accuracy: accuracy ?? this.accuracy,
      stability: stability ?? this.stability,
      symmetry: symmetry ?? this.symmetry,
      totalAccuracy: totalAccuracy ?? this.totalAccuracy,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      isRunning: isRunning ?? this.isRunning,
      feedback: feedback ?? this.feedback,
    );
  }
}

class YogaController extends AsyncNotifier<YogaState> {
  final YogaAnalyzer _analyzer = YogaAnalyzer();
  final TfliteService _tfliteService = TfliteService();
  YogaPoseConfig _selected = YogaPoseConfig.all.first;
  String? _lastPredictedLabel;
  int _stableFrames = 0;
  bool _autoDetectEnabled = true;

  @override
  Future<YogaState> build() async {
    ref.onDispose(() {
      _tfliteService.dispose();
    });

    return const YogaState(
      poseName: 'Select Pose',
      accuracy: 0,
      stability: 0,
      symmetry: 0,
      totalAccuracy: 0,
      holdSeconds: 0,
      isRunning: false,
      feedback: 'Find your center',
    );
  }

  Future<void> selectPose(String poseName) async {
    final current = await future;
    final matched = YogaPoseConfig.all.where((pose) => pose.label == poseName);
    if (matched.isNotEmpty) {
      _selected = matched.first;
    }
    state = AsyncData(current.copyWith(poseName: _selected.label));
  }

  Future<void> startSession({bool autoDetect = true}) async {
    _lastPredictedLabel = null;
    _stableFrames = 0;
    _autoDetectEnabled = autoDetect;
    state = AsyncData((await future).copyWith(isRunning: true));
  }

  Future<void> pauseSession() async {
    state = AsyncData((await future).copyWith(isRunning: false));
  }

  Future<void> completeSession() async {
    _selected = YogaPoseConfig.all.first;
    _lastPredictedLabel = null;
    _stableFrames = 0;
    _autoDetectEnabled = true;
    state = AsyncData(
      (await future).copyWith(
        isRunning: false,
        poseName: 'Select Pose',
        accuracy: 0,
        stability: 0,
        symmetry: 0,
        totalAccuracy: 0,
        holdSeconds: 0,
        feedback: 'Find your center',
      ),
    );
  }

  Future<void> analyzeLandmarks(List<PoseLandmarkData> landmarks) async {
    final YogaState current = await future;
    if (!current.isRunning) {
      return;
    }

    final normalized = _analyzer.normalizeLandmarks(landmarks);
    final probabilities = await _tfliteService.infer(normalized);
    final modelError = _tfliteService.loadError;
    if (modelError != null) {
      state = AsyncData(current.copyWith(feedback: modelError));
      return;
    }

    final prediction = _tfliteService.topPrediction(probabilities);
    final predictedLabel = prediction.$1;
    final confidence = prediction.$2;

    YogaPoseConfig predictedConfig = _selected;
    final candidate = _resolveConfig(predictedLabel);
    if (_autoDetectEnabled && candidate != null && confidence >= 0.60) {
      if (_lastPredictedLabel == predictedLabel) {
        _stableFrames += 1;
      } else {
        _lastPredictedLabel = predictedLabel;
        _stableFrames = 1;
      }
      if (_stableFrames >= 4) {
        predictedConfig = candidate;
      }
    }

    final result = _analyzer.analyze(
        config: predictedConfig,
        landmarks: landmarks,
        modelProbabilities: probabilities);

    final hold = result.total > 65 ? current.holdSeconds + 1 : 0;

    state = AsyncData(
      current.copyWith(
        poseName: result.pose,
        accuracy: result.accuracy,
        stability: result.stability,
        symmetry: result.symmetry,
        totalAccuracy: result.total,
        holdSeconds: hold,
        feedback: result.feedback,
      ),
    );
  }

  YogaPoseConfig? _resolveConfig(String raw) {
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    final aliases = <String, String>{
      'warrior2': 'warrior ii',
      'warrior 2': 'warrior ii',
      'down dog': 'downward dog',
      'downdog': 'downward dog',
      'goddess': 'chair',
    };

    final target = aliases[normalized] ?? normalized;
    for (final pose in YogaPoseConfig.all) {
      final poseKey = pose.label
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (poseKey == target) {
        return pose;
      }
    }
    return null;
  }
}

final yogaControllerProvider =
    AsyncNotifierProvider<YogaController, YogaState>(YogaController.new);
