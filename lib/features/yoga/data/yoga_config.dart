class PoseAngleTarget {
  const PoseAngleTarget({required this.key, required this.ideal});

  final String key;
  final double ideal;
}

class YogaPoseConfig {
  const YogaPoseConfig({
    required this.label,
    required this.angleTargets,
    required this.feedbackHints,
    this.referenceVector = const [],
  });

  final String label;
  final List<PoseAngleTarget> angleTargets;
  final List<String> feedbackHints;
  final List<double> referenceVector;

  static const List<YogaPoseConfig> all = [
    YogaPoseConfig(
        label: 'Mountain',
        angleTargets: [PoseAngleTarget(key: 'spine', ideal: 0)],
        feedbackHints: ['Stand tall', 'Relax shoulders']),
    YogaPoseConfig(label: 'Tree', angleTargets: [
      PoseAngleTarget(key: 'standing_knee', ideal: 175),
      PoseAngleTarget(key: 'bent_knee', ideal: 80)
    ], feedbackHints: [
      'Find your center',
      'Raise your foot higher'
    ]),
    YogaPoseConfig(label: 'Warrior I', angleTargets: [
      PoseAngleTarget(key: 'front_knee', ideal: 90),
      PoseAngleTarget(key: 'back_leg', ideal: 170)
    ], feedbackHints: [
      'Square your hips',
      'Reach overhead'
    ]),
    YogaPoseConfig(label: 'Warrior II', angleTargets: [
      PoseAngleTarget(key: 'front_knee', ideal: 90),
      PoseAngleTarget(key: 'arms', ideal: 90)
    ], feedbackHints: [
      'Sink deeper',
      'Keep arms level'
    ]),
    YogaPoseConfig(label: 'Downward Dog', angleTargets: [
      PoseAngleTarget(key: 'hip_angle', ideal: 60),
      PoseAngleTarget(key: 'arm_angle', ideal: 175)
    ], feedbackHints: [
      'Push hips back',
      'Straighten arms'
    ]),
    YogaPoseConfig(label: 'Child\'s Pose', angleTargets: [
      PoseAngleTarget(key: 'hip_fold', ideal: 50),
      PoseAngleTarget(key: 'knee', ideal: 45)
    ], feedbackHints: [
      'Sit hips back',
      'Reach forward'
    ]),
    YogaPoseConfig(label: 'Cobra', angleTargets: [
      PoseAngleTarget(key: 'elbow', ideal: 135),
      PoseAngleTarget(key: 'backbend', ideal: 40)
    ], feedbackHints: [
      'Open chest',
      'Drop shoulders'
    ]),
    YogaPoseConfig(label: 'Triangle', angleTargets: [
      PoseAngleTarget(key: 'side_bend', ideal: 170),
      PoseAngleTarget(key: 'top_arm', ideal: 175)
    ], feedbackHints: [
      'Open chest',
      'Reach top arm up'
    ]),
    YogaPoseConfig(
        label: 'Plank',
        angleTargets: [PoseAngleTarget(key: 'body_line', ideal: 175)],
        feedbackHints: ['Keep body straight']),
    YogaPoseConfig(label: 'Chair', angleTargets: [
      PoseAngleTarget(key: 'knee', ideal: 100),
      PoseAngleTarget(key: 'arm_raise', ideal: 170)
    ], feedbackHints: [
      'Sit deeper',
      'Reach arms up'
    ]),
    YogaPoseConfig(label: 'Bridge', angleTargets: [
      PoseAngleTarget(key: 'knee', ideal: 95),
      PoseAngleTarget(key: 'hip_line', ideal: 160)
    ], feedbackHints: [
      'Lift hips higher'
    ]),
    YogaPoseConfig(label: 'Seated Forward Bend', angleTargets: [
      PoseAngleTarget(key: 'hip_fold', ideal: 80),
      PoseAngleTarget(key: 'knee', ideal: 170)
    ], feedbackHints: [
      'Hinge at hips'
    ]),
    YogaPoseConfig(label: 'Pigeon', angleTargets: [
      PoseAngleTarget(key: 'front_knee', ideal: 85),
      PoseAngleTarget(key: 'back_leg', ideal: 170)
    ], feedbackHints: [
      'Square your hips'
    ]),
    YogaPoseConfig(label: 'Camel', angleTargets: [
      PoseAngleTarget(key: 'backbend', ideal: 55),
      PoseAngleTarget(key: 'knee', ideal: 90)
    ], feedbackHints: [
      'Push hips forward'
    ]),
    YogaPoseConfig(label: 'Warrior III', angleTargets: [
      PoseAngleTarget(key: 'standing_leg', ideal: 170),
      PoseAngleTarget(key: 'torso_horizontal', ideal: 5)
    ], feedbackHints: [
      'Lift back leg',
      'Keep spine parallel'
    ]),
  ];
}
