import 'dart:math' as math;

class PoseMath {
  /// Returns the angle ABC in degrees using the dot product between BA and BC.
  static double angleBetween3Points(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    final double baX = ax - bx;
    final double baY = ay - by;
    final double bcX = cx - bx;
    final double bcY = cy - by;

    final double dot = baX * bcX + baY * bcY;
    final double magnitudeBA = math.sqrt(baX * baX + baY * baY);
    final double magnitudeBC = math.sqrt(bcX * bcX + bcY * bcY);
    final double cosine = (dot / (magnitudeBA * magnitudeBC)).clamp(-1.0, 1.0);

    return math.acos(cosine) * 180 / math.pi;
  }

  /// A simple posture proxy: compare the torso vector against the vertical axis.
  static double spineDeviationFromVertical({required double shoulderX, required double hipX}) {
    final double deltaX = shoulderX - hipX;
    return deltaX.abs();
  }
}
