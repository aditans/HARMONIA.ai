import 'dart:math' as math;

import 'package:harmonia_ai/features/yoga/data/yoga_config.dart';
import 'package:harmonia_ai/features/yoga/services/yoga_math.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/services/ml/angle_calculator.dart';
import 'package:harmonia_ai/shared/services/ml/landmark_indices.dart';

class YogaAnalysisResult {
  const YogaAnalysisResult({
    required this.pose,
    required this.accuracy,
    required this.stability,
    required this.symmetry,
    required this.total,
    required this.feedback,
  });

  final String pose;
  final double accuracy;
  final double stability;
  final double symmetry;
  final double total;
  final String feedback;
}

class YogaAnalyzer {
  final List<double> _midHipHistory = [];

  List<double> normalizeLandmarks(List<PoseLandmarkData> landmarks) {
    final points = AngleCalculator.derivedPoints(landmarks);
    final midHip = points.midHip;
    final midShoulder = points.midShoulder;
    if (midHip == null || midShoulder == null) {
      return List<double>.filled(99, 0);
    }

    final double torsoDx = midShoulder.x - midHip.x;
    final double torsoDy = midShoulder.y - midHip.y;
    final double torsoDz = midShoulder.z - midHip.z;
    final double torsoNorm =
        math.sqrt(torsoDx * torsoDx + torsoDy * torsoDy + torsoDz * torsoDz);
    final double scale = torsoNorm == 0 ? 1 : torsoNorm;

    final List<double> output = [];
    for (int i = 0; i < 33; i++) {
      final lm = AngleCalculator.byIndex(landmarks, i);
      if (lm == null) {
        output.addAll([0, 0, 0]);
        continue;
      }
      output.add((lm.x - midHip.x) / scale);
      output.add((lm.y - midHip.y) / scale);
      output.add((lm.z - midHip.z) / scale);
    }
    return output;
  }

  YogaAnalysisResult analyze({
    required YogaPoseConfig config,
    required List<PoseLandmarkData> landmarks,
    required List<double> modelProbabilities,
  }) {
    final normalized = normalizeLandmarks(landmarks);
    
    // Only use cosine similarity if reference vector is provided
    double cosineAccuracy = 0;
    if (config.referenceVector.isNotEmpty) {
      final cosine = YogaMath.cosineSimilarity(normalized, config.referenceVector);
      cosineAccuracy = (cosine * 100).clamp(0, 100);
    }

    final points = AngleCalculator.derivedPoints(landmarks);
    if (points.midHip != null) {
      _midHipHistory.add(points.midHip!.x);
      if (_midHipHistory.length > 30) {
        _midHipHistory.removeAt(0);
      }
    }
    final stability = (100 - (_stddev(_midHipHistory) * 1000)).clamp(0, 100);

    final leftAngle = _leftSymmetryAngle(landmarks);
    final rightAngle = _rightSymmetryAngle(landmarks);
    final symmetry = (100 - (leftAngle - rightAngle).abs()).clamp(0, 100);

    final angleScores = config.angleTargets.map((target) {
      final measured = _resolveAngle(target.key, landmarks);
      return math.max(0, 100 - ((measured - target.ideal).abs() * 2));
    }).toList();
    final avgAngleScore = angleScores.isEmpty
        ? 0
        : angleScores.reduce((a, b) => a + b) / angleScores.length;

    final total =
        (avgAngleScore * 0.60) + (stability * 0.25) + (symmetry * 0.15);
    final feedback = _feedback(total, config.feedbackHints);

    // Use angle-based accuracy if no reference vector; otherwise use cosine similarity
    final accuracy = config.referenceVector.isNotEmpty 
        ? cosineAccuracy 
        : avgAngleScore;

    return YogaAnalysisResult(
      pose: config.label,
      accuracy: accuracy.toDouble(),
      stability: stability.toDouble(),
      symmetry: symmetry.toDouble(),
      total: total.toDouble(),
      feedback: feedback,
    );
  }

  double _resolveAngle(String key, List<PoseLandmarkData> landmarks) {
    switch (key) {
      case 'spine':
        return AngleCalculator.spineAngleFromVertical(landmarks);
      case 'body_line':
        return _angle(landmarks, LandmarkIndices.rightShoulder,
            LandmarkIndices.rightHip, LandmarkIndices.rightAnkle);
      case 'knee':
      case 'standing_knee':
        return _angle(landmarks, LandmarkIndices.rightHip,
            LandmarkIndices.rightKnee, LandmarkIndices.rightAnkle);
      case 'bent_knee':
      case 'front_knee':
        return _angle(landmarks, LandmarkIndices.leftHip,
            LandmarkIndices.leftKnee, LandmarkIndices.leftAnkle);
      case 'back_leg':
        return _angle(landmarks, LandmarkIndices.rightHip,
            LandmarkIndices.rightKnee, LandmarkIndices.rightAnkle);
      case 'arm_raise':
      case 'top_arm':
        return _angle(landmarks, LandmarkIndices.leftHip,
            LandmarkIndices.leftShoulder, LandmarkIndices.leftWrist);
      case 'arms':
        return _angle(landmarks, LandmarkIndices.rightHip,
            LandmarkIndices.rightShoulder, LandmarkIndices.rightElbow);
      case 'hip_angle':
      case 'hip_fold':
      case 'hip_line':
        return _angle(landmarks, LandmarkIndices.leftShoulder,
            LandmarkIndices.leftHip, LandmarkIndices.leftKnee);
      case 'elbow':
        return _angle(landmarks, LandmarkIndices.leftShoulder,
            LandmarkIndices.leftElbow, LandmarkIndices.leftWrist);
      case 'backbend':
        return 180 - AngleCalculator.spineAngleFromVertical(landmarks);
      case 'torso_horizontal':
        final shoulder =
            AngleCalculator.byIndex(landmarks, LandmarkIndices.leftShoulder);
        final hip = AngleCalculator.byIndex(landmarks, LandmarkIndices.leftHip);
        if (shoulder == null || hip == null) {
          return 0;
        }
        return (math.atan2(
                    (shoulder.y - hip.y).abs(), (shoulder.x - hip.x).abs()) *
                180 /
                math.pi)
            .abs();
      default:
        return 0;
    }
  }

  double _angle(List<PoseLandmarkData> lms, int a, int b, int c) {
    final pa = AngleCalculator.byIndex(lms, a);
    final pb = AngleCalculator.byIndex(lms, b);
    final pc = AngleCalculator.byIndex(lms, c);
    if (pa == null || pb == null || pc == null) {
      return 0;
    }
    return AngleCalculator.calculateAngle(pa, pb, pc);
  }

  double _leftSymmetryAngle(List<PoseLandmarkData> landmarks) {
    return _angle(landmarks, LandmarkIndices.leftShoulder,
        LandmarkIndices.leftElbow, LandmarkIndices.leftWrist);
  }

  double _rightSymmetryAngle(List<PoseLandmarkData> landmarks) {
    return _angle(landmarks, LandmarkIndices.rightShoulder,
        LandmarkIndices.rightElbow, LandmarkIndices.rightWrist);
  }

  double _stddev(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    return math.sqrt(variance);
  }

  String _feedback(double total, List<String> hints) {
    if (total < 50) {
      return 'Keep trying';
    }
    if (total < 70) {
      return 'Getting there';
    }
    if (total < 85) {
      return 'Good form';
    }
    if (total < 95) {
      return 'Excellent!';
    }
    return hints.isEmpty ? 'Perfect! 🏆' : hints.first;
  }
}
