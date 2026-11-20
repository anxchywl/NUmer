import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/tip_icon.dart';

import '../models/stats_models.dart';
import 'day_selector.dart';
import 'pie_chart_with_tooltip.dart';
import 'stats_section_container.dart';

class DayStatsSection extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final Future<PiePayload> pieFuture;
  final SliceTooltip? sliceTooltip;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onGoToday;
  final VoidCallback onPickDay;
  final ValueChanged<SliceTooltip> onSliceTap;
  final VoidCallback onDismissTooltip;
  final VoidCallback onOpenHistory;

  const DayStatsSection({
    super.key,
    required this.day,
    required this.isToday,
    required this.pieFuture,
    required this.sliceTooltip,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onGoToday,
    required this.onPickDay,
    required this.onSliceTap,
    required this.onDismissTooltip,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return StatsSectionContainer(
      title: AppLocalizations.of(context)!.dayStatistics,
      trailingHeader: TipIcon(
        title: AppLocalizations.of(context)!.tip,
        message:
            '${AppLocalizations.of(context)!.dayStatsTipLine1}\n${AppLocalizations.of(context)!.dayStatsTipLine2}\n${AppLocalizations.of(context)!.dayStatsTipLine3}',
      ),
      child: Column(
        children: [
          DaySelector(
            day: day,
            isToday: isToday,
            onPrevDay: onPrevDay,
            onNextDay: onNextDay,
            onGoToday: onGoToday,
            onPickDay: onPickDay,
          ),
          _pie(),
          _historyButton(context),
        ],
      ),
    );
  }

  Widget _pie() {
    return FutureBuilder<PiePayload>(
      future: pieFuture,
      builder: (context, snap) {
        final total = snap.data?.totalSeconds ?? 0;
        final slices = snap.data?.slices ?? const <Slice>[];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: PieChartWithTooltip(
            totalSeconds: total,
            slices: slices,
            tooltip: sliceTooltip,
            onSliceTap: onSliceTap,
            onDismiss: onDismissTooltip,
          ),
        );
      },
    );
  }

  Widget _historyButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.history, size: 18),
          label: Text(AppLocalizations.of(context)!.history),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onPressed: onOpenHistory,
        ),
      ),
    );
  }
}
