import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harmonia_ai/shared/services/camera/shared_camera_service.dart';

final sharedCameraServiceProvider = ChangeNotifierProvider<SharedCameraService>((ref) {
  final cameraService = SharedCameraService();
  ref.onDispose(() {
    // Don't actually dispose the singleton, just clear the callbacks
    cameraService.setExerciseCallback(null);
    cameraService.setYogaCallback(null);
    cameraService.setFocusCallback(null);
  });
  return cameraService;
});
