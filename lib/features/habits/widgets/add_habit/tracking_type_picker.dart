import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        SegmentedButton<HabitType>(
          segments: [
            _segment(HabitType.yesNo, l10n.habitYesNo),
            _segment(HabitType.numeric, l10n.habitNumeric),
            _segment(HabitType.time, l10n.habitTime),
          ],
          selected: {type},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            HapticFeedback.selectionClick();
            onSelected(selection.first);
          },
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

  // a disabled button would also hide which type is selected
  ButtonSegment<HabitType> _segment(HabitType value, String label) {
    return ButtonSegment(
      value: value,
      label: Text(label, textAlign: TextAlign.center),
      enabled: !isEditing || value == type,
    );
  }
}
