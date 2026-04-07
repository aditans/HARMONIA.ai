import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/auth/providers/auth_controller.dart';

class DashboardMetricsData {
  const DashboardMetricsData({
    required this.sleepHours,
    required this.sleepTarget,
    required this.waterCups,
    required this.waterTarget,
    required this.calories,
    required this.caloriesTarget,
    required this.heightCm,
    required this.weightKg,
    required this.heartRate,
    required this.heartRateTarget,
    required this.mealsDone,
    required this.mealsTarget,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    required this.workoutMinutes,
    required this.workoutTargetMinutes,
    required this.steps,
    required this.stepsTarget,
    required this.focusSessions,
    required this.focusTargetMinutes,
    required this.focusPercent,
  });

  final int sleepHours;
  final int sleepTarget;
  final int waterCups;
  final int waterTarget;
  final int calories;
  final int caloriesTarget;
  final int heightCm;
  final int weightKg;
  final int heartRate;
  final int heartRateTarget;
  final int mealsDone;
  final int mealsTarget;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;
  final int workoutMinutes;
  final int workoutTargetMinutes;
  final int steps;
  final int stepsTarget;
  final int focusSessions;
  final int focusTargetMinutes;
  final double focusPercent;

  static const DashboardMetricsData defaults = DashboardMetricsData(
    sleepHours: 8,
    sleepTarget: 8,
    waterCups: 5,
    waterTarget: 14,
    calories: 3642,
    caloriesTarget: 5000,
    heightCm: 170,
    weightKg: 70,
    heartRate: 129,
    heartRateTarget: 140,
    mealsDone: 2,
    mealsTarget: 5,
    proteinGrams: 120,
    carbsGrams: 220,
    fatsGrams: 60,
    workoutMinutes: 90,
    workoutTargetMinutes: 120,
    steps: 0,
    stepsTarget: 8000,
    focusSessions: 0,
    focusTargetMinutes: 25,
    focusPercent: 0,
  );

  DashboardMetricsData copyWith({
    int? sleepHours,
    int? sleepTarget,
    int? waterCups,
    int? waterTarget,
    int? calories,
    int? caloriesTarget,
    int? heightCm,
    int? weightKg,
    int? heartRate,
    int? heartRateTarget,
    int? mealsDone,
    int? mealsTarget,
    int? proteinGrams,
    int? carbsGrams,
    int? fatsGrams,
    int? workoutMinutes,
    int? workoutTargetMinutes,
    int? steps,
    int? stepsTarget,
    int? focusSessions,
    int? focusTargetMinutes,
    double? focusPercent,
  }) {
    return DashboardMetricsData(
      sleepHours: sleepHours ?? this.sleepHours,
      sleepTarget: sleepTarget ?? this.sleepTarget,
      waterCups: waterCups ?? this.waterCups,
      waterTarget: waterTarget ?? this.waterTarget,
      calories: calories ?? this.calories,
      caloriesTarget: caloriesTarget ?? this.caloriesTarget,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      heartRate: heartRate ?? this.heartRate,
      heartRateTarget: heartRateTarget ?? this.heartRateTarget,
      mealsDone: mealsDone ?? this.mealsDone,
      mealsTarget: mealsTarget ?? this.mealsTarget,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatsGrams: fatsGrams ?? this.fatsGrams,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      workoutTargetMinutes: workoutTargetMinutes ?? this.workoutTargetMinutes,
      steps: steps ?? this.steps,
      stepsTarget: stepsTarget ?? this.stepsTarget,
      focusSessions: focusSessions ?? this.focusSessions,
      focusTargetMinutes: focusTargetMinutes ?? this.focusTargetMinutes,
      focusPercent: focusPercent ?? this.focusPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sleepHours': sleepHours,
      'sleepTarget': sleepTarget,
      'waterCups': waterCups,
      'waterTarget': waterTarget,
      'calories': calories,
      'caloriesTarget': caloriesTarget,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'heartRate': heartRate,
      'heartRateTarget': heartRateTarget,
      'mealsDone': mealsDone,
      'mealsTarget': mealsTarget,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatsGrams': fatsGrams,
      'workoutMinutes': workoutMinutes,
      'workoutTargetMinutes': workoutTargetMinutes,
      'steps': steps,
      'stepsTarget': stepsTarget,
      'focusSessions': focusSessions,
      'focusTargetMinutes': focusTargetMinutes,
      'focusPercent': focusPercent,
    };
  }

  static DashboardMetricsData fromMap(Map<String, dynamic>? raw) {
    if (raw == null) {
      return defaults;
    }
    int readInt(String key, int fallback) {
      final value = raw[key];
      if (value is int) return value;
      if (value is num) return value.round();
      return fallback;
    }

    double readDouble(String key, double fallback) {
      final value = raw[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return fallback;
    }

    return defaults.copyWith(
      sleepHours: readInt('sleepHours', defaults.sleepHours),
      sleepTarget: readInt('sleepTarget', defaults.sleepTarget),
      waterCups: readInt('waterCups', defaults.waterCups),
      waterTarget: readInt('waterTarget', defaults.waterTarget),
      calories: readInt('calories', defaults.calories),
      caloriesTarget: readInt('caloriesTarget', defaults.caloriesTarget),
      heightCm: readInt('heightCm', defaults.heightCm),
      weightKg: readInt('weightKg', defaults.weightKg),
      heartRate: readInt('heartRate', defaults.heartRate),
      heartRateTarget: readInt('heartRateTarget', defaults.heartRateTarget),
      mealsDone: readInt('mealsDone', defaults.mealsDone),
      mealsTarget: readInt('mealsTarget', defaults.mealsTarget),
      proteinGrams: readInt('proteinGrams', defaults.proteinGrams),
      carbsGrams: readInt('carbsGrams', defaults.carbsGrams),
      fatsGrams: readInt('fatsGrams', defaults.fatsGrams),
      workoutMinutes: readInt('workoutMinutes', defaults.workoutMinutes),
      workoutTargetMinutes:
          readInt('workoutTargetMinutes', defaults.workoutTargetMinutes),
      steps: readInt('steps', defaults.steps),
      stepsTarget: readInt('stepsTarget', defaults.stepsTarget),
      focusSessions: readInt('focusSessions', defaults.focusSessions),
      focusTargetMinutes:
          readInt('focusTargetMinutes', defaults.focusTargetMinutes),
      focusPercent: readDouble('focusPercent', defaults.focusPercent),
    );
  }
}

class ActivityLogItem {
  const ActivityLogItem({
    required this.activity,
    required this.label,
    required this.durationSeconds,
    required this.reps,
    required this.holdSeconds,
    required this.focusPercent,
    required this.createdAt,
    required this.status,
  });

  final String activity;
  final String label;
  final int durationSeconds;
  final int reps;
  final int holdSeconds;
  final double focusPercent;
  final DateTime createdAt;
  final String status;

  static ActivityLogItem fromMap(Map<String, dynamic> raw) {
    final ts = raw['createdAt'];
    final at = ts is Timestamp ? ts.toDate() : DateTime.now();
    return ActivityLogItem(
      activity: (raw['activity'] ?? '').toString(),
      label: (raw['label'] ?? '').toString(),
      durationSeconds: ((raw['durationSeconds'] ?? 0) as num).round(),
      reps: ((raw['reps'] ?? 0) as num).round(),
      holdSeconds: ((raw['holdSeconds'] ?? 0) as num).round(),
      focusPercent: ((raw['focusPercent'] ?? 0) as num).toDouble(),
      createdAt: at,
      status: (raw['status'] ?? 'completed').toString(),
    );
  }
}

class DashboardDataService {
  DashboardDataService(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  String get _dayKey {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  DocumentReference<Map<String, dynamic>> _dayDoc() {
    return _db.collection('users').doc(_uid).collection('daily_metrics').doc(_dayKey);
  }

  CollectionReference<Map<String, dynamic>> _logs() {
    return _db.collection('users').doc(_uid).collection('activity_logs');
  }

  Stream<DashboardMetricsData> dailyMetricsStream() {
    return _dayDoc().snapshots().map((doc) {
      if (!doc.exists) {
        return DashboardMetricsData.defaults;
      }
      return DashboardMetricsData.fromMap(doc.data());
    });
  }

  Stream<List<ActivityLogItem>> activityLogsStream() {
    return _logs().orderBy('createdAt', descending: true).limit(50).snapshots().map(
      (snap) {
        return snap.docs.map((d) => ActivityLogItem.fromMap(d.data())).toList();
      },
    );
  }

  Future<void> updateMetrics(Map<String, dynamic> patch) async {
    final payload = <String, dynamic>{
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _dayDoc().set(payload, SetOptions(merge: true));
  }

  Future<void> saveActivitySession({
    required String activity,
    required String label,
    required int durationSeconds,
    required String status,
    int reps = 0,
    int holdSeconds = 0,
    double focusPercent = 0,
  }) async {
    final safeSeconds = durationSeconds < 0 ? 0 : durationSeconds;
    await _logs().add({
      'activity': activity,
      'label': label,
      'durationSeconds': safeSeconds,
      'reps': reps,
      'holdSeconds': holdSeconds,
      'focusPercent': focusPercent,
      'status': status,
      'dayKey': _dayKey,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final minutes = (safeSeconds / 60).ceil();
    final patch = <String, dynamic>{};
    if (activity == 'exercise' || activity == 'yoga') {
      patch['workoutMinutes'] = FieldValue.increment(minutes);
    }
    if (activity == 'focus') {
      patch['focusSessions'] = FieldValue.increment(1);
      patch['focusPercent'] = focusPercent;
    }
    if (patch.isNotEmpty) {
      await updateMetrics(patch);
    }
  }
}

final dashboardDataServiceProvider = Provider<DashboardDataService?>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) {
    return null;
  }
  return DashboardDataService(db, user.uid);
});

final dailyMetricsProvider = StreamProvider<DashboardMetricsData>((ref) {
  final service = ref.watch(dashboardDataServiceProvider);
  if (service == null) {
    return Stream.value(DashboardMetricsData.defaults);
  }
  return service.dailyMetricsStream();
});

final activityLogsProvider = StreamProvider<List<ActivityLogItem>>((ref) {
  final service = ref.watch(dashboardDataServiceProvider);
  if (service == null) {
    return Stream.value(const []);
  }
  return service.activityLogsStream();
});
