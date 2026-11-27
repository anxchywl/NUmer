import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_app/l10n/app_localizations.dart';

const double _dotSize = 10;

Future<void> showCoursePickerSheet(BuildContext context) {
  return showNumerSheet<void>(
    context,
    title: AppLocalizations.of(context)!.selectCourse,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final course in sheetContext.watch<AppState>().courses)
          NumerRow(
            leading: _CourseDot(color: course.color),
            title: course.name,
            onTap: () => _pick(sheetContext, course),
          ),
      ],
    ),
  );
}

void _pick(BuildContext sheetContext, Course course) {
  final navigator = Navigator.of(sheetContext, rootNavigator: true);
  navigator.pop();
  showCourseTimeSheet(navigator.context, course);
}

class _CourseDot extends StatelessWidget {
  const _CourseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _dotSize,
      height: _dotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
