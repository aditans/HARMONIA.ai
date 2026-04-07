import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/dashboard/providers/dashboard_data_provider.dart';

class MetricDetailScreen extends ConsumerStatefulWidget {
  const MetricDetailScreen({
    super.key,
    required this.title,
    required this.primaryColor,
    required this.startColor,
    required this.endColor,
    required this.topStats,
    required this.bars,
    required this.activities,
    required this.legend,
    this.minY = -1000,
    this.maxY = 1000,
  });

  final String title;
  final Color primaryColor;
  final Color startColor;
  final Color endColor;
  final List<_TopStat> topStats;
  final List<double> bars;
  final List<_ActivityItem> activities;
  final List<String> legend;
  final double minY;
  final double maxY;

  static MetricDetailScreen calories() {
    return _MetricDetailScreenState.calories();
  }

  static MetricDetailScreen heartRate() {
    return _MetricDetailScreenState.heartRate();
  }

  static MetricDetailScreen meals() {
    return _MetricDetailScreenState.meals();
  }

  @override
  ConsumerState<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends ConsumerState<MetricDetailScreen> {
  String _selectedSegment = 'Months';

  static MetricDetailScreen calories() {
    return MetricDetailScreen(
      title: 'Calories',
      primaryColor: const Color(0xFFD95B1A),
      startColor: const Color(0xFFFFB100),
      endColor: const Color(0xFFE3441A),
      legend: const ['Burned', 'Consumed'],
      topStats: const [
        _TopStat(label: 'Burned', value: '3642 kcal'),
        _TopStat(label: 'Target', value: '3900 kcal'),
        _TopStat(label: 'Consumed', value: '4729 kcal'),
      ],
      bars: const [
        -620,
        760,
        -590,
        620,
        -840,
        360,
        640,
        -500,
        680,
        510,
        -530,
        380,
        -770,
        770,
        -400,
        580,
        840,
        -620,
        560,
        -760
      ],
      activities: const [
        _ActivityItem(
            title: 'Gym workout',
            subtitle: '1:30 hrs, Biceps & Triceps',
            value: '-847 kcal'),
        _ActivityItem(
            title: 'Running', subtitle: '5.0 km', value: '-1127 kcal'),
        _ActivityItem(
            title: 'Breakfast',
            subtitle: '2 Eggs, White bread, Orange juice',
            value: '+768 kcal'),
        _ActivityItem(title: 'Walk', subtitle: '1.2 km', value: '-142 kcal'),
      ],
    );
  }

  static MetricDetailScreen heartRate() {
    return MetricDetailScreen(
      title: 'Heart Rate',
      primaryColor: const Color(0xFFF70658),
      startColor: const Color(0xFFFF7950),
      endColor: const Color(0xFFF70758),
      legend: const ['Avg', 'Peak'],
      minY: 0,
      maxY: 180,
      topStats: const [
        _TopStat(label: 'Average', value: '72 bpm'),
        _TopStat(label: 'Min', value: '48 bpm'),
        _TopStat(label: 'Max', value: '110 bpm'),
      ],
      bars: const [40, 96, 138, 88, 84, 58, 12, 141, 76, 10, 4, 24, 35, 18, 78],
      activities: const [
        _ActivityItem(
            title: 'Gym workout',
            subtitle: '1:30 hrs, Biceps & Triceps',
            value: '108 bpm'),
        _ActivityItem(title: 'Running', subtitle: '5.0 km', value: '110 bpm'),
      ],
    );
  }

  static MetricDetailScreen meals() {
    return MetricDetailScreen(
      title: 'Meals',
      primaryColor: const Color(0xFF2CC90A),
      startColor: const Color(0xFF5DDC00),
      endColor: const Color(0xFF33B809),
      legend: const ['Protein', 'Carbs', 'Fats'],
      minY: 0,
      maxY: 100,
      topStats: const [
        _TopStat(label: 'Done', value: '2 / 5'),
        _TopStat(label: 'Current', value: 'Morning Snack'),
        _TopStat(label: 'Next In', value: '02:19:06'),
      ],
      bars: const [30, 70, 20, 55, 42, 80, 65, 38, 58, 70, 45, 66],
      activities: const [
        _ActivityItem(title: 'Apple', subtitle: '95 kcal', value: '14g carb'),
        _ActivityItem(
            title: 'White Bread', subtitle: '0g fat', value: '0g protein'),
        _ActivityItem(
            title: 'Green Vegies', subtitle: '0g fat', value: '0g protein'),
        _ActivityItem(
            title: '2 Eggs', subtitle: '12g protein', value: '10g fat'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panel = isDark ? const Color(0xFF242432) : Colors.white;
    final Color page =
        isDark ? const Color(0xFF151522) : const Color(0xFFEAEAEA);
    final title = widget.title;
    final topStats = widget.topStats;
    final bars = widget.bars;
    final minY = widget.minY;
    final maxY = widget.maxY;
    final startColor = widget.startColor;
    final endColor = widget.endColor;
    final activities = widget.activities;

    final metrics = ref.watch(dailyMetricsProvider).valueOrNull;
    final isCalories = title == 'Calories';
    final isMeals = title == 'Meals';
    final calorieTopStats = isCalories
        ? [
            _TopStat(
                label: 'Burned',
                value:
                    '${metrics?.calories ?? DashboardMetricsData.defaults.calories} kcal'),
            _TopStat(
                label: 'Target',
                value:
                    '${metrics?.caloriesTarget ?? DashboardMetricsData.defaults.caloriesTarget} kcal'),
            _TopStat(
                label: 'BMI',
                value: _bmiLabel(
                  weightKg: metrics?.weightKg ?? DashboardMetricsData.defaults.weightKg,
                  heightCm: metrics?.heightCm ?? DashboardMetricsData.defaults.heightCm,
                )),
          ]
        : topStats;

    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title),
        actions: [
          if (isCalories || isMeals)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final service = ref.read(dashboardDataServiceProvider);
                if (service == null) return;
                if (isCalories) {
                  final current = metrics?.calories ?? DashboardMetricsData.defaults.calories;
                  final target = metrics?.caloriesTarget ?? DashboardMetricsData.defaults.caloriesTarget;
                  final result = await _showCaloriesEditor(
                    calories: current,
                    caloriesTarget: target,
                    weightKg: metrics?.weightKg ?? DashboardMetricsData.defaults.weightKg,
                    heightCm: metrics?.heightCm ?? DashboardMetricsData.defaults.heightCm,
                  );
                  if (result != null) {
                    await service.updateMetrics({
                      'calories': result.calories,
                      'caloriesTarget': result.target,
                      'weightKg': result.weightKg,
                      'heightCm': result.heightCm,
                    });
                  }
                } else {
                  final done = metrics?.mealsDone ?? DashboardMetricsData.defaults.mealsDone;
                  final target = metrics?.mealsTarget ?? DashboardMetricsData.defaults.mealsTarget;
                  final result = await _showMealMacroEditor(
                    mealsDone: done,
                    mealsTarget: target,
                    protein: metrics?.proteinGrams ?? DashboardMetricsData.defaults.proteinGrams,
                    carbs: metrics?.carbsGrams ?? DashboardMetricsData.defaults.carbsGrams,
                    fats: metrics?.fatsGrams ?? DashboardMetricsData.defaults.fatsGrams,
                  );
                  if (result != null) {
                    await service.updateMetrics({
                      'mealsDone': result.mealsDone,
                      'mealsTarget': result.mealsTarget,
                      'proteinGrams': result.protein,
                      'carbsGrams': result.carbs,
                      'fatsGrams': result.fats,
                    });
                  }
                }
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: panel, borderRadius: BorderRadius.circular(22)),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: calorieTopStats
                  .map(
                    (item) => SizedBox(
                      width: (MediaQuery.of(context).size.width - 64) / 3,
                      child: _statColumn(item),
                    ),
                  )
                  .toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                  colors: [startColor, endColor],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Week 7, Day 2',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const Text('Today, 23rd, Dec, 2018',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 250,
                    child: _MetricBarChart(
                      bars: bars,
                      barColor: Colors.white,
                      lineColor: Colors.white54,
                      minY: minY,
                      maxY: maxY,
                          selectedSegment: _selectedSegment,
                    ),
                  ),
                  const SizedBox(height: 10),
                      _segmentRow(),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
                color: panel, borderRadius: BorderRadius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activities',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...activities.map(_activityTile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(_TopStat stat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stat.label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(stat.value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _segmentRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            ...['Today', 'Weeks', 'Months', 'Years'].map((value) {
              final bool selected = value == _selectedSegment;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    setState(() {
                      _selectedSegment = value;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: selected
                          ? LinearGradient(colors: [widget.startColor, widget.endColor])
                          : null,
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade600,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _activityTile(_ActivityItem item) {
    final bool positive = item.value.startsWith('+');
    final Color valueColor = widget.title == 'Heart Rate'
      ? widget.primaryColor
        : positive
            ? Colors.green.shade600
        : widget.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                Text(item.subtitle,
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(item.value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
        ],
      ),
    );
  }

  Future<_MealMacroEdit?> _showMealMacroEditor({
    required int mealsDone,
    required int mealsTarget,
    required int protein,
    required int carbs,
    required int fats,
  }) async {
    final done = TextEditingController(text: mealsDone.toString());
    final target = TextEditingController(text: mealsTarget.toString());
    final p = TextEditingController(text: protein.toString());
    final c = TextEditingController(text: carbs.toString());
    final f = TextEditingController(text: fats.toString());

    final result = await showDialog<_MealMacroEdit>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Meals and Macros'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: done, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meals done')),
                TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meals target')),
                TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
                TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)')),
                TextField(controller: f, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fats (g)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final dv = int.tryParse(done.text.trim());
                final tv = int.tryParse(target.text.trim());
                final pv = int.tryParse(p.text.trim());
                final cv = int.tryParse(c.text.trim());
                final fv = int.tryParse(f.text.trim());
                if (dv == null || tv == null || pv == null || cv == null || fv == null) return;
                Navigator.of(dialogContext).pop(
                  _MealMacroEdit(
                    mealsDone: dv,
                    mealsTarget: tv <= 0 ? 1 : tv,
                    protein: pv.clamp(0, 1000),
                    carbs: cv.clamp(0, 1000),
                    fats: fv.clamp(0, 1000),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    done.dispose();
    target.dispose();
    p.dispose();
    c.dispose();
    f.dispose();
    return result;
  }

  Future<_CaloriesEdit?> _showCaloriesEditor({
    required int calories,
    required int caloriesTarget,
    required int weightKg,
    required int heightCm,
  }) async {
    final c = TextEditingController(text: calories.toString());
    final t = TextEditingController(text: caloriesTarget.toString());
    final w = TextEditingController(text: weightKg.toString());
    final h = TextEditingController(text: heightCm.toString());

    final result = await showDialog<_CaloriesEdit>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Calories & BMI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Today calories'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: t,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories target'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: w,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: h,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final cv = int.tryParse(c.text.trim());
                final tv = int.tryParse(t.text.trim());
                final wv = int.tryParse(w.text.trim());
                final hv = int.tryParse(h.text.trim());
                if (cv == null || tv == null || wv == null || hv == null) {
                  return;
                }
                Navigator.of(dialogContext).pop(_CaloriesEdit(
                  calories: cv.clamp(0, 20000),
                  target: tv <= 0 ? 1 : tv,
                  weightKg: wv.clamp(20, 300),
                  heightCm: hv.clamp(100, 250),
                ));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    c.dispose();
    t.dispose();
    w.dispose();
    h.dispose();
    return result;
  }

  String _bmiLabel({required int weightKg, required int heightCm}) {
    final hMeters = heightCm / 100;
    if (hMeters <= 0) {
      return 'N/A';
    }
    final bmi = weightKg / (hMeters * hMeters);
    return bmi.toStringAsFixed(1);
  }
}

class _MealMacroEdit {
  const _MealMacroEdit({
    required this.mealsDone,
    required this.mealsTarget,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  final int mealsDone;
  final int mealsTarget;
  final int protein;
  final int carbs;
  final int fats;
}

class _CaloriesEdit {
  const _CaloriesEdit({
    required this.calories,
    required this.target,
    required this.weightKg,
    required this.heightCm,
  });

  final int calories;
  final int target;
  final int weightKg;
  final int heightCm;
}

class _MetricBarChart extends StatelessWidget {
  const _MetricBarChart({
    required this.bars,
    required this.barColor,
    required this.lineColor,
    required this.minY,
    required this.maxY,
    required this.selectedSegment,
  });

  final List<double> bars;
  final Color barColor;
  final Color lineColor;
  final double minY;
  final double maxY;
  final String selectedSegment;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: lineColor.withValues(alpha: 0.35), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final int stride;
                switch (selectedSegment) {
                  case 'Today':
                    stride = 3;
                    break;
                  case 'Weeks':
                    stride = 4;
                    break;
                  case 'Months':
                    stride = 5;
                    break;
                  default:
                    stride = 6;
                }
                if (value.toInt() % stride != 0) {
                  return const SizedBox.shrink();
                }
                final int hour = 6 + value.toInt();
                return Text(
                    '${hour > 12 ? hour - 12 : hour} ${hour >= 12 ? 'pm' : 'am'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
        barGroups: List.generate(
          bars.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: bars[index],
                width: 8,
                borderRadius: BorderRadius.circular(4),
                color:
                    barColor.withValues(alpha: bars[index] < 0 ? 0.45 : 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopStat {
  const _TopStat({required this.label, required this.value});
  final String label;
  final String value;
}

class _ActivityItem {
  const _ActivityItem(
      {required this.title, required this.subtitle, required this.value});
  final String title;
  final String subtitle;
  final String value;
}
