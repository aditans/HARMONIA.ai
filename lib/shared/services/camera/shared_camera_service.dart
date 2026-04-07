import 'dart:async';
import 'package:camera/camera.dart' as camera_pkg;
import 'package:flutter/foundation.dart';

typedef ImageFrameCallback = Future<void> Function(
  camera_pkg.CameraImage image,
  camera_pkg.CameraDescription description,
);

/// Shared camera service that manages a single camera instance
/// and allows multiple listeners to process frames from different modes
class SharedCameraService extends ChangeNotifier {
  static final SharedCameraService _instance = SharedCameraService._internal();

  factory SharedCameraService() {
    return _instance;
  }

  SharedCameraService._internal();

  camera_pkg.CameraController? _controller;
  String? _errorMessage;
  List<camera_pkg.CameraDescription> _availableCameras = [];
  bool _isStreamingImages = false;
  bool _isInitialized = false;

  // Callbacks for different analysis modes
  ImageFrameCallback? _exerciseCallback;
  ImageFrameCallback? _yogaCallback;
  ImageFrameCallback? _focusCallback;

  bool get isInitialized => _isInitialized;
  bool get isStreamingImages => _isStreamingImages;
  camera_pkg.CameraController? get controller => _controller;
  String? get errorMessage => _errorMessage;
  List<camera_pkg.CameraDescription> get cameraList => _availableCameras;

  /// Initialize the camera service (singleton - safe to call multiple times)
  Future<void> initialize({camera_pkg.CameraLensDirection preferredDirection = camera_pkg.CameraLensDirection.front}) async {
    if (_isInitialized && _controller != null) {
      return;
    }

    try {
      _availableCameras = await camera_pkg.availableCameras();
      if (_availableCameras.isEmpty) {
        _errorMessage = 'No camera found on this device.';
        notifyListeners();
        return;
      }

      final camera = _pickCamera(_availableCameras, preferredDirection);
      await _setController(camera);
      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Camera permission is required.';
      _isInitialized = false;
      notifyListeners();
    }
  }

  camera_pkg.CameraDescription _pickCamera(List<camera_pkg.CameraDescription> cameras, camera_pkg.CameraLensDirection direction) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == direction,
      orElse: () => cameras.first,
    );
  }

  Future<void> _setController(camera_pkg.CameraDescription camera) async {
    await _controller?.dispose();
    final cameraController = camera_pkg.CameraController(
      camera,
      camera_pkg.ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: camera_pkg.ImageFormatGroup.yuv420,
    );
    await cameraController.initialize();
    _controller = cameraController;
  }

  /// Register exercise frame callback
  void setExerciseCallback(ImageFrameCallback? callback) {
    _exerciseCallback = callback;
    _updateStreaming();
  }

  /// Register yoga frame callback
  void setYogaCallback(ImageFrameCallback? callback) {
    _yogaCallback = callback;
    _updateStreaming();
  }

  /// Register focus frame callback
  void setFocusCallback(ImageFrameCallback? callback) {
    _focusCallback = callback;
    _updateStreaming();
  }

  /// Start or stop image streaming based on registered callbacks
  Future<void> _updateStreaming() async {
    final hasActiveCallbacks = _exerciseCallback != null || _yogaCallback != null || _focusCallback != null;

    if (hasActiveCallbacks && !_isStreamingImages && _controller != null) {
      await _startStreaming();
    } else if (!hasActiveCallbacks && _isStreamingImages && _controller != null) {
      await _stopStreaming();
    }
  }

  Future<void> _startStreaming() async {
    if (_isStreamingImages || _controller == null) {
      return;
    }

    try {
      await _controller!.startImageStream((image) {
        _processFrame(image);
      });
      _isStreamingImages = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to start image stream: $e');
    }
  }

  void _processFrame(camera_pkg.CameraImage image) {
    final description = _controller?.description;
    if (description == null) return;

    // Send frame to active callbacks
    if (_exerciseCallback != null) {
      _exerciseCallback!(image, description).catchError(
        (e) => debugPrint('Exercise callback error: $e'),
      );
    }

    if (_yogaCallback != null) {
      _yogaCallback!(image, description).catchError(
        (e) => debugPrint('Yoga callback error: $e'),
      );
    }

    if (_focusCallback != null) {
      _focusCallback!(image, description).catchError(
        (e) => debugPrint('Focus callback error: $e'),
      );
    }
  }

  Future<void> _stopStreaming() async {
    if (!_isStreamingImages || _controller == null) {
      return;
    }

    try {
      await _controller!.stopImageStream();
      _isStreamingImages = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to stop image stream: $e');
    }
  }

  /// Flip camera
  Future<void> flipCamera() async {
    if (_availableCameras.length < 2 || _controller == null) {
      return;
    }

    final currentLensDirection = _controller!.description.lensDirection;
    final newDirection = currentLensDirection == camera_pkg.CameraLensDirection.front
        ? camera_pkg.CameraLensDirection.back
        : camera_pkg.CameraLensDirection.front;

    final newCamera = _pickCamera(_availableCameras, newDirection);
    await _setController(newCamera);
    notifyListeners();
  }

  /// Dispose the camera service
  Future<void> dispose() async {
    await _stopStreaming();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _exerciseCallback = null;
    _yogaCallback = null;
    _focusCallback = null;
    super.dispose();
  }
}
