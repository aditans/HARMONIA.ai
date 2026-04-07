import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';

class MlKitPoseService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  Future<List<PoseLandmarkData>> detectLandmarks(
    CameraImage image,
    CameraDescription description,
  ) async {
    final InputImage? inputImage = _toInputImage(image, description);
    if (inputImage == null) {
      return const [];
    }

    final List<Pose> poses = await _poseDetector.processImage(inputImage);
    if (poses.isEmpty) {
      return const [];
    }

    final Pose pose = poses.first;
    final List<PoseLandmarkData> points = [];
    final Map<PoseLandmarkType, int> mapping = _landmarkTypeToIndex;

    for (final entry in mapping.entries) {
      final PoseLandmark? landmark = pose.landmarks[entry.key];
      if (landmark == null) {
        continue;
      }

      points.add(
        PoseLandmarkData(
          index: entry.value,
          x: landmark.x / image.width,
          y: landmark.y / image.height,
          z: landmark.z,
          likelihood: landmark.likelihood,
        ),
      );
    }

    return points;
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription description,
  ) {
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    if (image.planes.isEmpty) {
      return null;
    }

    final Uint8List bytes = _convertYuv420ToNv21(image);

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    int offset = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final int chromaHeight = height ~/ 2;
    final int chromaWidth = width ~/ 2;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < chromaHeight; row++) {
      for (int col = 0; col < chromaWidth; col++) {
        final int vIndex = row * vPlane.bytesPerRow + col * vPixelStride;
        final int uIndex = row * uPlane.bytesPerRow + col * uPixelStride;
        nv21[offset++] = vPlane.bytes[vIndex];
        nv21[offset++] = uPlane.bytes[uIndex];
      }
    }

    return nv21;
  }

  Future<void> dispose() async {
    await _poseDetector.close();
  }

  static const Map<PoseLandmarkType, int> _landmarkTypeToIndex = {
    PoseLandmarkType.nose: 0,
    PoseLandmarkType.leftEyeInner: 1,
    PoseLandmarkType.leftEye: 2,
    PoseLandmarkType.leftEyeOuter: 3,
    PoseLandmarkType.rightEyeInner: 4,
    PoseLandmarkType.rightEye: 5,
    PoseLandmarkType.rightEyeOuter: 6,
    PoseLandmarkType.leftEar: 7,
    PoseLandmarkType.rightEar: 8,
    PoseLandmarkType.leftMouth: 9,
    PoseLandmarkType.rightMouth: 10,
    PoseLandmarkType.leftShoulder: 11,
    PoseLandmarkType.rightShoulder: 12,
    PoseLandmarkType.leftElbow: 13,
    PoseLandmarkType.rightElbow: 14,
    PoseLandmarkType.leftWrist: 15,
    PoseLandmarkType.rightWrist: 16,
    PoseLandmarkType.leftPinky: 17,
    PoseLandmarkType.rightPinky: 18,
    PoseLandmarkType.leftIndex: 19,
    PoseLandmarkType.rightIndex: 20,
    PoseLandmarkType.leftThumb: 21,
    PoseLandmarkType.rightThumb: 22,
    PoseLandmarkType.leftHip: 23,
    PoseLandmarkType.rightHip: 24,
    PoseLandmarkType.leftKnee: 25,
    PoseLandmarkType.rightKnee: 26,
    PoseLandmarkType.leftAnkle: 27,
    PoseLandmarkType.rightAnkle: 28,
    PoseLandmarkType.leftHeel: 29,
    PoseLandmarkType.rightHeel: 30,
    PoseLandmarkType.leftFootIndex: 31,
    PoseLandmarkType.rightFootIndex: 32,
  };
}
