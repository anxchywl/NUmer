import 'package:flutter/material.dart';

import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class AddTimeCoursePicker extends StatelessWidget {
  const AddTimeCoursePicker({
    super.key,
    required this.courses,
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  final List<Course> courses;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return _empty(context);
    return SizedBox(
      height: 164,
      child: PageView.builder(
        // the picker leaves the tree while typing and must come back on the same course
        key: const PageStorageKey('add_time_course'),
        controller: controller,
        scrollDirection: Axis.vertical,
        onPageChanged: onChanged,
        itemCount: courses.length,
        itemBuilder: (context, i) => _card(context, courses[i], i == index),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(AppLocalizations.of(context)!.noCoursesAvailable),
    );
  }

  Widget _card(BuildContext context, Course course, bool selected) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: selected ? 1.0 : 0.95,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: selected ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? scheme.primary.withAlpha((0.40 * 255).round())
                  : scheme.outlineVariant,
            ),
          ),
          child: _cardContent(context, course),
        ),
      ),
    );
  }

  Widget _cardContent(BuildContext context, Course course) {
    return Row(
      children: [
        CircleAvatar(radius: 16, backgroundColor: course.color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            course.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
