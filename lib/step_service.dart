import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:harmonia_ai/step_algorithm.dart';

class StepReading {
  const StepReading({
    required this.isStep,
    required this.filteredMagnitude,
    required this.status,
    required this.time,
  });

  final bool isStep;
  final double filteredMagnitude;
  final ActivityStatus status;
  final DateTime time;
}

class StepService {
  StepService({StepDetectionAlgorithm? algorithm})
      : _algorithm = algorithm ?? StepDetectionAlgorithm();

  final StepDetectionAlgorithm _algorithm;
  final StreamController<StepReading> _controller =
      StreamController<StepReading>.broadcast();

  StreamSubscription<AccelerometerEvent>? _subscription;

  Stream<StepReading> get readings => _controller.stream;

  Future<bool> ensurePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    }
    if (Platform.isIOS) {
      final status = await Permission.sensors.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> start() async {
    if (_subscription != null) {
      return;
    }
    final hasPermission = await ensurePermission();
    if (!hasPermission) {
      return;
    }

    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((event) {
        final result = _algorithm.process(
          x: event.x,
          y: event.y,
          z: event.z,
        );

        _controller.add(
          StepReading(
            isStep: result.isStep,
            filteredMagnitude: result.filteredMagnitude,
            status: result.status,
            time: DateTime.now(),
          ),
        );
      });
    } catch (_) {
      _subscription = null;
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
