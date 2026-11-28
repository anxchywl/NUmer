import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import '../../models/habit.dart';
import 'compact_number_field.dart';
import 'period_selector.dart';

class PerPeriodContent extends StatelessWidget {
  final HabitPeriod period;
  final NumerSheetFocusMode focus;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onTogglePeriod;

  const PerPeriodContent({
    super.key,
    required this.period,
    required this.focus,
    required this.controller,
    required this.onChanged,
    required this.onTogglePeriod,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NumerFocusFold(
          hidden: focus.hidesChrome,
          animateSize: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.habitFrequencyTimesPerPeriodDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CompactNumberField(
              fieldKey: const ValueKey('frequency_goal_input'),
              width: 80,
              focusNode: focus.nodeFor('goal'),
              controller: controller,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            Text(l10n.habitTimesPerLabel),
            const SizedBox(width: 12),

            // Tap to toggle period
            GestureDetector(
              onTap: onTogglePeriod,
              child: PeriodToggle(period: period),
            ),
          ],
        ),
      ],
    );
  }
}
