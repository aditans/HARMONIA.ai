class FocusMath {
  static double focusPercent(int focusedSeconds, int totalSeconds) {
    if (totalSeconds <= 0) return 0;
    return (focusedSeconds / totalSeconds) * 100;
  }

  /// Focus is considered true only when every gaze and head-position signal passes.
  static bool isFocused({
    required bool faceDetected,
    required double headPitchDegrees,
    required double headYawDegrees,
    required double leftEyeProbability,
    required double rightEyeProbability,
  }) {
    return faceDetected &&
        headPitchDegrees.abs() < 20 &&
        headYawDegrees.abs() < 25 &&
        leftEyeProbability > 0.7 &&
        rightEyeProbability > 0.7;
  }
}
