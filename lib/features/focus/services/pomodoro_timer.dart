enum PomodoroState { work, shortBreak, longBreak }

class PomodoroSnapshot {
  const PomodoroSnapshot({
    required this.state,
    required this.remainingSeconds,
    required this.modeTotalSeconds,
    required this.completedWorkSessions,
    required this.isRunning,
  });

  final PomodoroState state;
  final int remainingSeconds;
  final int modeTotalSeconds;
  final int completedWorkSessions;
  final bool isRunning;
}

class PomodoroTimerMachine {
  static const int defaultWorkSeconds = 25 * 60;
  static const int shortBreakSeconds = 5 * 60;
  static const int longBreakSeconds = 15 * 60;

  int _workSeconds = defaultWorkSeconds;
  PomodoroState _state = PomodoroState.work;
  int _remaining = defaultWorkSeconds;
  int _completedWorkSessions = 0;
  bool _running = false;

  PomodoroSnapshot get snapshot => PomodoroSnapshot(
        state: _state,
        remainingSeconds: _remaining,
        modeTotalSeconds: _modeDurationSeconds(_state),
        completedWorkSessions: _completedWorkSessions,
        isRunning: _running,
      );

  int _modeDurationSeconds(PomodoroState mode) {
    switch (mode) {
      case PomodoroState.work:
        return _workSeconds;
      case PomodoroState.shortBreak:
        return shortBreakSeconds;
      case PomodoroState.longBreak:
        return longBreakSeconds;
    }
  }

  void start() {
    _running = true;
  }

  void setWorkMinutes(int minutes) {
    final safeSeconds = (minutes <= 0 ? 1 : minutes) * 60;
    _workSeconds = safeSeconds;
    if (_state == PomodoroState.work && !_running) {
      _remaining = safeSeconds;
    }
  }

  void pause() {
    _running = false;
  }

  void reset() {
    _state = PomodoroState.work;
    _remaining = _workSeconds;
    _running = false;
  }

  ({PomodoroSnapshot snapshot, String notification}) tick() {
    if (!_running) {
      return (snapshot: snapshot, notification: '');
    }
    _remaining -= 1;
    if (_remaining > 0) {
      return (snapshot: snapshot, notification: '');
    }

    String notification = '';
    if (_state == PomodoroState.work) {
      _completedWorkSessions += 1;
      if (_completedWorkSessions % 4 == 0) {
        _state = PomodoroState.longBreak;
        _remaining = longBreakSeconds;
      } else {
        _state = PomodoroState.shortBreak;
        _remaining = shortBreakSeconds;
      }
      notification = '🍅 Pomodoro complete! Time for a break.';
    } else {
      _state = PomodoroState.work;
      _remaining = _workSeconds;
      notification = 'Break over - back to focus! 💪';
    }

    return (snapshot: snapshot, notification: notification);
  }
}
