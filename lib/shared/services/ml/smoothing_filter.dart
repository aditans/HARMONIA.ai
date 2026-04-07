import 'dart:collection';

class EmaFilter {
  EmaFilter({this.alpha = 0.3});

  final double alpha;
  double? _previous;

  double apply(double value) {
    final double next =
        _previous == null ? value : alpha * value + (1 - alpha) * _previous!;
    _previous = next;
    return next;
  }
}

class MedianAngleBuffer {
  MedianAngleBuffer({this.windowSize = 5});

  final int windowSize;
  final Queue<double> _values = Queue<double>();

  double addAndGetMedian(double value) {
    _values.addLast(value);
    if (_values.length > windowSize) {
      _values.removeFirst();
    }
    final List<double> sorted = _values.toList()..sort();
    return sorted[sorted.length ~/ 2];
  }
}

class JointSmoothingPipeline {
  JointSmoothingPipeline({this.alpha = 0.3, this.windowSize = 5})
      : _ema = EmaFilter(alpha: alpha),
        _median = MedianAngleBuffer(windowSize: windowSize);

  final double alpha;
  final int windowSize;
  final EmaFilter _ema;
  final MedianAngleBuffer _median;

  double smooth(double rawAngle) {
    final double median = _median.addAndGetMedian(rawAngle);
    return _ema.apply(median);
  }
}
