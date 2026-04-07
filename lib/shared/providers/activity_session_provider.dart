import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityType {
  exercise,
  yoga,
  focus,
}

extension ActivityTypeLabel on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.exercise:
        return 'Exercise';
      case ActivityType.yoga:
        return 'Yoga';
      case ActivityType.focus:
        return 'Focus';
    }
  }
}

class ActivitySessionState {
  const ActivitySessionState({this.activeActivity});

  final ActivityType? activeActivity;

  bool get hasActiveActivity => activeActivity != null;

  String? get activeLabel => activeActivity?.label;

  ActivitySessionState copyWith({ActivityType? activeActivity}) {
    return ActivitySessionState(
      activeActivity: activeActivity,
    );
  }
}

class ActivitySessionNotifier extends Notifier<ActivitySessionState> {
  @override
  ActivitySessionState build() {
    return const ActivitySessionState();
  }

  bool tryStart(ActivityType activity) {
    final current = state.activeActivity;
    if (current != null && current != activity) {
      return false;
    }

    state = ActivitySessionState(activeActivity: activity);
    return true;
  }

  void complete(ActivityType activity) {
    state = const ActivitySessionState();
  }

  void clear() {
    state = const ActivitySessionState();
  }
}

final activitySessionProvider =
    NotifierProvider<ActivitySessionNotifier, ActivitySessionState>(
  ActivitySessionNotifier.new,
);
