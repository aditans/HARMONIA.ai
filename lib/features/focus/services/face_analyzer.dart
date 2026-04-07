import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FocusSignal {
  const FocusSignal({
    required this.isFocused,
    required this.primaryFeedback,
    required this.faceDetected,
    required this.eyesOpen,
    required this.pitch,
    required this.yaw,
    required this.roll,
  });

  final bool isFocused;
  final String primaryFeedback;
  final bool faceDetected;
  final bool eyesOpen;
  final double pitch;
  final double yaw;
  final double roll;
}

class FaceAnalyzer {
  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  int _consecutiveDistractedSeconds = 0;

  FocusSignal evaluateFaceSamples(List<Face> faces) {
    if (faces.isEmpty) {
      _consecutiveDistractedSeconds += 1;
      return FocusSignal(
        isFocused: false,
        primaryFeedback: _consecutiveDistractedSeconds >= 3
            ? 'No face detected - are you still there?'
            : '',
        faceDetected: false,
        eyesOpen: false,
        pitch: 0,
        yaw: 0,
        roll: 0,
      );
    }

    final face = faces.first;
    final pitch = face.headEulerAngleX ?? 0;
    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    final leftEye = face.leftEyeOpenProbability ?? 0;
    final rightEye = face.rightEyeOpenProbability ?? 0;

    final bool eyesOpen = leftEye > 0.7 && rightEye > 0.7;
    final bool pitchOk = pitch.abs() < 20;
    final bool yawOk = yaw.abs() < 25;
    final bool rollOk = roll.abs() < 30;
    final bool focused = eyesOpen && pitchOk && yawOk && rollOk;

    if (focused) {
      _consecutiveDistractedSeconds = 0;
      return FocusSignal(
        isFocused: true,
        primaryFeedback: 'Welcome back! 👋',
        faceDetected: true,
        eyesOpen: true,
        pitch: pitch,
        yaw: yaw,
        roll: roll,
      );
    }

    _consecutiveDistractedSeconds += 1;
    final bool showFeedback = _consecutiveDistractedSeconds >= 3;
    String feedback = '';
    if (showFeedback) {
      if (!eyesOpen) {
        feedback = 'Eyes closed - stay awake!';
      } else if (yaw.abs() >= 25) {
        feedback = 'Looking away - stay focused!';
      } else if (pitch > 20) {
        feedback = 'Are you reading from a different screen?';
      } else if (pitch < -20) {
        feedback = 'Look at your screen';
      } else if (roll.abs() >= 30) {
        feedback = 'Tilt your head straight';
      }
    }

    return FocusSignal(
      isFocused: false,
      primaryFeedback: feedback,
      faceDetected: true,
      eyesOpen: eyesOpen,
      pitch: pitch,
      yaw: yaw,
      roll: roll,
    );
  }

  Future<void> dispose() async {
    await faceDetector.close();
  }
}
