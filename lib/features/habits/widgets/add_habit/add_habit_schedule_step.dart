import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import '../../models/habit.dart';
import 'frequency_option.dart';
import 'next_button_style.dart';

class AddHabitScheduleStep extends StatelessWidget {
  final Key navKey;
  final HabitFrequencyType frequency;
  final bool isEditing;
  final NumerSheetFocusMode focus;
  final ValueChanged<HabitFrequencyType> onFrequencySelected;
  final Widget specificDays;
  final Widget perPeriod;
  final Widget workRest;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  const AddHabitScheduleStep({
    super.key,
    required this.navKey,
    required this.frequency,
    required this.isEditing,
    required this.focus,
    required this.onFrequencySelected,
    required this.specificDays,
    required this.perPeriod,
    required this.workRest,
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
        // -- Step 3: Frequency --
        _folded(
          focus.hidesChrome,
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.habitFrequencyPrompt,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),

        IgnorePointer(
          ignoring: isEditing,
          child: Opacity(
            opacity: isEditing ? 0.72 : 1.0,
            child: _options(theme, l10n),
          ),
        ),

        SizedBox(height: focus.hidesChrome ? 16 : 32),

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

  Widget _folded(bool hidden, Widget child) =>
      NumerFocusFold(hidden: hidden, animateSize: false, child: child);

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

  Widget _options(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        _folded(focus.hidesChrome, _dayOptions(theme, l10n)),
        _folded(
          focus.hides('goal'),
          _option(
            HabitFrequencyType.repeatsInPeriod,
            l10n.habitFrequencyTimesPerPeriodTitle,
            perPeriod,
          ),
        ),
        NumerFocusGap(
          hidden: focus.hidesChrome,
          height: 12,
          animateSize: false,
        ),
        _folded(
          focus.hides('work') && focus.hides('rest'),
          _option(
            HabitFrequencyType.interval,
            l10n.habitFrequencyWorkRestTitle,
            workRest,
          ),
        ),
      ],
    );
  }

  Widget _dayOptions(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        _option(
          HabitFrequencyType.daily,
          l10n.habitFrequencyEveryDay,
          Text(
            l10n.habitFrequencyDailyDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _option(
          HabitFrequencyType.specificDays,
          l10n.habitFrequencySpecificTitle,
          specificDays,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _option(HabitFrequencyType type, String title, Widget child) {
    final selected = frequency == type;
    return FrequencyOption(
      title: title,
      selected: selected,
      // If editing, disable switching to other types
      disabled: isEditing && !selected,
      onSelect: () => onFrequencySelected(type),
      child: child,
    );
  }
}
