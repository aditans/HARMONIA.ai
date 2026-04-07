import 'dart:math' as math;

class YogaMath {
  /// Cosine similarity for 99-float landmark vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) {
      return 0;
    }

    double dot = 0;
    double magnitudeA = 0;
    double magnitudeB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    final double denominator = math.sqrt(magnitudeA) * math.sqrt(magnitudeB);
    if (denominator == 0) {
      return 0;
    }
    return (dot / denominator).clamp(-1.0, 1.0);
  }

  /// A lightweight stability proxy based on hip midpoint drift.
  static double stabilityFromHipHistory(List<double> hipMidpointX) {
    if (hipMidpointX.isEmpty) return 0;
    final double mean = hipMidpointX.reduce((double a, double b) => a + b) / hipMidpointX.length;
    final double variance = hipMidpointX
        .map((double value) => (value - mean) * (value - mean))
        .reduce((double a, double b) => a + b) /
        hipMidpointX.length;
    return 1 / (1 + math.sqrt(variance));
  }
}
