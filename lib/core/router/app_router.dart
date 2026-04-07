import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:harmonia_ai/features/assistant/screens/assistant_screen.dart';
import 'package:harmonia_ai/features/auth/screens/auth_gate.dart';
import 'package:harmonia_ai/features/dashboard/screens/dashboard_screen.dart';
import 'package:harmonia_ai/features/dashboard/screens/metric_detail_screen.dart';
import 'package:harmonia_ai/features/dashboard/screens/workout_sessions_screen.dart';
import 'package:harmonia_ai/features/exercise/screens/exercise_screen_v2.dart';
import 'package:harmonia_ai/features/focus/screens/focus_screen_simple.dart';
import 'package:harmonia_ai/features/onboarding/screens/onboarding_screen.dart';
import 'package:harmonia_ai/features/settings/screens/settings_screen.dart';
import 'package:harmonia_ai/features/yoga/screens/yoga_screen_simple.dart';
import 'package:harmonia_ai/shared/widgets/app_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthGate(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercise',
                builder: (context, state) => const ExerciseScreenV2(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/yoga',
                builder: (context, state) => const YogaScreenSimple(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/focus',
                builder: (context, state) => const FocusScreenSimple(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/assistant',
                builder: (context, state) => const AssistantScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/stats/calories',
        builder: (context, state) => MetricDetailScreen.calories(),
      ),
      GoRoute(
        path: '/stats/heart-rate',
        builder: (context, state) => MetricDetailScreen.heartRate(),
      ),
      GoRoute(
        path: '/stats/meals',
        builder: (context, state) => MetricDetailScreen.meals(),
      ),
      GoRoute(
        path: '/stats/workout',
        builder: (context, state) => const WorkoutSessionsScreen(),
      ),
    ],
    redirect: (context, state) {
      if (state.uri.path == '/') {
        return '/onboarding';
      }
      return null;
    },
  );
});
