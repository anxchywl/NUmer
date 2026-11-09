import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class AddHabitHeader extends StatelessWidget {
  final int screen;

  const AddHabitHeader({super.key, required this.screen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        const SizedBox(width: 48),
        Expanded(
          child: Text(
            switch (screen) {
              0 => l10n.habitCreateTitle,
              1 => l10n.habitTrackingTitle,
              2 => l10n.habitFrequencySectionTitle,
              3 => l10n.habitSchedulingTitle,
              _ => l10n.habitCreateTitle,
            },
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 48), // Balance close button
      ],
    );
  }
}
