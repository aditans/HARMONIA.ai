import 'package:flutter/material.dart';

import 'package:harmonia_ai/shared/models/pose_landmark_data.dart';

class SkeletonPainter extends CustomPainter {
  const SkeletonPainter(
      {required this.landmarks,
      required this.angleLabels,
      required this.sizeFactor});

  final List<PoseLandmarkData> landmarks;
  final Map<int, String> angleLabels;
  final Size sizeFactor;

  static const List<({int a, int b})> _connections = [
    (a: 11, b: 12),
    (a: 11, b: 13),
    (a: 13, b: 15),
    (a: 12, b: 14),
    (a: 14, b: 16),
    (a: 11, b: 23),
    (a: 12, b: 24),
    (a: 23, b: 24),
    (a: 23, b: 25),
    (a: 25, b: 27),
    (a: 27, b: 29),
    (a: 27, b: 31),
    (a: 24, b: 26),
    (a: 26, b: 28),
    (a: 28, b: 30),
    (a: 28, b: 32),
  ];

  PoseLandmarkData? _byIndex(int index) {
    try {
      return landmarks.firstWhere((lm) => lm.index == index);
    } catch (_) {
      return null;
    }
  }

  Offset _point(PoseLandmarkData lm, Size size) {
    return Offset(lm.x * size.width * sizeFactor.width,
        lm.y * size.height * sizeFactor.height);
  }

  Color _landmarkColor(double visibility) {
    if (visibility > 0.8) {
      return Colors.greenAccent;
    }
    if (visibility > 0.5) {
      return Colors.amber;
    }
    return Colors.redAccent;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bonePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final pair in _connections) {
      final a = _byIndex(pair.a);
      final b = _byIndex(pair.b);
      if (a == null || b == null) {
        continue;
      }
      canvas.drawLine(_point(a, size), _point(b, size), bonePaint);
    }

    for (final lm in landmarks) {
      final Paint p = Paint()..color = _landmarkColor(lm.likelihood);
      canvas.drawCircle(_point(lm, size), 6, p);
      final label = angleLabels[lm.index];
      if (label != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, _point(lm, size) + const Offset(8, -8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.angleLabels != angleLabels;
  }
}
