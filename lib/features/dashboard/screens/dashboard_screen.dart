import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:harmonia_ai/features/auth/providers/auth_controller.dart';
import 'package:harmonia_ai/features/dashboard/providers/dashboard_data_provider.dart';
import 'package:harmonia_ai/step_algorithm.dart';
import 'package:harmonia_ai/step_provider.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.sleepHours,
    required this.sleepTarget,
    required this.waterCups,
    required this.waterTarget,
    required this.calories,
    required this.caloriesTarget,
    required this.heartRate,
    required this.heartRateTarget,
    required this.mealsDone,
    required this.mealsTarget,
    required this.workoutMinutes,
    required this.workoutTargetMinutes,
  });

  final int sleepHours;
  final int sleepTarget;
  final int waterCups;
  final int waterTarget;
  final int calories;
  final int caloriesTarget;
  final int heartRate;
  final int heartRateTarget;
  final int mealsDone;
  final int mealsTarget;
  final int workoutMinutes;
  final int workoutTargetMinutes;

  DashboardMetrics copyWith({
    int? sleepHours,
    int? sleepTarget,
    int? waterCups,
    int? waterTarget,
    int? calories,
    int? caloriesTarget,
    int? heartRate,
    int? heartRateTarget,
    int? mealsDone,
    int? mealsTarget,
    int? workoutMinutes,
    int? workoutTargetMinutes,
  }) {
    return DashboardMetrics(
      sleepHours: sleepHours ?? this.sleepHours,
      sleepTarget: sleepTarget ?? this.sleepTarget,
      waterCups: waterCups ?? this.waterCups,
      waterTarget: waterTarget ?? this.waterTarget,
      calories: calories ?? this.calories,
      caloriesTarget: caloriesTarget ?? this.caloriesTarget,
      heartRate: heartRate ?? this.heartRate,
      heartRateTarget: heartRateTarget ?? this.heartRateTarget,
      mealsDone: mealsDone ?? this.mealsDone,
      mealsTarget: mealsTarget ?? this.mealsTarget,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      workoutTargetMinutes: workoutTargetMinutes ?? this.workoutTargetMinutes,
    );
  }
}

final dashboardMetricsProvider = StateProvider<DashboardMetrics>((ref) {
  return const DashboardMetrics(
    sleepHours: 8,
    sleepTarget: 8,
    waterCups: 5,
    waterTarget: 14,
    calories: 3642,
    caloriesTarget: 5000,
    heartRate: 129,
    heartRateTarget: 140,
    mealsDone: 2,
    mealsTarget: 5,
    workoutMinutes: 90,
    workoutTargetMinutes: 120,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark ? const Color(0xFF12131A) : const Color(0xFFEAEAEA);
    final panel = isDark ? const Color(0xFF1B1D29) : Colors.white;
    final softText = isDark ? Colors.white70 : const Color(0xFF8B8B8B);
    final widthFull = MediaQuery.of(context).size.width - 32;
    final user = ref.watch(authStateProvider).valueOrNull;
    final metricsData =
        ref.watch(dailyMetricsProvider).valueOrNull ?? DashboardMetricsData.defaults;
    final metrics = DashboardMetrics(
      sleepHours: metricsData.sleepHours,
      sleepTarget: metricsData.sleepTarget,
      waterCups: metricsData.waterCups,
      waterTarget: metricsData.waterTarget,
      calories: metricsData.calories,
      caloriesTarget: metricsData.caloriesTarget,
      heartRate: metricsData.heartRate,
      heartRateTarget: metricsData.heartRateTarget,
      mealsDone: metricsData.mealsDone,
      mealsTarget: metricsData.mealsTarget,
      workoutMinutes: metricsData.workoutMinutes,
      workoutTargetMinutes: metricsData.workoutTargetMinutes,
    );

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _weekLabel(),
              style: TextStyle(color: softText, fontSize: 14, fontFamily: 'JosefinSans'),
            ),
            Text(
              _dateLabel(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _UserAvatar(user: user),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GridCard(
                widthFull: widthFull,
                child: _SleepCard(
                  panel: panel,
                  softText: softText,
                  hours: metrics.sleepHours,
                  target: metrics.sleepTarget,
                  onLongPress: () async {
                    final v = await _showEditor(
                      context,
                      title: 'Sleep',
                      currentLabel: 'Hours',
                      targetLabel: 'Target',
                      current: metrics.sleepHours,
                      target: metrics.sleepTarget,
                    );
                    if (v == null) return;
                    await _saveMetricsPatch(
                      ref,
                      {
                        'sleepHours': v.current,
                        'sleepTarget': v.target <= 0 ? 1 : v.target,
                      },
                    );
                  },
                ),
              ),
              _GridCard(
                widthFull: widthFull,
                child: _WaterCard(
                  cups: metrics.waterCups,
                  totalCups: metrics.waterTarget,
                  onTap: () {
                    _saveMetricsPatch(ref, {
                      'waterCups': (metrics.waterCups + 1).clamp(0, metrics.waterTarget),
                    });
                  },
                  onDoubleTap: () {
                    _saveMetricsPatch(ref, {
                      'waterCups': (metrics.waterCups - 1).clamp(0, metrics.waterTarget),
                    });
                  },
                  onLongPress: () async {
                    final v = await _showEditor(
                      context,
                      title: 'Water',
                      currentLabel: 'Cups',
                      targetLabel: 'Target cups',
                      current: metrics.waterCups,
                      target: metrics.waterTarget,
                    );
                    if (v == null) return;
                    final safeTarget = v.target <= 0 ? 1 : v.target;
                    await _saveMetricsPatch(
                      ref,
                      {
                        'waterTarget': safeTarget,
                        'waterCups': v.current.clamp(0, safeTarget),
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GridCard(
                widthFull: widthFull,
                child: _TapCard(
                  onTap: () => context.push('/stats/calories'),
                  child: _CaloriesCard(
                    calories: metrics.calories,
                    target: metrics.caloriesTarget,
                    onLongPress: () async {
                      final v = await _showEditor(
                        context,
                        title: 'Calories',
                        currentLabel: 'Current kcal',
                        targetLabel: 'Target kcal',
                        current: metrics.calories,
                        target: metrics.caloriesTarget,
                      );
                      if (v == null) return;
                      await _saveMetricsPatch(
                        ref,
                        {
                          'calories': v.current,
                          'caloriesTarget': v.target <= 0 ? 1 : v.target,
                        },
                      );
                    },
                  ),
                ),
              ),
              _GridCard(
                widthFull: widthFull,
                child: _TapCard(
                  onTap: () => context.push('/stats/heart-rate'),
                  child: _HeartRateCard(
                    panel: panel,
                    softText: softText,
                    bpm: metrics.heartRate,
                    target: metrics.heartRateTarget,
                    onLongPress: () async {
                      final v = await _showEditor(
                        context,
                        title: 'Heart Rate',
                        currentLabel: 'Current bpm',
                        targetLabel: 'Target bpm',
                        current: metrics.heartRate,
                        target: metrics.heartRateTarget,
                      );
                      if (v == null) return;
                      await _saveMetricsPatch(
                        ref,
                        {
                          'heartRate': v.current,
                          'heartRateTarget': v.target <= 0 ? 1 : v.target,
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GridCard(
                widthFull: widthFull,
                child: _TapCard(
                  onTap: () => context.push('/stats/meals'),
                  child: _MealsCard(
                    panel: panel,
                    softText: softText,
                    done: metrics.mealsDone,
                    target: metrics.mealsTarget,
                    onLongPress: () async {
                      final v = await _showEditor(
                        context,
                        title: 'Meals',
                        currentLabel: 'Meals done',
                        targetLabel: 'Meals target',
                        current: metrics.mealsDone,
                        target: metrics.mealsTarget,
                      );
                      if (v == null) return;
                      final safeTarget = v.target <= 0 ? 1 : v.target;
                      await _saveMetricsPatch(
                        ref,
                        {
                          'mealsDone': v.current.clamp(0, safeTarget),
                          'mealsTarget': safeTarget,
                        },
                      );
                    },
                  ),
                ),
              ),
              _GridCard(
                widthFull: widthFull,
                child: _TapCard(
                  onTap: () => context.push('/stats/workout'),
                  child: _WorkoutCard(
                  minutes: metrics.workoutMinutes,
                  targetMinutes: metrics.workoutTargetMinutes,
                  onLongPress: () async {
                    final v = await _showEditor(
                      context,
                      title: 'Workout',
                      currentLabel: 'Minutes done',
                      targetLabel: 'Target minutes',
                      current: metrics.workoutMinutes,
                      target: metrics.workoutTargetMinutes,
                    );
                    if (v == null) return;
                    final safeTarget = v.target <= 0 ? 1 : v.target;
                    await _saveMetricsPatch(
                      ref,
                      {
                        'workoutMinutes': v.current.clamp(0, 600),
                        'workoutTargetMinutes': safeTarget.clamp(1, 600),
                      },
                    );
                  },
                ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GridCard(
                widthFull: widthFull,
                child: _StepsCard(
                  target: metricsData.stepsTarget,
                  onLongPress: () async {
                    final stepState = ref.read(stepCounterProvider).valueOrNull;
                    final v = await _showEditor(
                      context,
                      title: 'Steps',
                      currentLabel: 'Today steps',
                      targetLabel: 'Steps target',
                      current: stepState?.stepsToday ?? 0,
                      target: metricsData.stepsTarget,
                    );
                    if (v == null) return;
                    final safeTarget = v.target <= 0 ? 1 : v.target;
                    await _saveMetricsPatch(
                      ref,
                      {
                        'stepsTarget': safeTarget.clamp(1, 500000),
                      },
                    );
                  },
                ),
              ),
              _GridCard(
                widthFull: widthFull,
                child: _FocusCard(
                  sessions: metricsData.focusSessions,
                  targetMinutes: metricsData.focusTargetMinutes,
                  focusPercent: metricsData.focusPercent,
                  onLongPress: () async {
                    final v = await _showEditor(
                      context,
                      title: 'Focus Goal',
                      currentLabel: 'Focused sessions',
                      targetLabel: 'Pomodoro target (minutes)',
                      current: metricsData.focusSessions,
                      target: metricsData.focusTargetMinutes,
                    );
                    if (v == null) return;
                    final safeTarget = v.target <= 0 ? 1 : v.target;
                    await _saveMetricsPatch(
                      ref,
                      {
                        'focusSessions': v.current.clamp(0, 1000),
                        'focusTargetMinutes': safeTarget.clamp(1, 240),
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveMetricsPatch(WidgetRef ref, Map<String, dynamic> patch) async {
    final service = ref.read(dashboardDataServiceProvider);
    if (service == null) return;
    await service.updateMetrics(patch);
  }

  Future<_MetricEdit?> _showEditor(
    BuildContext context, {
    required String title,
    required String currentLabel,
    required String targetLabel,
    required int current,
    required int target,
  }) async {
    final currentController = TextEditingController(text: current.toString());
    final targetController = TextEditingController(text: target.toString());

    final result = await showDialog<_MetricEdit>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: currentLabel),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: targetLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsedCurrent = int.tryParse(currentController.text.trim());
                final parsedTarget = int.tryParse(targetController.text.trim());
                if (parsedCurrent == null || parsedTarget == null) {
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _MetricEdit(current: parsedCurrent, target: parsedTarget),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    currentController.dispose();
    targetController.dispose();
    return result;
  }

  String _weekLabel() {
    final now = DateTime.now();
    final week = ((now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor() + 1).clamp(1, 52);
    return 'Week $week, Day ${now.weekday}';
  }

  String _dateLabel() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final suffix = _daySuffix(now.day);
    return 'Today, ${now.day}$suffix, ${months[now.month - 1]}, ${now.year}';
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

class _MetricEdit {
  const _MetricEdit({required this.current, required this.target});

  final int current;
  final int target;
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    final name = user?.displayName?.trim() ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'H';

    return CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(initials, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700))
          : null,
    );
  }
}

class _TapCard extends StatelessWidget {
  const _TapCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: child);
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.widthFull, required this.child});

  final double widthFull;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cardWidth = (widthFull - 12) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: cardWidth,
        height: 238,
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
      ),
    );
  }
}

class _CardScaler extends StatelessWidget {
  const _CardScaler({required this.child});

  final Widget child;
  static const double _designW = 168;
  static const double _designH = 236;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final scale = math.min(constraints.maxWidth / _designW, constraints.maxHeight / _designH);
        final safeScale = scale.clamp(0.62, 1.0);
        return Center(
          child: SizedBox(
            width: _designW * safeScale,
            height: _designH * safeScale,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _designW,
                height: _designH,
                child: MediaQuery(data: media.copyWith(textScaler: TextScaler.noScaling), child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({
    required this.panel,
    required this.softText,
    required this.hours,
    required this.target,
    required this.onLongPress,
  });

  final Color panel;
  final Color softText;
  final int hours;
  final int target;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sleep', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Oswald', color: textColor)),
                    Image.asset('assets/images/moon.png', width: 30, height: 30, color: textColor),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('Hours', style: TextStyle(fontSize: 16)),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$hours', style: TextStyle(fontSize: 70, fontFamily: 'JosefinSans', fontWeight: FontWeight.w700, color: textColor)),
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Row(
                          children: [
                            Text('/$target', style: TextStyle(fontSize: 20, fontFamily: 'JosefinSans', color: textColor)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: onLongPress,
                              child: Icon(Icons.edit, size: 14, color: textColor.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text('Goal Achieved', style: TextStyle(color: softText, fontSize: 17)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({
    required this.cups,
    required this.totalCups,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  final int cups;
  final int totalCups;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFF9CD9FF) : const Color(0xFF0066A5);
    final valueColor = isDark ? const Color(0xFFD8F0FF) : const Color(0xFF0066A5);
    final fill = totalCups <= 0 ? 0.0 : (cups / totalCups).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isDark ? [const Color(0xFF164564), const Color(0xFF0E6EB0)] : [const Color(0xFF53BCFF), const Color(0xFF2D96DB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _CardScaler(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(painter: _WaterFillPainter(fillLevel: fill, isDark: isDark)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Water', style: TextStyle(fontSize: 24, fontFamily: 'Oswald', color: titleColor)),
                        Image.asset('assets/images/water.png', width: 28, height: 28, color: titleColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Cups', style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w700)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text('$cups', style: TextStyle(fontSize: 72, fontFamily: 'JosefinSans', fontWeight: FontWeight.w700, color: valueColor)),
                          Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: Row(
                              children: [
                                Text('/$totalCups', style: TextStyle(fontSize: 20, fontFamily: 'JosefinSans', color: valueColor)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: onLongPress,
                                  child: Icon(Icons.edit, size: 14, color: valueColor.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final slot = constraints.maxWidth / totalCups;
                          final dot = slot.clamp(3.0, 6.0);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(totalCups, (i) {
                              final filled = i < cups;
                              return Container(
                                width: dot,
                                height: filled ? 34 : dot,
                                decoration: filled
                                    ? BoxDecoration(
                                        color: valueColor,
                                        borderRadius: BorderRadius.circular(4),
                                        shape: BoxShape.rectangle,
                                      )
                                    : BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        shape: BoxShape.circle,
                                      ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({
    required this.calories,
    required this.target,
    required this.onLongPress,
  });

  final int calories;
  final int target;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? [const Color(0xFFB95D00), const Color(0xFF8E320A)] : [const Color(0xFFE29B08), const Color(0xFFD74B17)];
    final progress = target <= 0 ? 0.0 : (calories / target).clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Calories', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontFamily: 'Oswald')),
                    Image.asset('assets/images/fire.png', width: 30, height: 30, color: Colors.white),
                  ],
                ),
                const Spacer(),
                Center(
                  child: SizedBox(
                    width: 126,
                    height: 126,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(size: const Size.square(126), painter: _CalorieArcPainter(progress: progress)),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$calories', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
                            const Text('kcal', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard({
    required this.panel,
    required this.softText,
    required this.bpm,
    required this.target,
    required this.onLongPress,
  });

  final Color panel;
  final Color softText;
  final int bpm;
  final int target;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Heart Rate', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'Oswald')),
                    Image.asset('assets/images/heart.png', width: 28, height: 28, color: const Color(0xFFF90659)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(height: 36, width: double.infinity, child: CustomPaint(painter: _PinkWavePainter())),
                const Spacer(),
                Center(
                  child: Text('$bpm', style: const TextStyle(color: Color(0xFFF90659), fontSize: 58, fontWeight: FontWeight.w700)),
                ),
                Center(child: Text('Target: $target bpm', style: TextStyle(color: softText, fontSize: 12))),
                Center(child: Text('bpm', style: TextStyle(color: softText, fontSize: 15))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({
    required this.panel,
    required this.softText,
    required this.done,
    required this.target,
    required this.onLongPress,
  });

  final Color panel;
  final Color softText;
  final int done;
  final int target;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF45E06D) : const Color(0xFF1FC700);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Meals', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'Oswald')),
                    Image.asset('assets/images/tray.png', width: 28, height: 28, color: accent),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$done', style: TextStyle(fontSize: 72, fontFamily: 'JosefinSans', fontWeight: FontWeight.w700, color: accent)),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text('/$target', style: TextStyle(fontSize: 20, fontFamily: 'JosefinSans', color: accent)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _dailyMeal(accent, '1 Apple', softText),
                          _dailyMeal(accent, 'White Bread', softText),
                          _dailyMeal(accent, 'Green Veggies', softText),
                          _dailyMeal(accent, '2 Eggs', softText),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      Text('02:19:06', style: TextStyle(color: accent, fontSize: 20)),
                      Text('For Next Meal', style: TextStyle(color: softText, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dailyMeal(Color accent, String title, Color softText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 1.4)),
          ),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: softText, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.minutes, required this.targetMinutes, required this.onLongPress});

  final int minutes;
  final int targetMinutes;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final progress = targetMinutes <= 0 ? 0.0 : (minutes / targetMinutes).clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF921AEA), Color(0xFF390095)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Workout', style: TextStyle(fontSize: 22, color: Colors.white, fontFamily: 'Oswald')),
                          Text('Biceps & Triceps', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset('assets/images/dumbbell.png', width: 24, height: 24, color: Colors.white),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 118,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      CustomPaint(size: const Size(118, 76), painter: _WorkoutGaugePainter(progress: progress)),
                      Positioned(bottom: 18, child: Text(_formatMinutes(minutes), style: const TextStyle(color: Colors.white, fontSize: 32))),
                      const Positioned(bottom: 0, child: Text('hours', style: TextStyle(color: Colors.white, fontSize: 18))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Goal ${_formatMinutes(targetMinutes)}', style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString()}:${m.toString().padLeft(2, '0')}';
  }
}

class _StepsCard extends ConsumerStatefulWidget {
  const _StepsCard({
    required this.target,
    required this.onLongPress,
  });

  final int target;
  final VoidCallback onLongPress;

  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard>
    with WidgetsBindingObserver {
  int _lastSteps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stepCounterProvider.notifier).startTracking();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(stepCounterProvider.notifier).pauseTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(stepCounterProvider.notifier).resumeTracking();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(stepCounterProvider.notifier).pauseTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(stepCounterProvider).valueOrNull;
    final steps = stepState?.stepsToday ?? 0;
    final status = stepState?.status ?? ActivityStatus.idle;
    final progress = widget.target <= 0 ? 0.0 : (steps / widget.target).clamp(0.0, 1.0);
    final permissionGranted = stepState?.permissionGranted ?? true;

    if (steps > _lastSteps) {
      _lastSteps = steps;
    }

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF15A971), Color(0xFF0D6C53)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Steps', style: TextStyle(fontSize: 24, color: Colors.white, fontFamily: 'Oswald')),
                    Icon(Icons.directions_walk, color: Colors.white),
                  ],
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 0.86, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Text(
                    '$steps',
                    key: ValueKey<int>(steps),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Row(
                  children: [
                    Text('/${widget.target}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onLongPress,
                      child: const Icon(Icons.edit, size: 14, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  permissionGranted
                      ? (status == ActivityStatus.walking ? 'Walking' : 'Idle')
                      : 'Permission required',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.sessions,
    required this.targetMinutes,
    required this.focusPercent,
    required this.onLongPress,
  });

  final int sessions;
  final int targetMinutes;
  final double focusPercent;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = (focusPercent / 100).clamp(0.0, 1.0);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: _CardScaler(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Focus', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'Oswald')),
                    const Icon(Icons.timelapse, color: Color(0xFF2D9F57)),
                  ],
                ),
                const Spacer(),
                Text('$sessions sessions', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Text('Target $targetMinutes min', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onLongPress,
                      child: const Icon(Icons.edit, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: p,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D9F57)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Focused ${focusPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterFillPainter extends CustomPainter {
  _WaterFillPainter({required this.fillLevel, required this.isDark});

  final double fillLevel;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final zoneTop = size.height * 0.34;
    final zoneHeight = size.height * 0.60;
    final baseY = zoneTop + (1 - fillLevel) * zoneHeight;

    final backPaint = Paint()
      ..color = (isDark ? const Color(0xFF0F78C2) : const Color(0xFF0493EE)).withValues(alpha: 0.88);
    final frontPaint = Paint()
      ..color = (isDark ? const Color(0xFF6CC7FF) : const Color(0xFF65BEF7)).withValues(alpha: 0.56);

    final back = Path()
      ..moveTo(0, baseY)
      ..quadraticBezierTo(size.width * 0.28, baseY - 22, size.width * 0.54, baseY)
      ..quadraticBezierTo(size.width * 0.78, baseY + 24, size.width, baseY - 2)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final front = Path()
      ..moveTo(0, baseY + 8)
      ..quadraticBezierTo(size.width * 0.22, baseY - 16, size.width * 0.5, baseY + 6)
      ..quadraticBezierTo(size.width * 0.74, baseY + 28, size.width, baseY + 8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(back, backPaint);
    canvas.drawPath(front, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterFillPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.isDark != isDark;
  }
}

class _CalorieArcPainter extends CustomPainter {
  _CalorieArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    final fg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;

    const start = math.pi * 0.8;
    const totalSweep = math.pi * 1.4;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 8), start, totalSweep, false, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 8), start, totalSweep * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _CalorieArcPainter oldDelegate) => oldDelegate.progress != progress;
}

class _PinkWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF90659)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.15, 0, size.width * 0.3, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.48, size.height, size.width * 0.6, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.82, 0, size.width, size.height * 0.35);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinkWavePainter oldDelegate) => false;
}

class _WorkoutGaugePainter extends CustomPainter {
  _WorkoutGaugePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final fgPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height + 6);
    final radius = size.width * 0.62;
    for (int i = 0; i <= 56; i++) {
      final angle = math.pi + (i / 56) * math.pi;
      final p1 = Offset(center.dx + (radius - 14) * math.cos(angle), center.dy + (radius - 14) * math.sin(angle));
      final p2 = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      final t = i / 56;
      canvas.drawLine(p1, p2, t <= progress ? fgPaint : bgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WorkoutGaugePainter oldDelegate) => oldDelegate.progress != progress;
}
