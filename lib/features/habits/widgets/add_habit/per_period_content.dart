import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';
import 'compact_number_field.dart';
import 'period_selector.dart';

class PerPeriodContent extends StatelessWidget {
  final HabitPeriod period;
  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onTogglePeriod;

  const PerPeriodContent({
    super.key,
    required this.period,
    required this.focusNode,
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
        Text(
          l10n.habitFrequencyTimesPerPeriodDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CompactNumberField(
              fieldKey: const ValueKey('frequency_goal_input'),
              width: 80,
              focusNode: focusNode,
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
