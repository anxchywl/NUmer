import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';
import 'frequency_option.dart';
import 'next_button_style.dart';

class AddHabitScheduleStep extends StatelessWidget {
  final Key navKey;
  final HabitFrequencyType frequency;
  final bool isEditing;
  final bool isFreqGoalFocused;
  final bool isWorkRestFocused;
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
    required this.isFreqGoalFocused,
    required this.isWorkRestFocused,
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
        // -- Step 3: Frequency --
        Text(l10n.habitFrequencyPrompt, style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),

        IgnorePointer(
          ignoring: isEditing,
          child: Opacity(
            opacity: isEditing ? 0.72 : 1.0,
            child: _options(theme, l10n),
          ),
        ),

        const SizedBox(height: 32),

        // Navigation
        Row(
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
        ),
      ],
    );
  }

  Widget _options(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: isFreqGoalFocused || isWorkRestFocused
              ? const SizedBox.shrink()
              : _dayOptions(theme, l10n),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: isWorkRestFocused
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    _option(
                      HabitFrequencyType.repeatsInPeriod,
                      l10n.habitFrequencyTimesPerPeriodTitle,
                      perPeriod,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: isFreqGoalFocused
              ? const SizedBox.shrink()
              : _option(
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
