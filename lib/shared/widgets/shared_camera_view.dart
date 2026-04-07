import 'package:flutter/material.dart';
import 'package:harmonia_ai/shared/services/camera/shared_camera_service.dart';
import 'package:harmonia_ai/shared/widgets/camera_preview_view.dart';
import 'package:harmonia_ai/shared/widgets/permission_request_view.dart';

class SharedCameraView extends StatefulWidget {
  const SharedCameraView({
    super.key,
    required this.cameraService,
    required this.overlay,
    this.onCameraReady,
  });

  final SharedCameraService cameraService;
  final Widget overlay;
  final VoidCallback? onCameraReady;

  @override
  State<SharedCameraView> createState() => _SharedCameraViewState();
}

class _SharedCameraViewState extends State<SharedCameraView> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await widget.cameraService.initialize();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
      widget.onCameraReady?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = widget.cameraService;
    final controller = cameraService.controller;

    // Show error state
    if (cameraService.errorMessage != null) {
      return PermissionRequestView(
        title: 'Camera access needed',
        message: cameraService.errorMessage!,
        onRetry: _initializeCamera,
      );
    }

    // Show loading
    if (_isInitializing || controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1 / controller.value.aspectRatio,
          child: CameraPreviewView(controller: controller),
        ),
        widget.overlay,
      ],
    );
  }
}
