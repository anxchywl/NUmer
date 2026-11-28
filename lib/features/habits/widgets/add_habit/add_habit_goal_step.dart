import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import '../../models/habit.dart';
import '../habit_time_picker.dart';
import 'comparator_selector.dart';
import 'next_button_style.dart';

class AddHabitGoalStep extends StatelessWidget {
  final Key leadKey;
  final Key navKey;
  final HabitType type;
  final NumerSheetFocusMode focus;
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
    required this.focus,
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
          child: _folded(typePicker),
        ),

        // Comparator & Goal
        if (type != HabitType.yesNo) ..._goalFields(theme, l10n),

        _folded(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: courseSelector,
          ),
        ),

        // the folds above take their padding with them
        SizedBox(height: focus.hidesChrome ? 16 : 0),

        // Navigation
        KeyedSubtree(
          key: navKey,
          child: SheetDoneActions(
            focus: focus,
            actions: _navigation(theme, l10n),
          ),
        ),
      ],
    );
  }

  Widget _folded(Widget child) => NumerFocusFold(
    hidden: focus.hidesChrome,
    animateSize: false,
    child: child,
  );

  List<Widget> _goalFields(ThemeData theme, AppLocalizations l10n) {
    return [
      _folded(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ComparatorSelector(
            selected: comparator,
            onChanged: onComparatorChanged,
          ),
        ),
      ),
      if (type == HabitType.numeric) ...[
        numericFields,
        _folded(_perDay(theme, l10n)),
      ] else if (type == HabitType.time) ...[
        _folded(
          Column(
            children: [
              HabitTimePicker(
                value: target,
                activeColor: theme.colorScheme.primary,
                onChanged: onTargetChanged,
              ),
              _perDay(theme, l10n),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _perDay(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Text(
          l10n.habitPerDay,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _navigation(ThemeData theme, AppLocalizations l10n) {
    return Row(
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
