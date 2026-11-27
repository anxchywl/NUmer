import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class StreakTitle extends StatelessWidget {
  const StreakTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final count = state.streakCount;
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = context.text.screenTitle;

    if (count == 0) {
      return Text(l10n.noStreakYet, style: style.copyWith(color: muted));
    }

    final hasToday = state.hasStudyToday;
    final color = hasToday ? style.color : muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasToday
              ? Icons.local_fire_department
              : Icons.local_fire_department_outlined,
          color: color,
        ),
        const SizedBox(width: NumerSpace.xs),
        Flexible(
          child: Text(
            l10n.streakDays(count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
