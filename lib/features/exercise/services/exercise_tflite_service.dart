import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ExerciseTfliteService {
  Interpreter? _interpreter;
  String? _loadError;
  List<String> _labels = const [];

  String? get loadError => _loadError;

  Future<({String? label, double confidence})> predict(
      List<double> normalizedLandmarks) async {
    if (_interpreter == null) {
      await loadModel();
    }

    final interpreter = _interpreter;
    if (interpreter == null || _loadError != null) {
      return (label: null, confidence: 0.0);
    }

    final int outputClasses = interpreter.getOutputTensor(0).shape.last;
    final output = List<double>.filled(outputClasses, 0);
    interpreter.run(
      Float32List.fromList(normalizedLandmarks)
          .reshape([1, normalizedLandmarks.length]),
      [output],
    );

    if (output.isEmpty) {
      return (label: null, confidence: 0.0);
    }

    final int topIndex = _argmax(output);
    final label = _labels.isNotEmpty && topIndex < _labels.length
        ? _labels[topIndex]
        : 'Exercise #${topIndex + 1}';
    return (label: label, confidence: output[topIndex]);
  }

  Future<void> loadModel() async {
    if (_interpreter != null || _loadError != null) {
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/exercise_classifier.tflite',
      );
      _labels = await _loadLabels(
        'assets/models/exercise_classifier_labels.txt',
      );
    } catch (_) {
      _loadError = 'Exercise classifier model is missing.';
    }
  }

  Future<String?> predictLabel(List<double> normalizedLandmarks) async {
    final prediction = await predict(normalizedLandmarks);
    return prediction.label;
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
    return math.max(index, 0);
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
