import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:harmonia_ai/features/focus/services/pomodoro_timer.dart';

class FocusState {
  const FocusState({
    required this.focusPercent,
    required this.distractionEvents,
    required this.pomodorosCompleted,
    required this.isRunning,
    required this.totalSeconds,
    required this.focusedSeconds,
    required this.statusLabel,
    required this.feedbackBanner,
    required this.mode,
    required this.modeRemainingSeconds,
    required this.modeTotalSeconds,
    required this.longestFocusStreakSeconds,
    required this.currentFocusStreakSeconds,
    required this.distractionTimeline,
    required this.notifications,
  });

  final double focusPercent;
  final int distractionEvents;
  final int pomodorosCompleted;
  final bool isRunning;
  final int totalSeconds;
  final int focusedSeconds;
  final String statusLabel;
  final String feedbackBanner;
  final PomodoroState mode;
  final int modeRemainingSeconds;
  final int modeTotalSeconds;
  final int longestFocusStreakSeconds;
  final int currentFocusStreakSeconds;
  final List<int> distractionTimeline;
  final List<String> notifications;

  FocusState copyWith({
    double? focusPercent,
    int? distractionEvents,
    int? pomodorosCompleted,
    bool? isRunning,
    int? totalSeconds,
    int? focusedSeconds,
    String? statusLabel,
    String? feedbackBanner,
    PomodoroState? mode,
    int? modeRemainingSeconds,
    int? modeTotalSeconds,
    int? longestFocusStreakSeconds,
    int? currentFocusStreakSeconds,
    List<int>? distractionTimeline,
    List<String>? notifications,
  }) {
    return FocusState(
      focusPercent: focusPercent ?? this.focusPercent,
      distractionEvents: distractionEvents ?? this.distractionEvents,
      pomodorosCompleted: pomodorosCompleted ?? this.pomodorosCompleted,
      isRunning: isRunning ?? this.isRunning,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      focusedSeconds: focusedSeconds ?? this.focusedSeconds,
      statusLabel: statusLabel ?? this.statusLabel,
      feedbackBanner: feedbackBanner ?? this.feedbackBanner,
      mode: mode ?? this.mode,
      modeRemainingSeconds: modeRemainingSeconds ?? this.modeRemainingSeconds,
      modeTotalSeconds: modeTotalSeconds ?? this.modeTotalSeconds,
      longestFocusStreakSeconds:
          longestFocusStreakSeconds ?? this.longestFocusStreakSeconds,
      currentFocusStreakSeconds:
          currentFocusStreakSeconds ?? this.currentFocusStreakSeconds,
      distractionTimeline: distractionTimeline ?? this.distractionTimeline,
      notifications: notifications ?? this.notifications,
    );
  }
}

class FocusController extends AsyncNotifier<FocusState> {
  final PomodoroTimerMachine _pomodoro = PomodoroTimerMachine();
  bool _lastFocusState = true;

  @override
  Future<FocusState> build() async {
    return const FocusState(
      focusPercent: 0,
      distractionEvents: 0,
      pomodorosCompleted: 0,
      isRunning: false,
      totalSeconds: 0,
      focusedSeconds: 0,
      statusLabel: 'FOCUSED 🟢',
      feedbackBanner: '',
      mode: PomodoroState.work,
      modeRemainingSeconds: PomodoroTimerMachine.defaultWorkSeconds,
      modeTotalSeconds: PomodoroTimerMachine.defaultWorkSeconds,
      longestFocusStreakSeconds: 0,
      currentFocusStreakSeconds: 0,
      distractionTimeline: [],
      notifications: [],
    );
  }

  Future<void> startSession({int? workMinutes}) async {
    if (workMinutes != null) {
      _pomodoro.setWorkMinutes(workMinutes);
      _pomodoro.reset();
    }
    _pomodoro.start();
    final snap = _pomodoro.snapshot;
    state = AsyncData((await future).copyWith(
        isRunning: true,
        mode: snap.state,
      modeRemainingSeconds: snap.remainingSeconds,
      modeTotalSeconds: snap.modeTotalSeconds));
  }

  Future<void> pauseSession() async {
    _pomodoro.pause();
    state = AsyncData((await future).copyWith(isRunning: false));
  }

  Future<void> completeSession() async {
    _pomodoro.pause();
    state = AsyncData((await future).copyWith(isRunning: false));
  }

  Future<void> updateFeedback(String feedback) async {
    final FocusState current = await future;
    state = AsyncData(current.copyWith(feedbackBanner: feedback));
  }

  Future<void> tick({required bool focused, String feedback = ''}) async {
    final FocusState current = await future;
    final int totalSeconds = current.totalSeconds + 1;
    final int focusedSeconds =
        focused ? current.focusedSeconds + 1 : current.focusedSeconds;
    final double focusPercent =
        totalSeconds == 0 ? 0 : (focusedSeconds / totalSeconds) * 100;
    int distractionEvents = current.distractionEvents;
    if (_lastFocusState && !focused) {
      distractionEvents += 1;
    }
    _lastFocusState = focused;

    final int currentStreak =
        focused ? current.currentFocusStreakSeconds + 1 : 0;
    final int longestStreak = currentStreak > current.longestFocusStreakSeconds
        ? currentStreak
        : current.longestFocusStreakSeconds;

    final pomodoroTick = _pomodoro.tick();
    final mode = pomodoroTick.snapshot.state;
    final modeRemaining = pomodoroTick.snapshot.remainingSeconds;
    final modeTotal = pomodoroTick.snapshot.modeTotalSeconds;
    final List<String> notifications = pomodoroTick.notification.isEmpty
        ? current.notifications
        : [...current.notifications, pomodoroTick.notification];

    final List<int> timeline = [
      ...current.distractionTimeline,
      focused ? 1 : 0
    ];
    if (timeline.length > 600) {
      timeline.removeAt(0);
    }

    state = AsyncData(
      current.copyWith(
        totalSeconds: totalSeconds,
        focusedSeconds: focusedSeconds,
        focusPercent: focusPercent,
        distractionEvents: distractionEvents,
        statusLabel: focused ? 'FOCUSED 🟢' : 'DISTRACTED 🔴',
        feedbackBanner: feedback,
        mode: mode,
        modeRemainingSeconds: modeRemaining,
        modeTotalSeconds: modeTotal,
        pomodorosCompleted: pomodoroTick.snapshot.completedWorkSessions,
        currentFocusStreakSeconds: currentStreak,
        longestFocusStreakSeconds: longestStreak,
        distractionTimeline: timeline,
        notifications: notifications,
      ),
    );
  }
}

final focusControllerProvider =
    AsyncNotifierProvider<FocusController, FocusState>(FocusController.new);
