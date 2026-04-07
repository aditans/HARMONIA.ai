import 'dart:math' as math;

import 'package:harmonia_ai/features/exercise/data/exercise_config.dart';
import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';
import 'package:harmonia_ai/shared/services/ml/angle_calculator.dart';
import 'package:harmonia_ai/shared/services/ml/landmark_indices.dart';
import 'package:harmonia_ai/shared/services/ml/smoothing_filter.dart';

class ExerciseAnalysisResult {
  const ExerciseAnalysisResult({
    required this.stage,
    required this.reps,
    required this.leftReps,
    required this.rightReps,
    required this.currentAngle,
    required this.feedback,
    required this.postureScore,
    required this.formQuality,
    required this.orientationWarning,
    required this.holdSeconds,
  });

  final String stage;
  final int reps;
  final int leftReps;
  final int rightReps;
  final double currentAngle;
  final String feedback;
  final int postureScore;
  final String formQuality;
  final String orientationWarning;
  final int holdSeconds;
}

class ExerciseAnalyzer {
  final Map<String, JointSmoothingPipeline> _jointSmoothing = {};

  String _stage = 'up';
  String _leftStage = 'down';
  String _rightStage = 'down';
  int _reps = 0;
  int _leftReps = 0;
  int _rightReps = 0;
  int _plankHoldSeconds = 0;

  void reset() {
    _jointSmoothing.clear();
    _stage = 'up';
    _leftStage = 'down';
    _rightStage = 'down';
    _reps = 0;
    _leftReps = 0;
    _rightReps = 0;
    _plankHoldSeconds = 0;
  }

  double _smooth(String key, double raw) {
    final pipeline = _jointSmoothing.putIfAbsent(
        key, () => JointSmoothingPipeline(alpha: 0.3, windowSize: 5));
    return pipeline.smooth(raw);
  }

  PoseLandmarkData? _lm(List<PoseLandmarkData> landmarks, int index) =>
      AngleCalculator.byIndex(landmarks, index);

  double _distance(PoseLandmarkData a, PoseLandmarkData b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  ExerciseAnalysisResult analyze({
    required ExerciseKind kind,
    required List<PoseLandmarkData> landmarks,
    required int elapsedSeconds,
  }) {
    final double spineAngle = AngleCalculator.spineAngleFromVertical(landmarks);
    final int postureScore =
        AngleCalculator.postureScoreFromSpineAngle(spineAngle);
    final String formQuality = postureScore >= 80
        ? 'GOOD'
        : postureScore >= 60
            ? 'WARNING'
            : 'BAD';

    final orientationOffset = AngleCalculator.orientationOffsetAngle(landmarks);
    final String orientationWarning =
        orientationOffset > 25 ? 'Please face sideways' : '';

    switch (kind) {
      case ExerciseKind.squat:
        return _analyzeSquat(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.pushUp:
        return _analyzePushUp(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.bicepCurl:
        return _analyzeBicepCurl(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.shoulderPress:
        return _analyzeShoulderPress(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.lunge:
        return _analyzeLunge(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.deadlift:
        return _analyzeDeadlift(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.lateralRaise:
        return _analyzeLateralRaise(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.pullUp:
        return _analyzePullUp(
            landmarks, postureScore, formQuality, orientationWarning);
      case ExerciseKind.plank:
        return _analyzePlank(landmarks, postureScore, formQuality,
            orientationWarning, elapsedSeconds);
      case ExerciseKind.jumpingJack:
        return _analyzeJumpingJack(
            landmarks, postureScore, formQuality, orientationWarning);
    }
  }

  ExerciseAnalysisResult _analyzeSquat(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final hip = _lm(landmarks, LandmarkIndices.leftHip);
    final knee = _lm(landmarks, LandmarkIndices.leftKnee);
    final ankle = _lm(landmarks, LandmarkIndices.leftAnkle);
    final shoulder = _lm(landmarks, LandmarkIndices.rightShoulder);
    final rightHip = _lm(landmarks, LandmarkIndices.rightHip);
    final rightKnee = _lm(landmarks, LandmarkIndices.rightKnee);
    final heel = _lm(landmarks, LandmarkIndices.leftHeel);
    if (hip == null ||
        knee == null ||
        ankle == null ||
        shoulder == null ||
        rightHip == null ||
        rightKnee == null ||
        heel == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }

    final kneeAngle =
        _smooth('squat_knee', AngleCalculator.calculateAngle(hip, knee, ankle));
    final hipAngle = _smooth('squat_hip',
        AngleCalculator.calculateAngle(shoulder, rightHip, rightKnee));
    final ankleAngle = _smooth(
        'squat_ankle', AngleCalculator.calculateAngle(knee, ankle, heel));
    final torsoAngle = AngleCalculator.spineAngleFromVertical(landmarks);

    if (kneeAngle > 155) {
      if (_stage == 'down') {
        _reps++;
      }
      _stage = 'up';
    } else if (kneeAngle < 115) {
      _stage = 'down';
    }

    String feedback = 'Great squat form';
    if (kneeAngle < 80) {
      feedback = "Don't go too deep";
    } else if (kneeAngle >= 100 && kneeAngle <= 140) {
      feedback = 'Squat deeper';
    } else if (torsoAngle > 45) {
      feedback = 'Chest up! Lean less forward';
    } else if (ankleAngle < 60) {
      feedback = "Don't let heels rise";
    } else if (hipAngle > 100 && kneeAngle < 100) {
      feedback = 'Go deeper';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: kneeAngle,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzePushUp(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final shoulder = _lm(landmarks, LandmarkIndices.rightShoulder);
    final elbow = _lm(landmarks, LandmarkIndices.rightElbow);
    final wrist = _lm(landmarks, LandmarkIndices.rightWrist);
    final hip = _lm(landmarks, LandmarkIndices.rightHip);
    final ankle = _lm(landmarks, LandmarkIndices.rightAnkle);
    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        hip == null ||
        ankle == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }

    final elbowAngle = _smooth(
        'push_elbow', AngleCalculator.calculateAngle(shoulder, elbow, wrist));
    final bodyLine = _smooth(
        'push_body_line', AngleCalculator.calculateAngle(shoulder, hip, ankle));

    if (elbowAngle > 155) {
      if (_stage == 'down') {
        _reps++;
      }
      _stage = 'up';
    } else if (elbowAngle < 110) {
      _stage = 'down';
    }

    String feedback = 'Strong push-up';
    if (bodyLine < 160) {
      feedback = 'Hips sagging! Engage your core';
    } else if (elbowAngle > 110 && _stage == 'down') {
      feedback = 'Go lower for full range';
    } else if ((wrist.x - shoulder.x).abs() > 0.05) {
      feedback = 'Move hands under shoulders';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: elbowAngle,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzeBicepCurl(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final ls = _lm(landmarks, LandmarkIndices.leftShoulder);
    final le = _lm(landmarks, LandmarkIndices.leftElbow);
    final lw = _lm(landmarks, LandmarkIndices.leftWrist);
    final rs = _lm(landmarks, LandmarkIndices.rightShoulder);
    final re = _lm(landmarks, LandmarkIndices.rightElbow);
    final rw = _lm(landmarks, LandmarkIndices.rightWrist);
    if (ls == null ||
        le == null ||
        lw == null ||
        rs == null ||
        re == null ||
        rw == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }

    final leftAngle =
        _smooth('curl_left', AngleCalculator.calculateAngle(ls, le, lw));
    final rightAngle =
        _smooth('curl_right', AngleCalculator.calculateAngle(rs, re, rw));

    final leftState = leftAngle > 160
        ? 'down'
        : leftAngle < 45
            ? 'up'
            : _leftStage;
    if (_leftStage == 'down' && leftState == 'up') {
      _leftReps++;
      _reps++;
    }
    _leftStage = leftState;

    final rightState = rightAngle > 160
        ? 'down'
        : rightAngle < 45
            ? 'up'
            : _rightStage;
    if (_rightStage == 'down' && rightState == 'up') {
      _rightReps++;
      _reps++;
    }
    _rightStage = rightState;

    String feedback = 'Controlled curl';
    if ((ls.y - rs.y).abs() > 0.05) {
      feedback = "Keep your elbow pinned - don't swing";
    } else if (leftAngle > 60 || rightAngle > 60) {
      feedback = 'Curl higher for full contraction';
    }

    return ExerciseAnalysisResult(
      stage: 'L:${_leftStage.toUpperCase()} R:${_rightStage.toUpperCase()}',
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: (leftAngle + rightAngle) / 2,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzeShoulderPress(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final ls = _lm(landmarks, LandmarkIndices.leftShoulder);
    final le = _lm(landmarks, LandmarkIndices.leftElbow);
    final lw = _lm(landmarks, LandmarkIndices.leftWrist);
    final rs = _lm(landmarks, LandmarkIndices.rightShoulder);
    final re = _lm(landmarks, LandmarkIndices.rightElbow);
    final rw = _lm(landmarks, LandmarkIndices.rightWrist);
    if (ls == null ||
        le == null ||
        lw == null ||
        rs == null ||
        re == null ||
        rw == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }
    final leftElbow =
        _smooth('press_left', AngleCalculator.calculateAngle(ls, le, lw));
    final rightElbow =
        _smooth('press_right', AngleCalculator.calculateAngle(rs, re, rw));

    final bool down =
      leftElbow < 110 && rightElbow < 110 && lw.y > ls.y && rw.y > rs.y;
    final bool up = leftElbow > 155 && rightElbow > 155;
    if (up && _stage == 'down') {
      _reps++;
    }
    if (down) {
      _stage = 'down';
    } else if (up) {
      _stage = 'up';
    }

    String feedback = 'Press straight overhead';
    if (AngleCalculator.spineAngleFromVertical(landmarks) > 10) {
      feedback = "Don't arch - brace core";
    } else if ((lw.x - ls.x).abs() > 0.08 || (rw.x - rs.x).abs() > 0.08) {
      feedback = 'Bar path should be vertical';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: (leftElbow + rightElbow) / 2,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzeLunge(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final fh = _lm(landmarks, LandmarkIndices.leftHip);
    final fk = _lm(landmarks, LandmarkIndices.leftKnee);
    final fa = _lm(landmarks, LandmarkIndices.leftAnkle);
    final bh = _lm(landmarks, LandmarkIndices.rightHip);
    final bk = _lm(landmarks, LandmarkIndices.rightKnee);
    final ba = _lm(landmarks, LandmarkIndices.rightAnkle);
    if (fh == null ||
        fk == null ||
        fa == null ||
        bh == null ||
        bk == null ||
        ba == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }
    final frontKnee =
        _smooth('lunge_front', AngleCalculator.calculateAngle(fh, fk, fa));
    final backKnee =
        _smooth('lunge_back', AngleCalculator.calculateAngle(bh, bk, ba));

    final bool down = frontKnee < 115 && backKnee < 125;
    final bool up = frontKnee > 155;
    if (up && _stage == 'down') {
      _reps++;
    }
    if (down) {
      _stage = 'down';
    } else if (up) {
      _stage = 'up';
    }

    String feedback = 'Great lunge';
    if (fk.x > fa.x + 0.05) {
      feedback = 'Keep front knee over ankle';
    } else if (AngleCalculator.spineAngleFromVertical(landmarks) > 15) {
      feedback = 'Keep torso upright';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: frontKnee,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzeDeadlift(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final shoulder = _lm(landmarks, LandmarkIndices.rightShoulder);
    final hip = _lm(landmarks, LandmarkIndices.rightHip);
    final knee = _lm(landmarks, LandmarkIndices.rightKnee);
    final ankle = _lm(landmarks, LandmarkIndices.rightAnkle);
    final wrist = _lm(landmarks, LandmarkIndices.rightWrist);
    if (shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        wrist == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }
    final hipHinge = _smooth(
        'deadlift_hip', AngleCalculator.calculateAngle(shoulder, hip, knee));
    final kneeAngle = _smooth(
        'deadlift_knee', AngleCalculator.calculateAngle(hip, knee, ankle));
    final backAngle = AngleCalculator.spineAngleFromVertical(landmarks);

    final bool hinge = hipHinge < 125;
    final bool lockout = hipHinge > 160 && kneeAngle > 150;
    if (lockout && _stage == 'down') {
      _reps++;
    }
    if (hinge) {
      _stage = 'down';
    } else if (lockout) {
      _stage = 'up';
    }

    String feedback = 'Hinge with control';
    if (backAngle > 20) {
      feedback = 'Keep your back flat - hinge at hips';
    } else if (kneeAngle < 150 && lockout) {
      feedback = 'Fully extend knees at top';
    } else if ((wrist.x - ankle.x).abs() > 0.03) {
      feedback = 'Keep bar path over mid-foot';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: hipHinge,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzeLateralRaise(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final ls = _lm(landmarks, LandmarkIndices.leftShoulder);
    final lw = _lm(landmarks, LandmarkIndices.leftWrist);
    final le = _lm(landmarks, LandmarkIndices.leftElbow);
    final rs = _lm(landmarks, LandmarkIndices.rightShoulder);
    final rw = _lm(landmarks, LandmarkIndices.rightWrist);
    final re = _lm(landmarks, LandmarkIndices.rightElbow);
    final lh = _lm(landmarks, LandmarkIndices.leftHip);
    final rh = _lm(landmarks, LandmarkIndices.rightHip);
    if (ls == null ||
        lw == null ||
        le == null ||
        rs == null ||
        rw == null ||
        re == null ||
        lh == null ||
        rh == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }

    // Measure wrist elevation relative to shoulder (y-axis difference)
    final leftElevation = _smooth('raise_left_elev', (ls.y - lw.y) * 100);
    final rightElevation = _smooth('raise_right_elev', (rs.y - rw.y) * 100);
    final avgElevation = (leftElevation + rightElevation) / 2;

    // Lateral raise: arms down (~0-5), arms up (~15-25)
    if (avgElevation < 8) {
      if (_stage == 'top') {
        _reps++;
      }
      _stage = 'down';
    } else if (avgElevation > 12 && _stage == 'down') {
      _stage = 'top';
    }

    String feedback = 'Smooth lateral raises';
    if (avgElevation > 20) {
      feedback = 'Lower to shoulder height';
    } else if (le.y > lw.y || re.y > rw.y) {
      feedback = 'Lead with elbows, not wrists';
    } else if ((lh.x - rh.x).abs() > 0.03) {
      feedback = 'Control the movement - no swinging';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: avgElevation,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzePullUp(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final shoulder = _lm(landmarks, LandmarkIndices.leftShoulder);
    final elbow = _lm(landmarks, LandmarkIndices.leftElbow);
    final wrist = _lm(landmarks, LandmarkIndices.leftWrist);
    final nose = _lm(landmarks, LandmarkIndices.nose);
    final leftHip = _lm(landmarks, LandmarkIndices.leftHip);
    final rightHip = _lm(landmarks, LandmarkIndices.rightHip);
    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        nose == null ||
        leftHip == null ||
        rightHip == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }
    final elbowAngle = _smooth(
        'pullup_elbow', AngleCalculator.calculateAngle(shoulder, elbow, wrist));

    final bool deadHang = elbowAngle > 160;
    final bool top = elbowAngle < 60 && nose.y < wrist.y;
    if (top && _stage == 'down') {
      _reps++;
    }
    if (deadHang) {
      _stage = 'down';
    } else if (top) {
      _stage = 'up';
    }

    String feedback = 'Strong pull';
    if (!top && elbowAngle < 60) {
      feedback = 'Pull higher - chin over bar';
    } else if ((leftHip.x - rightHip.x).abs() > 0.08) {
      feedback = 'Avoid swinging';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: elbowAngle,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzePlank(
      List<PoseLandmarkData> landmarks,
      int postureScore,
      String quality,
      String orientationWarning,
      int elapsedSeconds) {
    final shoulder = _lm(landmarks, LandmarkIndices.rightShoulder);
    final hip = _lm(landmarks, LandmarkIndices.rightHip);
    final ankle = _lm(landmarks, LandmarkIndices.rightAnkle);
    if (shoulder == null || hip == null || ankle == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }
    final bodyLine = _smooth(
        'plank_line', AngleCalculator.calculateAngle(shoulder, hip, ankle));

    String feedback = 'Hold steady';
    if (bodyLine >= 165 && bodyLine <= 180) {
      _plankHoldSeconds = elapsedSeconds;
    } else if (hip.y > (shoulder.y + ankle.y) / 2 + 0.03) {
      feedback = 'Hips sagging!';
    } else if (hip.y < (shoulder.y + ankle.y) / 2 - 0.03) {
      feedback = 'Lower your hips';
    }

    return ExerciseAnalysisResult(
      stage: 'HOLD',
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: bodyLine,
      feedback: feedback,
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _analyzeJumpingJack(List<PoseLandmarkData> landmarks,
      int postureScore, String quality, String orientationWarning) {
    final lw = _lm(landmarks, LandmarkIndices.leftWrist);
    final rw = _lm(landmarks, LandmarkIndices.rightWrist);
    final la = _lm(landmarks, LandmarkIndices.leftAnkle);
    final ra = _lm(landmarks, LandmarkIndices.rightAnkle);
    final ls = _lm(landmarks, LandmarkIndices.leftShoulder);
    final rs = _lm(landmarks, LandmarkIndices.rightShoulder);
    final lh = _lm(landmarks, LandmarkIndices.leftHip);
    final rh = _lm(landmarks, LandmarkIndices.rightHip);
    if (lw == null ||
        rw == null ||
        la == null ||
        ra == null ||
        ls == null ||
        rs == null ||
        lh == null ||
        rh == null) {
      return _fallback(postureScore, quality, orientationWarning);
    }

    final shoulderWidth = _distance(ls, rs);
    final hipWidth = _distance(lh, rh);
    final armSpread =
        _distance(lw, rw) / (shoulderWidth == 0 ? 1 : shoulderWidth);
    final legSpread = _distance(la, ra) / (hipWidth == 0 ? 1 : hipWidth);

    // More lenient thresholds for fast-paced jumping jacks
    final bool closed = armSpread < 1.3 && legSpread < 1.3;
    final bool closingTrans = armSpread < 1.5 && legSpread < 1.5;
    final bool open = armSpread > 1.7 && legSpread > 1.5;

    if (closed || closingTrans) {
      if (_stage == 'open') {
        _reps++;
      }
      _stage = 'closed';
    } else if (open) {
      _stage = 'open';
    }

    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: armSpread,
      feedback: 'Stay rhythmic and controlled',
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }

  ExerciseAnalysisResult _fallback(
      int postureScore, String quality, String orientationWarning) {
    return ExerciseAnalysisResult(
      stage: _stage.toUpperCase(),
      reps: _reps,
      leftReps: _leftReps,
      rightReps: _rightReps,
      currentAngle: 0,
      feedback: 'Move into full camera view',
      postureScore: postureScore,
      formQuality: quality,
      orientationWarning: orientationWarning,
      holdSeconds: _plankHoldSeconds,
    );
  }
}
