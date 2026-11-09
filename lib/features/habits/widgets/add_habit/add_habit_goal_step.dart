import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';
import '../habit_time_picker.dart';
import 'comparator_selector.dart';
import 'next_button_style.dart';
import 'slide_size_transition.dart';

class AddHabitGoalStep extends StatelessWidget {
  final Key leadKey;
  final Key navKey;
  final HabitType type;
  final bool isInputFocused;
  final Widget typePicker;
  final HabitComparator comparator;
  final ValueChanged<HabitComparator> onComparatorChanged;
  final Widget numericFields;
  final double target;
  final ValueChanged<double> onTargetChanged;
  final Widget courseSelector;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  const AddHabitGoalStep({
    super.key,
    required this.leadKey,
    required this.navKey,
    required this.type,
    required this.isInputFocused,
    required this.typePicker,
    required this.comparator,
    required this.onComparatorChanged,
    required this.numericFields,
    required this.target,
    required this.onTargetChanged,
    required this.courseSelector,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tracking Type
        AnimatedSize(
          key: leadKey,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: slideSizeTransition,
            child: isInputFocused
                ? const SizedBox.shrink(key: ValueKey('tracking_hidden'))
                : typePicker,
          ),
        ),

        // Comparator & Goal
        if (type != HabitType.yesNo) ..._goalFields(theme, l10n),

        const SizedBox(height: 16),
        courseSelector,
        const SizedBox(height: 16),

        // Navigation
        _navigation(theme, l10n),
      ],
    );
  }

  List<Widget> _goalFields(ThemeData theme, AppLocalizations l10n) {
    return [
      ComparatorSelector(selected: comparator, onChanged: onComparatorChanged),
      const SizedBox(height: 20),
      if (type == HabitType.numeric) ...[
        numericFields,
        const SizedBox(height: 16),
        _perDay(theme, l10n),
      ] else if (type == HabitType.time) ...[
        HabitTimePicker(
          value: target,
          activeColor: theme.colorScheme.primary,
          onChanged: onTargetChanged,
        ),
        const SizedBox(height: 16),
        _perDay(theme, l10n),
      ],
    ];
  }

  Widget _perDay(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Text(
        l10n.habitPerDay,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _navigation(ThemeData theme, AppLocalizations l10n) {
    return Row(
      key: navKey,
      children: [
        TextButton(onPressed: onBack, child: Text(l10n.habitBack)),
        const Spacer(),
        FilledButton(
          style: nextButtonStyle(theme),
          onPressed: onNext,
          child: Text(l10n.habitNext),
        ),
      ],
    );
  }
}
