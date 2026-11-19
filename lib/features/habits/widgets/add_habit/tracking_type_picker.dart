import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';

class TrackingTypePicker extends StatelessWidget {
  final HabitType type;
  final bool isEditing;
  final ValueChanged<HabitType> onSelected;

  const TrackingTypePicker({
    super.key,
    required this.type,
    required this.isEditing,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(theme, HabitType.yesNo, l10n.habitYesNo),
              _chip(theme, HabitType.numeric, l10n.habitNumeric),
              _chip(theme, HabitType.time, l10n.habitTime),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          switch (type) {
            HabitType.yesNo => l10n.habitTrackingYesNoDescription,
            HabitType.numeric => l10n.habitTrackingNumericDescription,
            HabitType.time => l10n.habitTrackingTimeDescription,
          },
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _chip(ThemeData theme, HabitType value, String label) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: type == value
              ? theme.colorScheme.onSecondaryContainer
              : (isEditing && type != value
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                    : null),
        ),
      ),
      selected: type == value,
      disabledColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      selectedColor: theme.colorScheme.secondaryContainer,
      onSelected: isEditing ? null : (b) => onSelected(value),
    );
  }
}
