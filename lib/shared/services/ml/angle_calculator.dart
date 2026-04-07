import 'dart:math' as math;

import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/services/ml/landmark_indices.dart';

class AngleCalculator {
  static bool isVisible(PoseLandmarkData lm) => lm.likelihood > 0.5;

  static bool tripletVisible(
      PoseLandmarkData a, PoseLandmarkData b, PoseLandmarkData c) {
    return isVisible(a) && isVisible(b) && isVisible(c);
  }

  static double calculateAngle(
      PoseLandmarkData a, PoseLandmarkData b, PoseLandmarkData c) {
    final double radians =
        math.atan2(c.y - b.y, c.x - b.x) - math.atan2(a.y - b.y, a.x - b.x);
    double angle = (radians * 180 / math.pi).abs();
    if (angle > 180) {
      angle = 360 - angle;
    }
    return angle;
  }

  static PoseLandmarkData midpoint(PoseLandmarkData a, PoseLandmarkData b,
      {required int index}) {
    return PoseLandmarkData(
      index: index,
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      likelihood: math.min(a.likelihood, b.likelihood),
    );
  }

  static PoseLandmarkData? byIndex(
      List<PoseLandmarkData> landmarks, int index) {
    try {
      return landmarks.firstWhere((lm) => lm.index == index);
    } catch (_) {
      return null;
    }
  }

  static ({PoseLandmarkData? midHip, PoseLandmarkData? midShoulder})
      derivedPoints(List<PoseLandmarkData> landmarks) {
    final PoseLandmarkData? leftHip =
        byIndex(landmarks, LandmarkIndices.leftHip);
    final PoseLandmarkData? rightHip =
        byIndex(landmarks, LandmarkIndices.rightHip);
    final PoseLandmarkData? leftShoulder =
        byIndex(landmarks, LandmarkIndices.leftShoulder);
    final PoseLandmarkData? rightShoulder =
        byIndex(landmarks, LandmarkIndices.rightShoulder);

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return (midHip: null, midShoulder: null);
    }

    return (
      midHip: midpoint(leftHip, rightHip, index: 100),
      midShoulder: midpoint(leftShoulder, rightShoulder, index: 101),
    );
  }

  static double spineAngleFromVertical(List<PoseLandmarkData> landmarks) {
    final points = derivedPoints(landmarks);
    final PoseLandmarkData? midHip = points.midHip;
    final PoseLandmarkData? midShoulder = points.midShoulder;
    if (midHip == null || midShoulder == null) {
      return 0;
    }

    final double vx = midShoulder.x - midHip.x;
    final double vy = midShoulder.y - midHip.y;
    final double dot = vx * 0 + vy * -1;
    final double mag = math.sqrt(vx * vx + vy * vy);
    if (mag == 0) {
      return 0;
    }
    final double cosine = (dot / mag).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }

  static int postureScoreFromSpineAngle(double spineAngle) {
    if (spineAngle <= 10) {
      return 100;
    }
    if (spineAngle <= 20) {
      return 80;
    }
    if (spineAngle <= 30) {
      return 60;
    }
    return 40;
  }

  static double orientationOffsetAngle(List<PoseLandmarkData> landmarks) {
    final PoseLandmarkData? nose = byIndex(landmarks, LandmarkIndices.nose);
    final points = derivedPoints(landmarks);
    if (nose == null || points.midShoulder == null) {
      return 0;
    }
    final dx = nose.x - points.midShoulder!.x;
    final dy = nose.y - points.midShoulder!.y;
    return math.atan2(dy, dx).abs() * 180 / math.pi;
  }
}
