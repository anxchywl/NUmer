import 'package:flutter/material.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';

class CourseSelector extends StatelessWidget {
  final List<Course> courses;
  final HabitType type;
  final List<String> connectedIds;
  final void Function(String courseId, bool selected) onSelected;

  const CourseSelector({
    super.key,
    required this.courses,
    required this.type,
    required this.connectedIds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (courses.isEmpty) return const SizedBox.shrink();

    // Only show for Yes/No and Time
    if (type != HabitType.yesNo && type != HabitType.time) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.habitConnectCourse,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.habitCourseSyncHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _chip(theme, courses[index]),
          ),
        ),
      ],
    );
  }

  Widget _chip(ThemeData theme, Course c) {
    final isSelected = connectedIds.contains(c.id);
    return FilterChip(
      label: Text(c.name),
      selected: isSelected,
      onSelected: (selected) => onSelected(c.id, selected),
      avatar: CircleAvatar(backgroundColor: c.color, radius: 8),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : theme.colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
