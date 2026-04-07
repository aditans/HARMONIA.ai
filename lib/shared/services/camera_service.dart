import 'package:camera/camera.dart';

class CameraService {
  static Future<List<CameraDescription>> availableCamerasSafe() async {
    try {
      return await availableCameras();
    } catch (_) {
      return <CameraDescription>[];
    }
  }
}
