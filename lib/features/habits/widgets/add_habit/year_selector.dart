import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class YearSelector extends StatelessWidget {
  final Set<int> selectedDates;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  const YearSelector({
    super.key,
    required this.selectedDates,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final localeName = AppLocalizations.of(context)!.localeName;
    final months = List.generate(
      12,
      (i) => DateFormat.MMM(localeName).format(DateTime(2024, i + 1, 1)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectedDates
              .where((encoded) {
                // Validate: month should be 1-12, day should be 1-31
                final m = encoded ~/ 100;
                final d = encoded % 100;
                return m >= 1 && m <= 12 && d >= 1 && d <= 31;
              })
              .map((encoded) {
                final m = encoded ~/ 100;
                final d = encoded % 100;
                return Chip(
                  label: Text("${months[m - 1]} $d"),
                  onDeleted: () => onRemove(encoded),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.habitAddDateAction),
        ),
      ],
    );
  }
}
