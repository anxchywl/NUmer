import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';
import '../../screens/swipe_selector.dart';

class ComparatorSelector extends StatelessWidget {
  final HabitComparator selected;
  final ValueChanged<HabitComparator> onChanged;

  const ComparatorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.center,
      child: SwipeSelector<HabitComparator>(
        items: HabitComparator.values
            .where((c) => c != HabitComparator.any)
            .toList(),
        selectedValue: selected,
        onChanged: onChanged,
        builder: (context, item) {
          String label = switch (item) {
            HabitComparator.atLeast => l10n.habitComparatorAtLeast,
            HabitComparator.lessThan => l10n.habitComparatorLessThan,
            HabitComparator.exactly => l10n.habitComparatorExactly,
            HabitComparator.any =>
              l10n.habitComparatorAny, // Should not happen with filter
          };
          return Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}
