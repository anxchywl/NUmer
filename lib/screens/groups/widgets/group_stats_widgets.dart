

import 'package:flutter/material.dart';
import '../../../models/group_statistics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/universal_avatar.dart';





class PeriodFilterChips extends StatelessWidget {
  final StatisticsPeriod selectedPeriod;
  final ValueChanged<StatisticsPeriod> onPeriodChanged;

  const PeriodFilterChips({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      children: StatisticsPeriod.values.map((period) {
        final isSelected = period == selectedPeriod;
        return FilterChip(
          label: Text(_periodLabel(context, period)),
          selected: isSelected,
          onSelected: isSelected ? null : (_) => onPeriodChanged(period),
          backgroundColor: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
              side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
              ),
        );
      }).toList(),
    );
  }
}





class GroupSummaryCard extends StatelessWidget {
  final GroupStatistics stats;
  final AnimationController animationController;

  const GroupSummaryCard({
    super.key,
    required this.stats,
    required this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avgSeconds = stats.averageStudyTimeSeconds;
    final totalSeconds = stats.totalStudyTimeSeconds;
    final bestPerformer = stats.bestPerformer;
    final lowestPerformer = stats.lowestPerformer;

    return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Text(
              AppLocalizations.of(context)!.groupSummary,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                _StatBox(
                  label: AppLocalizations.of(context)!.average,
                  value: _formatSeconds(context, avgSeconds),
                  icon: Icons.trending_up,
                  color: colorScheme.primary,
                  animation: animationController,
                ),
                _StatBox(
                  label: AppLocalizations.of(context)!.total,
                  value: _formatSeconds(context, totalSeconds),
                  icon: Icons.show_chart,
                  color: colorScheme.secondary,
                  animation: animationController,
                ),
                _StatBox(
                  label: AppLocalizations.of(context)!.leader,
                  value: bestPerformer?.name ?? '-',
                  icon: Icons.emoji_events,
                  color: const Color(0xFFFFB800),
                  animation: animationController,
                ),
                _StatBox(
                  label: AppLocalizations.of(context)!.lowest,
                  value: lowestPerformer?.name ?? '-',
                  icon: Icons.trending_down,
                  color: colorScheme.tertiary,
                  animation: animationController,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  
}

String _formatSeconds(BuildContext context, int totalSeconds) {
  final l10n = AppLocalizations.of(context)!;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours${l10n.hUnit} $minutes${l10n.mUnit}';
  } else if (minutes > 0) {
    return '$minutes${l10n.mUnit} $seconds${l10n.sUnit}';
  }
  return '$seconds${l10n.sUnit}';
}

String _periodLabel(BuildContext context, StatisticsPeriod period) {
  final l10n = AppLocalizations.of(context)!;
  return switch (period) {
    StatisticsPeriod.today => l10n.today,
    StatisticsPeriod.last7Days => l10n.weeklyGoal,
    StatisticsPeriod.lastMonth => l10n.month,
  };
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AnimationController animation;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.1),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}





class MemberCardMobile extends StatelessWidget {
  final MemberStudyData member;
  final int groupAverage;
  final VoidCallback onTap;

  const MemberCardMobile({
    super.key,
    required this.member,
    required this.groupAverage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percentage = member.getPercentageOfAverage(groupAverage);
    
    final safePercentage = percentage.isNaN || percentage.isInfinite ? 0.0 : percentage;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Row(
                children: [
                  UniversalAvatar(
                    userId: member.userId,
                    name: member.name,
                    initialAvatarIndex: member.avatarIndex,
                    initialAvatarColorValue: member.avatarColorValue,
                    initialAvatarBase64: member.avatarBase64,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (member.isLeader)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text('🥇', style: theme.textTheme.bodyLarge),
                              ),
                            Text(
                              member.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (member.isCurrentUser)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Chip(
                                  label: Text(AppLocalizations.of(context)!.youMember),
                                  labelPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatSeconds(context, member.studyTimeSeconds),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (safePercentage / 200).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getPerformanceColor(percentage),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${safePercentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getPerformanceColor(percentage),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 150) return const Color(0xFF10B981); 
    if (percentage >= 100) return const Color(0xFF3B82F6); 
    if (percentage >= 50) return const Color(0xFFF59E0B); 
    return const Color(0xFFEF4444); 
  }
}





class MemberTableView extends StatelessWidget {
  final List<MemberStudyData> members;
  final int groupAverage;
  final ValueChanged<MemberStudyData> onMemberTap;

  const MemberTableView({
    super.key,
    required this.members,
    required this.groupAverage,
    required this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(AppLocalizations.of(context)!.member)),
            DataColumn(label: Text(AppLocalizations.of(context)!.todayDataTable), numeric: true),
            DataColumn(label: Text(AppLocalizations.of(context)!.monthDataTable), numeric: true),
            DataColumn(label: Text(AppLocalizations.of(context)!.vsAverage), numeric: true),
          ],
          rows: members.map((member) {
            final percentage = member.getPercentageOfAverage(groupAverage);
            return DataRow(
              onSelectChanged: (_) => onMemberTap(member),
              cells: [
                DataCell(
                  Row(
                    children: [
                      UniversalAvatar(
                        userId: member.userId,
                        name: member.name,
                        initialAvatarIndex: member.avatarIndex,
                        initialAvatarColorValue: member.avatarColorValue,
                        initialAvatarBase64: member.avatarBase64,
                        size: 32,
                        fontSize: 14,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              if (member.isLeader)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text('🥇', style: theme.textTheme.bodySmall),
                                ),
                              Text(member.name),
                            ],
                          ),
                          if (member.isCurrentUser)
                            Text(
                              'You',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(_formatSeconds(context, member.todayStudyTimeSeconds)),
                ),
                DataCell(
                  Text(_formatSeconds(context, member.monthStudyTimeSeconds)),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPerformanceColor(percentage).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getPerformanceColor(percentage),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      )
    );
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 150) return const Color(0xFF10B981);
    if (percentage >= 100) return const Color(0xFF3B82F6);
    if (percentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}





class MemberComparisonChart extends StatefulWidget {
  final List<MemberStudyData> members;
  final int groupAverage;
  final AnimationController animationController;

  const MemberComparisonChart({
    super.key,
    required this.members,
    required this.groupAverage,
    required this.animationController,
  });

  @override
  State<MemberComparisonChart> createState() => _MemberComparisonChartState();
}

class _MemberComparisonChartState extends State<MemberComparisonChart> {
  late Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _barAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: widget.animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _barAnimation.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    
    final maxSeconds = widget.members
        .map((m) => m.studyTimeSeconds)
        .reduce((a, b) => a > b ? a : b);

    return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.studyTimeComparison,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ...widget.members.map((member) {
              final percentage = (maxSeconds == 0)
                  ? 0.0
                  : (member.studyTimeSeconds / maxSeconds);
              final safePercentage = percentage.isNaN || percentage.isInfinite ? 0.0 : percentage;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UniversalAvatar(
                          userId: member.userId,
                          name: member.name,
                          initialAvatarIndex: member.avatarIndex,
                          initialAvatarColorValue: member.avatarColorValue,
                          initialAvatarBase64: member.avatarBase64,
                          size: 28,
                          fontSize: 10,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            member.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatSeconds(context, member.studyTimeSeconds),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: _barAnimation,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (() {
                              final v = safePercentage * _barAnimation.value;
                              if (v.isNaN || v.isInfinite || v < 0.0) return 0.0;
                              if (v > 1.0) return 1.0;
                              return v;
                            })(),
                            minHeight: 24,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              member.isLeader
                                  ? const Color(0xFFFFB800)
                                  : _getPerformanceColor(
                                      member.getPercentageOfAverage(widget.groupAverage),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 150) return const Color(0xFF10B981);
    if (percentage >= 100) return const Color(0xFF3B82F6);
    if (percentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}





class MemberDetailsBottomSheet extends StatefulWidget {
  final MemberStudyData member;
  final int groupAverage;

  const MemberDetailsBottomSheet({
    super.key,
    required this.member,
    required this.groupAverage,
  });

  @override
  State<MemberDetailsBottomSheet> createState() => _MemberDetailsBottomSheetState();
}

class _MemberDetailsBottomSheetState extends State<MemberDetailsBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _chartAnimationController;

  @override
  void initState() {
    super.initState();
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _chartAnimationController.forward();
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percentage = widget.member.getPercentageOfAverage(widget.groupAverage);

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Row(
                  children: [
                    UniversalAvatar(
                      userId: widget.member.userId,
                      name: widget.member.name,
                      initialAvatarIndex: widget.member.avatarIndex,
                      initialAvatarColorValue: widget.member.avatarColorValue,
                      initialAvatarBase64: widget.member.avatarBase64,
                      size: 64,
                      fontSize: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.member.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (widget.member.isLeader)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text('🥇', style: theme.textTheme.headlineSmall),
                                ),
                            ],
                          ),
                          Text(
                            _formatSeconds(context, widget.member.studyTimeSeconds),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getPerformanceColor(percentage).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPerformanceColor(percentage).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: _getPerformanceColor(percentage),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                               AppLocalizations.of(context)!.performanceVsGroup,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                               '${percentage.toStringAsFixed(1)}% ${AppLocalizations.of(context)!.ofAverage}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: _getPerformanceColor(percentage),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                
                Text(
                   AppLocalizations.of(context)!.studyTimeByDay,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                
                Container(
                  height: 200,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildDailyBreakdownChart(),
                ),

                const SizedBox(height: 24),

                
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: AppLocalizations.of(context)!.bestDay,
                        value: _formatSeconds(context, _getBestDayTimeInSeconds()),
                        icon: Icons.star,
                        color: const Color(0xFFFFB800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: AppLocalizations.of(context)!.avgDay,
                        value: _formatSeconds(context, _getAverageDailyTimeInSeconds()),
                        icon: Icons.auto_graph,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyBreakdownChart() {
    if (widget.member.dailyBreakdown.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final maxSeconds = widget.member.dailyBreakdown
        .map((d) => d.studyTimeSeconds)
        .reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: widget.member.dailyBreakdown.map((entry) {
        final percentage = maxSeconds > 0 ? entry.studyTimeSeconds / maxSeconds : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: entry.getFormattedTime(),
                  child: AnimatedBuilder(
                    animation: _chartAnimationController,
                    builder: (context, child) {
                      return Container(
                        height: 150 * percentage * _chartAnimationController.value,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color(widget.member.avatarColorValue),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDayOfWeek(context, entry.date),
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  int _getBestDayTimeInSeconds() {
    if (widget.member.dailyBreakdown.isEmpty) return 0;
    return widget.member.dailyBreakdown
        .map((e) => e.studyTimeSeconds)
        .reduce((a, b) => a > b ? a : b);
  }

  int _getAverageDailyTimeInSeconds() {
    if (widget.member.dailyBreakdown.isEmpty) return 0;
    final total = widget.member.dailyBreakdown
      .fold<int>(0, (acc, d) => acc + d.studyTimeSeconds);
    return total ~/ widget.member.dailyBreakdown.length;
  }

  String _formatDayOfWeek(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final days = [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
    return days[date.weekday - 1];
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 150) return const Color(0xFF10B981);
    if (percentage >= 100) return const Color(0xFF3B82F6);
    if (percentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}





class ErrorPlaceholder extends StatelessWidget {
  final String error;

  const ErrorPlaceholder({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load data',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}





class TopThreeLeaderboard extends StatelessWidget {
  final List<MemberStudyData> members;

  const TopThreeLeaderboard({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    final top = members.take(3).toList();
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: top.map((m) {
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color(m.avatarColorValue),
                child: Text(
                  m.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                m.name,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatSeconds(context, m.studyTimeSeconds),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class TodayMembersCarousel extends StatelessWidget {
  final List<MemberStudyData> members;
  final ValueChanged<MemberStudyData>? onMemberTap;

  const TodayMembersCarousel({super.key, required this.members, this.onMemberTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final m = members[index];
          return GestureDetector(
            onTap: () => onMemberTap?.call(m),
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(m.avatarColorValue),
                        child: Text(
                          m.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              m.name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatSeconds(context, m.todayStudyTimeSeconds),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: members.length,
      ),
    );
  }
}

class LeaderboardList extends StatelessWidget {
  final List<MemberStudyData> members;
  final int groupAverage;

  const LeaderboardList({super.key, required this.members, required this.groupAverage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: members.map((m) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MemberCardMobile(
            member: m,
            groupAverage: groupAverage,
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => MemberDetailsBottomSheet(member: m, groupAverage: groupAverage),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                useSafeArea: true,
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

class TodayMemberPages extends StatelessWidget {
  final List<MemberStudyData> members;

  const TodayMemberPages({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: members.length,
      controller: PageController(viewportFraction: 0.9),
      itemBuilder: (context, index) {
        final m = members[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Color(m.avatarColorValue),
                        child: Text(
                          m.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('${AppLocalizations.of(context)!.todayDataTable}: ${_formatSeconds(context, m.todayStudyTimeSeconds)}', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text('${AppLocalizations.of(context)!.monthDataTable}: ${_formatSeconds(context, m.monthStudyTimeSeconds)}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


