import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../stats_format.dart';

class DaySelector extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onGoToday;
  final VoidCallback onPickDay;

  const DaySelector({
    super.key,
    required this.day,
    required this.isToday,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onGoToday,
    required this.onPickDay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.previousDay,
            onPressed: onPrevDay,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: _dayButtons(context)),
          IconButton(
            tooltip: AppLocalizations.of(context)!.nextDay,
            onPressed: isToday ? null : onNextDay,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _dayButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _pickButton(context),
        const SizedBox(width: 8),
        _todayButton(context),
      ],
    );
  }

  Widget _pickButton(BuildContext context) {
    return Flexible(
      flex: 2,
      child: TextButton.icon(
        onPressed: onPickDay,
        icon: const Icon(Icons.calendar_today, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            fmtDateLong(day, context),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
      ),
    );
  }

  Widget _todayButton(BuildContext context) {
    return Flexible(
      child: OutlinedButton(
        onPressed: isToday ? null : onGoToday,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(AppLocalizations.of(context)!.today),
        ),
      ),
    );
  }
}
