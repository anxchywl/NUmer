import 'package:flutter/material.dart';

import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class CourseTimeHeader extends StatelessWidget {
  const CourseTimeHeader({
    super.key,
    required this.course,
    required this.isAnyRunning,
    required this.onToggleHidden,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final bool isAnyRunning;
  final VoidCallback onToggleHidden;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          height: 5,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: CircleAvatar(backgroundColor: course.color),
          title: Text(course.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _visibilityButton(context),
              _editButton(context),
              _deleteButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _visibilityButton(BuildContext context) {
    return IconButton(
      tooltip: course.hiddenFromLeaderboard
          ? AppLocalizations.of(context)!.unhideFromLeaderboard
          : AppLocalizations.of(context)!.hideFromLeaderboard,
      icon: Icon(
        course.hiddenFromLeaderboard ? Icons.visibility_off : Icons.visibility,
        color: isAnyRunning ? Colors.grey : Colors.blueGrey,
      ),
      onPressed: isAnyRunning ? null : onToggleHidden,
    );
  }

  Widget _editButton(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.edit,
      icon: Icon(
        Icons.edit,
        color: isAnyRunning ? Colors.grey : Colors.blueGrey,
      ),
      onPressed: isAnyRunning ? null : onEdit,
    );
  }

  Widget _deleteButton() {
    return IconButton(
      icon: Icon(Icons.delete, color: isAnyRunning ? Colors.grey : Colors.red),
      tooltip: 'Delete Course',
      onPressed: isAnyRunning ? null : onDelete,
    );
  }
}
