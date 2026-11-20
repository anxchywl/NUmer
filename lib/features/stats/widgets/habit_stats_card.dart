import 'package:flutter/material.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../models/stats_models.dart';

class HabitStatsCard extends StatelessWidget {
  final Habit habit;
  final HabitStatsResult? stats;

  const HabitStatsCard({super.key, required this.habit, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = this.stats;
    // Refined Card Style
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow, // Softer background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const Spacer(),
            if (stats == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              _StatRow(
                label: l10n.habitStatsCompletionRate,
                value: "${stats.completionRate.toStringAsFixed(1)}%",
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: l10n.habitStatsCompleted,
                      value: "${stats.completed}",
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: l10n.habitStatsMissed,
                      value: "${stats.notCompleted}",
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Icon(
          IconData(
            habit.iconCodePoint,
            fontFamily: habit.iconFamily,
            fontPackage: habit.iconPackage,
          ),
          color: habit.color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            habit.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isKK = Localizations.localeOf(context).languageCode == 'kk';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
              fontSize: isKK ? 13 : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isKK = Localizations.localeOf(context).languageCode == 'kk';
    // Cleaner stat card: no border, subtle background
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isKK ? 10 : 11,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
