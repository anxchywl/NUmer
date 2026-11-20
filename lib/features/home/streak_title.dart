import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class StreakTitle extends StatelessWidget {
  const StreakTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final count = state.streakCount;
    final hasToday = state.hasStudyToday;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (count == 0) {
      return Text(
        l10n.noStreakYet,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withAlpha(
            (0.8 * 255).round(),
          ),
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: 22,
          color: hasToday ? Colors.orangeAccent : Colors.grey.shade400,
        ),
        const SizedBox(width: 6),
        Text(
          l10n.streakDays(count),
          style: theme.textTheme.titleMedium?.copyWith(
            color: hasToday
                ? state.accentColor
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
