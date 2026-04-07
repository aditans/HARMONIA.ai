import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteService {
  Interpreter? _interpreter;
  String? _loadError;
  List<String> _labels = const [
    'downdog',
    'goddess',
    'plank',
    'tree',
    'warrior2',
  ];

  String? get loadError => _loadError;

  bool get isModelReady => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null || _loadError != null) {
      return;
    }

    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/yoga_classifier.tflite');
      _labels = await _loadLabels('assets/models/yoga_classifier_labels.txt');
    } catch (e) {
      _loadError = 'Unable to find the TensorFlow file. Please run again.';
    }
  }

  Future<List<double>> infer(List<double> input) async {
    if (_interpreter == null) {
      await loadModel();
    }
    final interpreter = _interpreter;
    if (interpreter == null) {
      return List<double>.filled(5, 0);
    }

    if (_loadError != null) {
      return List<double>.filled(5, 0);
    }

    final int outputClasses = interpreter.getOutputTensor(0).shape.last;
    final output = List<double>.filled(outputClasses, 0);
    interpreter
        .run(Float32List.fromList(input).reshape([1, input.length]), [output]);
    return output;
  }

  String topLabel(List<double> probabilities) {
    return topPrediction(probabilities).$1;
  }

  (String, double) topPrediction(List<double> probabilities) {
    if (probabilities.isEmpty) {
      return ('Unknown', 0);
    }

    int bestIndex = 0;
    double best = -double.infinity;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > best) {
        best = probabilities[i];
        bestIndex = i;
      }
    }

    if (bestIndex < _labels.length) {
      return (_labels[bestIndex], best);
    }
    return ('Unknown', best);
  }

  Future<List<String>> _loadLabels(String path) async {
    final raw = await rootBundle.loadString(path);
    return raw
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
