import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../data/stats_labels.dart';
import '../models/stats_models.dart';
import '../stats_format.dart';
import 'stats_block.dart';

class PeriodRangeChips extends StatelessWidget {
  final Range range;
  final ValueChanged<Range> onSetRange;

  const PeriodRangeChips({
    super.key,
    required this.range,
    required this.onSetRange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        children: [
          SegChip(
            label: AppLocalizations.of(context)!.week,
            selected: range == Range.week,
            onTap: () => onSetRange(Range.week),
          ),
          SegChip(
            label: AppLocalizations.of(context)!.month,
            selected: range == Range.month,
            onTap: () => onSetRange(Range.month),
          ),
          SegChip(
            label: AppLocalizations.of(context)!.year,
            selected: range == Range.year,
            onTap: () => onSetRange(Range.year),
          ),
        ],
      ),
    );
  }
}

class PeriodRangeNavigator extends StatelessWidget {
  final Range range;
  final int shift;
  final DateTime start;
  final DateTime end;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const PeriodRangeNavigator({
    super.key,
    required this.range,
    required this.shift,
    required this.start,
    required this.end,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: prevLabel(context, range),
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: _label(context)),
          IconButton(
            tooltip: nextLabel(context, range),
            onPressed: shift >= 0 ? null : onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context) {
    return TextButton(
      onPressed: null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          periodLabel(context, start, end, range),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
