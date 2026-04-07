import 'dart:async';
import 'package:camera/camera.dart' as camera_pkg;
import 'package:flutter/foundation.dart';

/// Simpler camera service - camera starts immediately on init
/// No lazy loading, just straightforward frame processing
class SimpleCameraService extends ChangeNotifier {
  static final SimpleCameraService _instance = SimpleCameraService._internal();

  factory SimpleCameraService() {
    return _instance;
  }

  SimpleCameraService._internal();

  camera_pkg.CameraController? _controller;
  String? _errorMessage;
  bool _isInitialized = false;
  bool _isStreaming = false;

  // Single callback for frame processing  
  Function(camera_pkg.CameraImage)? _frameCallback;

  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  camera_pkg.CameraController? get controller => _controller;
  String? get errorMessage => _errorMessage;

  /// Initialize camera and start streaming immediately
  Future<void> initialize() async {
    if (_isInitialized && _controller != null) {
      debugPrint('[SimpleCamera] Already initialized, skipping');;
      return;
    }

    try {
      final cameras = await camera_pkg.availableCameras();
      if (cameras.isEmpty) {
        _errorMessage = 'No camera found';
        notifyListeners();
        return;
      }

      // Get front camera
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == camera_pkg.CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = camera_pkg.CameraController(
        frontCamera,
        camera_pkg.ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: camera_pkg.ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _errorMessage = null;

      debugPrint('[SimpleCamera] ✓ Camera initialized successfully');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Camera error: $e';
      _isInitialized = false;
      debugPrint('[SimpleCamera] ✗ Init error: $e');
      notifyListeners();
    }
  }

  /// Set frame callback and start camera stream
  Future<void> startFrameStream(Function(camera_pkg.CameraImage) callback) async {
    if (!_isInitialized || _controller == null) {
      debugPrint('[SimpleCamera] ✗ Cannot start stream - camera not initialized');
      return;
    }

    if (_isStreaming) {
      debugPrint('[SimpleCamera] Stream already running');
      return;
    }

    _frameCallback = callback;

    try {
      await _controller!.startImageStream((cameraImage) {
        _frameCallback?.call(cameraImage);
      });
      _isStreaming = true;
      debugPrint('[SimpleCamera] ✓ Image stream started');
      notifyListeners();
    } catch (e) {
      debugPrint('[SimpleCamera] ✗ Stream start error: $e');
    }
  }

  /// Stop camera stream
  Future<void> stopFrameStream() async {
    if (!_isStreaming || _controller == null) return;

    try {
      await _controller!.stopImageStream();
      _isStreaming = false;
      _frameCallback = null;
      debugPrint('[SimpleCamera] ✓ Image stream stopped');
      notifyListeners();
    } catch (e) {
      debugPrint('[SimpleCamera] ✗ Stream stop error: $e');
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await stopFrameStream();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    super.dispose();
  }
}
