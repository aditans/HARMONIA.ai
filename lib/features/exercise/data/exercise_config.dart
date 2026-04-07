enum CameraPreference { side, front }

enum ExerciseKind {
  squat,
  pushUp,
  bicepCurl,
  shoulderPress,
  lunge,
  deadlift,
  lateralRaise,
  pullUp,
  plank,
  jumpingJack,
}

class ExerciseConfig {
  const ExerciseConfig(
      {required this.kind,
      required this.label,
      required this.cameraPreference});

  final ExerciseKind kind;
  final String label;
  final CameraPreference cameraPreference;

  static const List<ExerciseConfig> all = [
    ExerciseConfig(
        kind: ExerciseKind.squat,
        label: 'Squat',
        cameraPreference: CameraPreference.side),
    ExerciseConfig(
        kind: ExerciseKind.pushUp,
        label: 'Push-Up',
        cameraPreference: CameraPreference.side),
    ExerciseConfig(
        kind: ExerciseKind.bicepCurl,
        label: 'Bicep Curl',
        cameraPreference: CameraPreference.front),
    ExerciseConfig(
        kind: ExerciseKind.shoulderPress,
        label: 'Shoulder Press',
        cameraPreference: CameraPreference.front),
    ExerciseConfig(
        kind: ExerciseKind.lunge,
        label: 'Lunge',
        cameraPreference: CameraPreference.side),
    ExerciseConfig(
        kind: ExerciseKind.deadlift,
        label: 'Deadlift',
        cameraPreference: CameraPreference.side),
    ExerciseConfig(
        kind: ExerciseKind.lateralRaise,
        label: 'Lateral Raise',
        cameraPreference: CameraPreference.front),
    ExerciseConfig(
        kind: ExerciseKind.pullUp,
        label: 'Pull-Up',
        cameraPreference: CameraPreference.front),
    ExerciseConfig(
        kind: ExerciseKind.plank,
        label: 'Plank',
        cameraPreference: CameraPreference.side),
    ExerciseConfig(
        kind: ExerciseKind.jumpingJack,
        label: 'Jumping Jack',
        cameraPreference: CameraPreference.front),
  ];
}
