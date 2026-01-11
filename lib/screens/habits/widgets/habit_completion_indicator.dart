import 'package:flutter/material.dart';
import '../../../models/habit.dart';
import '../../../widgets/progress_circle.dart';

class HabitCompletionIndicator extends StatelessWidget {
  final Habit habit;
  final double currentValue; // For today
  final double size;
  final double strokeWidth;

  const HabitCompletionIndicator({
    super.key,
    required this.habit,
    required this.currentValue,
    this.size = 36,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = currentValue >= habit.targetValue;
    
    if (habit.type == HabitType.yesNo) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isCompleted ? habit.color : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isCompleted ? habit.color : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 2, // Consistent border width
          ),
        ),
        child: isCompleted 
            ? Icon(Icons.check, color: Colors.white, size: size * 0.55) 
            : null,
      );
    } else {
      // Numeric / Time
      final progress = habit.targetValue > 0 ? currentValue / habit.targetValue : 0.0;
      
      // Calculate milestone-based stroke width
      double dynamicStrokeWidth = 2.0;
      if (progress >= 0.75) {
        dynamicStrokeWidth = 5.0;
      } else if (progress >= 0.50) {
        dynamicStrokeWidth = 4.0;
      } else if (progress >= 0.25) {
        dynamicStrokeWidth = 3.0;
      }

      return Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),
          
          // Progress Ring or Full Checkmark
          if (isCompleted)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: habit.color,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.white, size: size * 0.55),
            )
          else if (currentValue > 0)
            ProgressCircle(
              current: currentValue,
              goal: habit.targetValue,
              color: habit.color,
              size: size,
              strokeWidth: dynamicStrokeWidth,
            ),
        ],
      );
    }
  }
}
