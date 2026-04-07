import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harmonia_ai/step_algorithm.dart';
import 'package:harmonia_ai/step_service.dart';

class StepCounterState {
  const StepCounterState({
    required this.stepsToday,
    required this.dayKey,
    required this.status,
    required this.lastMagnitude,
    required this.history,
    required this.permissionGranted,
  });

  final int stepsToday;
  final String dayKey;
  final ActivityStatus status;
  final double lastMagnitude;
  final Map<String, int> history;
  final bool permissionGranted;

  StepCounterState copyWith({
    int? stepsToday,
    String? dayKey,
    ActivityStatus? status,
    double? lastMagnitude,
    Map<String, int>? history,
    bool? permissionGranted,
  }) {
    return StepCounterState(
      stepsToday: stepsToday ?? this.stepsToday,
      dayKey: dayKey ?? this.dayKey,
      status: status ?? this.status,
      lastMagnitude: lastMagnitude ?? this.lastMagnitude,
      history: history ?? this.history,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }

  static StepCounterState initial() => StepCounterState(
        stepsToday: 0,
        dayKey: _todayKey(),
        status: ActivityStatus.idle,
        lastMagnitude: 0,
        history: const {},
        permissionGranted: false,
      );

  static String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }
}

final stepServiceProvider = Provider<StepService>((ref) {
  final service = StepService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class StepCounterController extends AsyncNotifier<StepCounterState> {
  static const String _kDay = 'steps_day_key';
  static const String _kCount = 'steps_day_count';
  static const String _kHistory = 'steps_history_json';

  StreamSubscription<StepReading>? _sub;

  @override
  Future<StepCounterState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDay = prefs.getString(_kDay) ?? StepCounterState._todayKey();
    final savedCount = prefs.getInt(_kCount) ?? 0;
    final historyRaw = prefs.getString(_kHistory);
    final history = _decodeHistory(historyRaw);

    final today = StepCounterState._todayKey();
    final count = savedDay == today ? savedCount : 0;
    if (savedDay != today) {
      await prefs.setString(_kDay, today);
      await prefs.setInt(_kCount, 0);
      history[today] = 0;
      await prefs.setString(_kHistory, jsonEncode(history));
    }

    ref.onDispose(() async {
      await _sub?.cancel();
    });

    return StepCounterState(
      stepsToday: count,
      dayKey: today,
      status: ActivityStatus.idle,
      lastMagnitude: 0,
      history: history,
      permissionGranted: false,
    );
  }

  Future<void> startTracking() async {
    final current = await future;
    final service = ref.read(stepServiceProvider);
    final granted = await service.ensurePermission();

    state = AsyncData(current.copyWith(permissionGranted: granted));
    if (!granted || _sub != null) {
      return;
    }

    await service.start();
    _sub = service.readings.listen((reading) async {
      final currentState = await future;
      final today = StepCounterState._todayKey();
      var next = currentState;

      if (currentState.dayKey != today) {
        final updatedHistory = Map<String, int>.from(currentState.history)
          ..putIfAbsent(today, () => 0);
        next = currentState.copyWith(
          dayKey: today,
          stepsToday: 0,
          history: updatedHistory,
        );
      }

      final increment = reading.isStep ? 1 : 0;
      final newCount = next.stepsToday + increment;
      final updatedHistory = Map<String, int>.from(next.history)
        ..[today] = newCount;

      final updated = next.copyWith(
        stepsToday: newCount,
        status: reading.status,
        lastMagnitude: reading.filteredMagnitude,
        history: updatedHistory,
      );

      state = AsyncData(updated);
      await _persist(updated);
    });
  }

  Future<void> pauseTracking() async {
    await ref.read(stepServiceProvider).stop();
    await _sub?.cancel();
    _sub = null;

    final current = await future;
    state = AsyncData(current.copyWith(status: ActivityStatus.idle));
  }

  Future<void> resumeTracking() async {
    if (_sub == null) {
      await startTracking();
    }
  }

  Future<void> _persist(StepCounterState stateValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDay, stateValue.dayKey);
    await prefs.setInt(_kCount, stateValue.stepsToday);
    await prefs.setString(_kHistory, jsonEncode(stateValue.history));
  }

  Map<String, int> _decodeHistory(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }
      return decoded.map(
        (key, value) => MapEntry(key, (value as num).round()),
      );
    } catch (_) {
      return {};
    }
  }
}

final stepCounterProvider =
    AsyncNotifierProvider<StepCounterController, StepCounterState>(
  StepCounterController.new,
);
