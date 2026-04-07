import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/dashboard/providers/dashboard_data_provider.dart';

class WorkoutSessionsScreen extends ConsumerWidget {
  const WorkoutSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(activityLogsProvider).valueOrNull ?? const [];
    final workoutLogs = logs
        .where((log) => log.activity == 'exercise' || log.activity == 'yoga')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Sessions'),
      ),
      body: workoutLogs.isEmpty
          ? const Center(child: Text('No workout sessions recorded yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: workoutLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = workoutLogs[index];
                final minutes = (item.durationSeconds / 60).toStringAsFixed(1);
                final title = item.label.isEmpty ? item.activity : item.label;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(item.activity == 'yoga' ? 'Y' : 'E'),
                    ),
                    title: Text(title),
                    subtitle: Text(
                      '${item.createdAt.toLocal()}\n$minutes min • ${item.reps} reps • ${item.status}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
