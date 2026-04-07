import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:harmonia_ai/shared/providers/activity_session_provider.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(BuildContext context, WidgetRef ref, int index) {
    final lock = ref.read(activitySessionProvider);
    if (lock.activeActivity == ActivityType.focus && index != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete Focus session before switching tabs.')),
      );
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _goBranch(context, ref, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), label: 'Exercise'),
          NavigationDestination(icon: Icon(Icons.self_improvement_outlined), label: 'Yoga'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Focus'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'AI'),
        ],
      ),
    );
  }
}
