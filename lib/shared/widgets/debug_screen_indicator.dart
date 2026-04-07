import 'package:flutter/material.dart';

/// Debug overlay showing current screen name and button state
class DebugScreenIndicator extends StatelessWidget {
  final String screenName;
  final bool isButtonEnabled;
  
  const DebugScreenIndicator({
    required this.screenName,
    required this.isButtonEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 $screenName',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              isButtonEnabled ? '✓ Button Active' : '✗ Button Disabled',
              style: TextStyle(
                color: isButtonEnabled ? Colors.greenAccent : Colors.redAccent,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
