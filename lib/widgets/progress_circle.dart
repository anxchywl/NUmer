import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProgressCircle extends StatelessWidget {
  final double current;
  final double goal;
  final double size;
  final Color? color;

  const ProgressCircle({
    super.key,
    required this.current,
    required this.goal,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Clamp progress between 0 and 1
    final double progress = (goal > 0) ? (current / goal).clamp(0.0, 1.0) : 0.0;

    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) {
          // If we are animating towards completion, we might want to handle the checkmark transition smoothly.
          // However, the requirement says "Smooth animation from old -> new value".
          // The stroke width change is discrete steps based on the *target* value usually, or instantaneous?
          // "0-24% -> thin" implies it depends on the value.
          // Let's base stroke width on the *animated* progress to make it feel organic, 
          // OR base it on the target to match the "state". 
          // Users usually prefer the visual weight to match the current fill. Let's use animatedProgress.
          
          double currentStrokeWidth;
          if (animatedProgress < 0.25) {
            currentStrokeWidth = 2.0;
          } else if (animatedProgress < 0.50) {
            currentStrokeWidth = 3.0;
          } else if (animatedProgress < 0.75) {
            currentStrokeWidth = 4.0;
          } else {
            currentStrokeWidth = 5.0;
          }
          
          // Special case: if it's fully complete (target is 1.0), we want to show the checkmark.
          // We can fade in the checkmark as it reaches 1.0.
          final showCheckmark = animatedProgress >= 0.99;

          return CustomPaint(
            painter: _ProgressPainter(
              progress: animatedProgress,
              color: activeColor,
              strokeWidth: currentStrokeWidth,
              isCompleted: showCheckmark,
            ),
            child: showCheckmark
                ? Center(
                    child: Icon(
                      Icons.check,
                      size: size * 0.6,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool isCompleted;

  _ProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = isCompleted ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    if (isCompleted) {
      // Draw filled circle
      canvas.drawCircle(center, radius, paint);
    } else {
      // Draw background circle (optional, usually nice for context, but requirements said "Progress circle... Update only on Update progress... No extra text". 
      // Requirement didn't explicitly ask for a track/background, but "Progress circle" usually implies one.
      // However, "Stroke thickness... 0-24% thin" implies we are just drawing the active part.
      // Let's stick to just the active part for now as per "No extra text, visual only" implying minimal.
      // Wait, "Circle fully closed" at 100%. 
      
      // Let's just draw the progress arc.
      // We need to account for stroke width so it doesn't clip.
      final correctedRadius = radius - strokeWidth / 2;
      
      // Start from top (-pi/2)
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: correctedRadius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isCompleted != isCompleted;
  }
}
