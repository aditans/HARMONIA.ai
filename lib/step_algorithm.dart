import 'dart:math' as math;

enum ActivityStatus { walking, idle }

class StepDetectionConfig {
  const StepDetectionConfig({
    this.gravityAlpha = 0.90,
    this.stepThreshold = 1.15,
    this.maxStepThreshold = 6.5,
    this.debounceMs = 380,
    this.idleTimeoutMs = 2200,
  });

  final double gravityAlpha;
  final double stepThreshold;
  final double maxStepThreshold;
  final int debounceMs;
  final int idleTimeoutMs;
}

class StepAlgorithmResult {
  const StepAlgorithmResult({
    required this.isStep,
    required this.filteredMagnitude,
    required this.status,
  });

  final bool isStep;
  final double filteredMagnitude;
  final ActivityStatus status;
}

class StepDetectionAlgorithm {
  StepDetectionAlgorithm({StepDetectionConfig config = const StepDetectionConfig()})
      : _config = config;

  final StepDetectionConfig _config;

  double _gravityEstimate = 9.81;
  double _prev2 = 0;
  double _prev1 = 0;
  DateTime? _lastStepAt;

  StepAlgorithmResult process({
    required double x,
    required double y,
    required double z,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final magnitude = math.sqrt((x * x) + (y * y) + (z * z));

    // Low-pass filter to estimate gravity, then isolate dynamic acceleration.
    _gravityEstimate =
        (_config.gravityAlpha * _gravityEstimate) + ((1 - _config.gravityAlpha) * magnitude);
    final filtered = (magnitude - _gravityEstimate).abs();

    bool stepDetected = false;
    final bool localPeak = _prev1 > _prev2 && _prev1 > filtered;
    final bool inStepBand = _prev1 >= _config.stepThreshold && _prev1 <= _config.maxStepThreshold;
    final bool debouncePassed = _lastStepAt == null ||
        now.difference(_lastStepAt!).inMilliseconds >= _config.debounceMs;

    if (localPeak && inStepBand && debouncePassed) {
      stepDetected = true;
      _lastStepAt = now;
    }

    _prev2 = _prev1;
    _prev1 = filtered;

    final isWalking = _lastStepAt != null &&
        now.difference(_lastStepAt!).inMilliseconds <= _config.idleTimeoutMs;

    return StepAlgorithmResult(
      isStep: stepDetected,
      filteredMagnitude: filtered,
      status: isWalking ? ActivityStatus.walking : ActivityStatus.idle,
    );
  }

  void reset() {
    _gravityEstimate = 9.81;
    _prev1 = 0;
    _prev2 = 0;
    _lastStepAt = null;
  }
}
