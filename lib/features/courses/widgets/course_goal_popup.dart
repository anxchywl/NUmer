import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../course.dart';
import '../course_format.dart';

const int _kDefaultSemesterWeeks = 14;

String _fmtHours(double h, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final whole = h.floor();
  final mins = ((h - whole) * 60).round();
  if (mins == 0) return '$whole${l10n.hUnit}';
  return '$whole${l10n.hUnit} $mins${l10n.mUnit}';
}

void openCourseGoalPopup(BuildContext context, Course c) async {
  final appState = context.read<AppState>();
  final savedGoal = appState.goalHoursForCourse(c.id);
  final level = c.expLevel ?? 3;
  final perCred = hoursPerCreditForLevel(level);
  final credits = c.credits!;
  final defaultWeekly = credits * perCred;
  final weekly = savedGoal ?? defaultWeekly;

  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      double customWeekly = weekly;
      final sliderMin = math.min(defaultWeekly * 0.5, customWeekly);
      final sliderMax = math.max(defaultWeekly * 1.5, customWeekly);
      final tt = Theme.of(ctx).textTheme;
      final scheme = Theme.of(ctx).colorScheme;

      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _goalHeader(context, ctx, tt, scheme),
                const SizedBox(height: 16),

                // Course Info
                _goalCourseInfo(context, c, level, tt, scheme),
                const SizedBox(height: 24),

                // Stats Card
                _goalStats(context, customWeekly, scheme),

                const SizedBox(height: 24),

                // Slider
                Text(
                  AppLocalizations.of(context)!.adjustWeeklyGoal,
                  style: tt.labelLarge?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.hPerWeek(customWeekly.toStringAsFixed(1)),
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                Slider(
                  min: sliderMin,
                  max: sliderMax,
                  divisions: ((sliderMax - sliderMin) * 2).round(), // 0.5 steps
                  value: customWeekly,
                  onChanged: (v) => setLocal(() => customWeekly = v),
                ),

                const SizedBox(height: 32),

                // Save Button
                _goalSaveButton(context, appState, c.id, customWeekly),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _goalHeader(
  BuildContext context,
  BuildContext ctx,
  TextTheme tt,
  ColorScheme scheme,
) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        AppLocalizations.of(context)!.setGoals,
        style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      IconButton(
        onPressed: () => Navigator.pop(ctx),
        icon: const Icon(Icons.close),
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
        ),
      ),
    ],
  );
}

Widget _goalCourseInfo(
  BuildContext context,
  Course c,
  int level,
  TextTheme tt,
  ColorScheme scheme,
) {
  return Row(
    children: [
      CircleAvatar(backgroundColor: c.color, radius: 6),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          c.name,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(expShortLabel(context, level), style: tt.labelSmall),
      ),
    ],
  );
}

Widget _goalStats(
  BuildContext context,
  double customWeekly,
  ColorScheme scheme,
) {
  final semester = customWeekly * _kDefaultSemesterWeeks;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    ),
    child: Column(
      children: [
        _popupRow(
          AppLocalizations.of(context)!.semester(_kDefaultSemesterWeeks),
          _fmtHours(semester, context),
        ),
        Divider(
          height: 16,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        _popupRow(
          AppLocalizations.of(context)!.targetPerWeek,
          _fmtHours(customWeekly, context),
          isBold: true,
        ),
        Divider(
          height: 16,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        _popupRow(
          AppLocalizations.of(context)!.targetPerDay,
          _fmtHours(customWeekly / 7, context),
        ),
      ],
    ),
  );
}

Widget _goalSaveButton(
  BuildContext context,
  AppState appState,
  String courseId,
  double customWeekly,
) {
  return FilledButton(
    onPressed: () async {
      final navigator = Navigator.of(context);
      final l10n = AppLocalizations.of(context)!;
      await appState.setCourseGoalHours(courseId, customWeekly);

      if (!navigator.mounted) return;
      navigator.pop();
      showAppMessage(navigator.context, l10n.goalsUpdated);
    },
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Text(
      AppLocalizations.of(context)!.save,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );
}

Widget _popupRow(String label, String value, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class CreditsBadge extends StatelessWidget {
  final double credits;
  final VoidCallback onTap;
  const CreditsBadge({super.key, required this.credits, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bg = t.colorScheme.surfaceContainerHighest.withAlpha(
      (0.7 * 255).round(),
    );
    final fg = t.colorScheme.onSurface.withAlpha((0.9 * 255).round());
    final text = credits == 1
        ? '1 ${AppLocalizations.of(context)!.credits}'
        : '${credits % 1 == 0 ? credits.toInt() : credits.toStringAsFixed(1)} ${AppLocalizations.of(context)!.credits_plural}';

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: t.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
