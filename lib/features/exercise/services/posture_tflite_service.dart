import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/services/ml/angle_calculator.dart';
import 'package:harmonia_ai/shared/services/ml/landmark_indices.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PosturePrediction {
  const PosturePrediction({
    required this.label,
    required this.score,
    required this.feedback,
  });

  final String label;
  final int score;
  final String feedback;
}

class PostureTfliteService {
  Interpreter? _interpreter;
  String? _loadError;
  List<String> _labels = const ['slouched', 'upright'];

  String? get loadError => _loadError;

  Future<void> loadModel() async {
    if (_interpreter != null || _loadError != null) {
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/posture_classifier.tflite',
      );
      _labels = await _loadLabels(
        'assets/models/posture_classifier_labels.txt',
      );
    } catch (_) {
      _loadError = 'Posture classifier model is missing.';
    }
  }

  Future<PosturePrediction> predictFromLandmarks(
    List<PoseLandmarkData> landmarks,
  ) async {
    if (_interpreter == null) {
      await loadModel();
    }

    final interpreter = _interpreter;
    if (interpreter == null || _loadError != null) {
      return const PosturePrediction(
        label: 'UNKNOWN',
        score: 0,
        feedback: 'Posture model not available.',
      );
    }

    final features = _buildFeatures(landmarks);
    final output = List<double>.filled(2, 0);
    interpreter.run(Float32List.fromList(features).reshape([1, 12]), [output]);

    final int topIndex = _argmax(output);
    final String label = topIndex < _labels.length
        ? _labels[topIndex]
        : (topIndex == 1 ? 'upright' : 'slouched');
    final bool upright = label.toLowerCase().contains('upright');

    return PosturePrediction(
      label: upright ? 'UPRIGHT' : 'SLOUCHED',
      score: upright ? 90 : 55,
      feedback: upright
          ? 'Posture looks good.'
          : 'Straighten your spine and open your chest.',
    );
  }

  List<double> _buildFeatures(List<PoseLandmarkData> landmarks) {
    PoseLandmarkData? lm(int index) => AngleCalculator.byIndex(landmarks, index);

    final leftShoulder = lm(LandmarkIndices.leftShoulder);
    final rightShoulder = lm(LandmarkIndices.rightShoulder);
    final leftHip = lm(LandmarkIndices.leftHip);
    final rightHip = lm(LandmarkIndices.rightHip);

    final points = [leftShoulder, rightShoulder, leftHip, rightHip];
    final output = <double>[];
    for (final p in points) {
      output.add(p?.x ?? 0);
      output.add(p?.y ?? 0);
      output.add(math.max(0, math.min(1, p?.likelihood ?? 0)));
    }
    return output;
  }

  int _argmax(List<double> values) {
    int index = 0;
    double best = -double.infinity;
    for (int i = 0; i < values.length; i++) {
      if (values[i] > best) {
        best = values[i];
        index = i;
      }
    }
    return index;
  }

  Future<List<String>> _loadLabels(String path) async {
    final raw = await rootBundle.loadString(path);
    return raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
