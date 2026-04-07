import 'package:flutter/foundation.dart';

import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/services/ml/angle_calculator.dart';

class PoseFrameRequest {
  const PoseFrameRequest(
      {required this.landmarks, required this.computeAngles});

  final List<PoseLandmarkData> landmarks;
  final List<({int a, int b, int c, String key})> computeAngles;
}

class PoseFrameResult {
  const PoseFrameResult({
    required this.angles,
    required this.spineAngle,
    required this.postureScore,
    required this.orientationOffset,
  });

  final Map<String, double> angles;
  final double spineAngle;
  final int postureScore;
  final double orientationOffset;
}

class PoseService {
  Future<PoseFrameResult> analyzeFrame(PoseFrameRequest request) async {
    return compute(_analyzeFrameIsolate, request);
  }

  static PoseFrameResult _analyzeFrameIsolate(PoseFrameRequest request) {
    final Map<String, double> angles = <String, double>{};
    for (final tuple in request.computeAngles) {
      final a = AngleCalculator.byIndex(request.landmarks, tuple.a);
      final b = AngleCalculator.byIndex(request.landmarks, tuple.b);
      final c = AngleCalculator.byIndex(request.landmarks, tuple.c);
      if (a == null ||
          b == null ||
          c == null ||
          !AngleCalculator.tripletVisible(a, b, c)) {
        continue;
      }
      angles[tuple.key] = AngleCalculator.calculateAngle(a, b, c);
    }

    final double spineAngle =
        AngleCalculator.spineAngleFromVertical(request.landmarks);
    final int postureScore =
        AngleCalculator.postureScoreFromSpineAngle(spineAngle);
    final double offset =
        AngleCalculator.orientationOffsetAngle(request.landmarks);
    return PoseFrameResult(
      angles: angles,
      spineAngle: spineAngle,
      postureScore: postureScore,
      orientationOffset: offset,
    );
  }
}
