import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import '../course.dart';
import '../course_format.dart';
import '../swipeable_course_item.dart';
import 'course_goal_popup.dart';

class CourseListSliver extends StatelessWidget {
  const CourseListSliver({super.key, required this.onOpenCourse});

  final ValueChanged<Course> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.courses;

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverReorderableList(
        itemCount: courses.length,
        onReorder: (oldIndex, newIndex) =>
            state.reorderCourses(oldIndex, newIndex),
        itemBuilder: (context, i) => _item(context, state, courses, i),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    AppState state,
    List<Course> courses,
    int i,
  ) {
    final c = courses[i];

    return Padding(
      key: ValueKey(c.id),
      padding: EdgeInsets.only(bottom: i == courses.length - 1 ? 0 : 8),
      child: ReorderableDelayedDragStartListener(
        index: i,
        child: SwipeableCourseItem(
          confirmDelete: () => _confirmDelete(context),
          onDelete: () => state.removeCourse(c.id),
          child: Builder(builder: (context) => _tile(context, state, c)),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showNumerConfirm(
      context,
      title: l10n.deleteCourseTitle,
      body: l10n.deleteCourseMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );
  }

  Widget _tile(BuildContext context, AppState state, Course c) {
    final showSummary = state.homeSummaryRange != HomeSummaryRange.off;
    final showProgress = state.progressView != ProgressView.off;
    final customGoalHours = state.goalHoursForCourse(c.id) ?? 0;
    final hasCredits = (c.credits ?? 0) > 0;
    final willShowProgressBar =
        showProgress && (hasCredits || customGoalHours > 0);
    final isMinimal = !showSummary && !willShowProgressBar;

    if (isMinimal) return _minimalTile(context, c);

    return _detailTile(
      context,
      state,
      c,
      showSummary: showSummary,
      showProgress: showProgress,
      customGoalHours: customGoalHours,
    );
  }

  Widget _minimalTile(BuildContext context, Course c) {
    final courseTheme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(backgroundColor: c.color),
      title: Text(
        c.name,
        style: courseTheme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.more_horiz,
        color: courseTheme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => onOpenCourse(c),
    );
  }

  Widget _detailTile(
    BuildContext context,
    AppState state,
    Course c, {
    required bool showSummary,
    required bool showProgress,
    required double customGoalHours,
  }) {
    final hasCredits = (c.credits ?? 0) > 0;
    return ListTile(
      leading: CircleAvatar(backgroundColor: c.color),
      title: Row(
        children: [
          Expanded(
            child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if ((c.credits ?? 0) > 0 && showProgress)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CreditsBadge(
                credits: c.credits!,
                onTap: () => openCourseGoalPopup(context, c),
              ),
            ),
        ],
      ),
      subtitle: Builder(
        builder: (context) {
          final showProgressBar = hasCredits || customGoalHours > 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSummary) _summaryLine(context, state, c),
              if (showProgressBar && showProgress)
                _progressLine(context, state, c, customGoalHours),
            ],
          );
        },
      ),
      trailing: const Icon(Icons.more_horiz),
      onTap: () => onOpenCourse(c),
    );
  }

  Widget _summaryLine(BuildContext context, AppState state, Course c) {
    return FutureBuilder<Map<String, int>>(
      future: _loadCourseSeconds(context, c.id),
      builder: (context, snap) {
        final secs = snap.data?[c.id] ?? 0;
        final label = state.homeSummaryLabel(context);
        return Text('$label: ${formatHms(secs)}');
      },
    );
  }

  Widget _progressLine(
    BuildContext context,
    AppState state,
    Course c,
    double customGoalHours,
  ) {
    final hasCredits = (c.credits ?? 0) > 0;
    return FutureBuilder<int>(
      future: state.progressView == ProgressView.day
          ? Future<int>.value(state.todaySecondsFor(c.id))
          : weeklyElapsedForCourse(context, c.id),
      builder: (context, snap) {
        final elapsed = (snap.data ?? 0);
        return _goalProgress(
          context,
          state,
          c,
          elapsed: elapsed,
          hasCredits: hasCredits,
          customGoalHours: customGoalHours,
        );
      },
    );
  }

  Widget _goalProgress(
    BuildContext context,
    AppState state,
    Course c, {
    required int elapsed,
    required bool hasCredits,
    required double customGoalHours,
  }) {
    final level = c.expLevel ?? 3;
    final weeklyHoursGoal = customGoalHours > 0
        ? customGoalHours
        : hasCredits
        ? c.credits! * hoursPerCreditForLevel(level)
        : 0;
    if (weeklyHoursGoal <= 0) {
      return const SizedBox.shrink();
    }
    final weeklyGoalSecs = (weeklyHoursGoal * 3600).clamp(1, 1 << 31).toInt();
    final targetSecs = state.progressView == ProgressView.day
        ? (weeklyGoalSecs / 7).round().clamp(1, 1 << 31)
        : weeklyGoalSecs;
    final progress = targetSecs <= 0
        ? 0.0
        : (elapsed / targetSecs).clamp(0.0, 1.0);
    final labelPrefix = state.progressView == ProgressView.day
        ? AppLocalizations.of(context)!.dailyGoal
        : AppLocalizations.of(context)!.weeklyGoal;
    final targetHoursLabel = state.progressView == ProgressView.day
        ? (weeklyHoursGoal / 7).toStringAsFixed(1)
        : weeklyHoursGoal.toStringAsFixed(1);

    return _progressBar(
      context,
      progress: progress,
      label:
          '$labelPrefix: ${formatHms(elapsed)} / $targetHoursLabel${AppLocalizations.of(context)!.hUnit}',
    );
  }

  Widget _progressBar(
    BuildContext context, {
    required double progress,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: progress),
            builder: (context, v, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: v, minHeight: 8),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _loadCourseSeconds(
    BuildContext context,
    String id,
  ) async {
    final state = context.read<AppState>();
    final (start, end) = state.homeSummaryBoundsNow();
    final s = state;
    final bounds = (start, end);
    final map = await s.secondsByCourseBetween(bounds.$1, bounds.$2);
    return {id: map[id] ?? 0};
  }
}
