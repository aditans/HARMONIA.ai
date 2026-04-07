import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:harmonia_ai/shared/widgets/camera_preview_view.dart';
import 'package:harmonia_ai/shared/widgets/permission_request_view.dart';

class ExerciseCameraShell extends StatefulWidget {
  const ExerciseCameraShell({
    super.key,
    required this.overlay,
    this.onImage,
    this.streamEnabled = false,
  });

  final Widget overlay;
  final Future<void> Function(CameraImage image, CameraDescription description)?
      onImage;
  final bool streamEnabled;

  @override
  State<ExerciseCameraShell> createState() => _ExerciseCameraShellState();
}

class _ExerciseCameraShellState extends State<ExerciseCameraShell> {
  CameraController? controller;
  String? errorMessage;
  List<CameraDescription> available = const [];
  CameraLensDirection preferredDirection = CameraLensDirection.front;
  bool _isStreaming = false;
  bool _isForwardingFrame = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant ExerciseCameraShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller == null || widget.onImage == null) {
      return;
    }

    if (widget.streamEnabled && !oldWidget.streamEnabled) {
      _startStreaming(controller!);
    } else if (!widget.streamEnabled && oldWidget.streamEnabled) {
      _stopStreaming();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      available = cameras;
      if (cameras.isEmpty) {
        setState(() {
          errorMessage = 'No camera found on this device.';
        });
        return;
      }

      final camera = _pickCamera(cameras, preferredDirection);

      await _setController(camera);
      if (!mounted) return;
      setState(() {
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Camera permission is required to run Exercise Mode.';
      });
    }
  }

  @override
  void dispose() {
    _stopStreaming();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _stopStreaming() async {
    final cameraController = controller;
    if (cameraController != null && cameraController.value.isStreamingImages) {
      await cameraController.stopImageStream();
    }
    _isStreaming = false;
  }

  CameraDescription _pickCamera(
      List<CameraDescription> cameras, CameraLensDirection direction) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => cameras.first,
    );
  }

  Future<void> _setController(CameraDescription camera) async {
    await controller?.dispose();
    final cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await cameraController.initialize();
    if (widget.streamEnabled) {
      await _startStreaming(cameraController);
    }
    if (!mounted) return;
    setState(() {
      controller = cameraController;
    });
  }

  Future<void> _startStreaming(CameraController cameraController) async {
    if (widget.onImage == null || _isStreaming) {
      return;
    }

    await cameraController.startImageStream((CameraImage image) async {
      if (_isForwardingFrame || widget.onImage == null) {
        return;
      }
      _isForwardingFrame = true;
      try {
        await widget.onImage!(image, cameraController.description);
      } finally {
        _isForwardingFrame = false;
      }
    });
    _isStreaming = true;
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = controller;
    if (errorMessage != null) {
      return PermissionRequestView(
        title: 'Camera access needed',
        message: errorMessage!,
        onRetry: _initializeCamera,
      );
    }

    if (cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isFront =
        cameraController.description.lensDirection == CameraLensDirection.front;

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreviewView(
          controller: cameraController,
          overlay: widget.overlay,
          mirror: isFront,
        ),
      ],
    );
  }
}
