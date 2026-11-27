import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../stats_format.dart';

class StatsBlock extends StatelessWidget {
  final int totalSecs;
  final int avgSecs;
  final String mostName;
  final int mostSecs;
  final Color? mostColor;
  final String leastName;
  final int leastSecs;
  final Color? leastColor;

  const StatsBlock({
    super.key,
    required this.totalSecs,
    required this.avgSecs,
    required this.mostName,
    required this.mostSecs,
    this.mostColor,
    required this.leastName,
    required this.leastSecs,
    this.leastColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const spacing = 12.0;

    return Column(
      children: [
        _TotalCard(totalSecs: totalSecs),
        const SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: _DetailStatCard(
                title: l10n.mostStudied,
                value: mostName,
                subValue: mostSecs > 0 ? fmtHMS(mostSecs) : null,
                accentColor: mostColor,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _DetailStatCard(
                title: l10n.leastStudied,
                value: leastName,
                subValue: (leastSecs > 0 && mostSecs > 0)
                    ? fmtHMS(leastSecs)
                    : null,
                accentColor: leastColor,
                icon: Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: spacing),
        _AverageRow(avgSecs: avgSecs),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int totalSecs;
  const _TotalCard({required this.totalSecs});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            l10n.total,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fmtTotalVerbose(
              totalSecs,
              context,
            ).replaceFirst(' ${l10n.total.toLowerCase()}', ''),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  final int avgSecs;
  const _AverageRow({required this.avgSecs});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.avgPerDay,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmtHMS(avgSecs),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final Color? accentColor;
  final IconData icon;

  const _DetailStatCard({
    required this.title,
    required this.value,
    this.subValue,
    this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: 8),
          _valueRow(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _valueRow(BuildContext context) {
    return Row(
      children: [
        if (accentColor != null)
          Container(
            width: 3,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subValue != null)
                Text(
                  subValue!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
