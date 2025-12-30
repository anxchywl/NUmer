import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_statistics.dart';
import '../../services/group_service.dart';
import '../../widgets/universal_avatar.dart';
import '../../widgets/tip_icon.dart';

class GroupStatisticsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;

  const GroupStatisticsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
  });

  @override
  State<GroupStatisticsScreen> createState() => _GroupStatisticsScreenState();
}

class _GroupStatisticsScreenState extends State<GroupStatisticsScreen> {
  StatisticsPeriod _selectedPeriod = StatisticsPeriod.today;

  @override
  Widget build(BuildContext context) {
    final groupService = context.read<GroupService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.periodStatistics,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                TipIcon(
                  title: AppLocalizations.of(context)!.tip,
                  message: AppLocalizations.of(context)!.chartTip,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _PeriodSelector(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (period) {
                setState(() {
                  _selectedPeriod = period;
                });
              },
            ),
          ),
          
          Expanded(
            child: StreamBuilder<GroupStatistics>(
              stream: groupService.watchGroupStatistics(
                widget.groupId,
                _selectedPeriod,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(AppLocalizations.of(context)!.errorLoadingLeaderboard(snapshot.error.toString())),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var stats = snapshot.data;
                
                
                
                
                
                if (stats != null) {
                  final mockMembers = [
                    MemberStudyData(
                      userId: 'mock_user_1',
                      name: 'Alice',
                      avatarIndex: 0,
                      avatarColorValue: 0xFF6366F1,
                      studyTimeSeconds: 14400, 
                      todayStudyTimeSeconds: 7200,
                      monthStudyTimeSeconds: 86400,
                      isLeader: false,
                      isCurrentUser: false,
                      dailyBreakdown: [],
                    ),
                    MemberStudyData(
                      userId: 'mock_user_2',
                      name: 'Bob',
                      avatarIndex: 1,
                      avatarColorValue: 0xFFEC4899,
                      studyTimeSeconds: 10800, 
                      todayStudyTimeSeconds: 5400,
                      monthStudyTimeSeconds: 64800,
                      isLeader: false,
                      isCurrentUser: false,
                      dailyBreakdown: [],
                    ),
                    MemberStudyData(
                      userId: 'mock_user_3',
                      name: 'Charlie',
                      avatarIndex: 2,
                      avatarColorValue: 0xFF10B981,
                      studyTimeSeconds: 7200, 
                      todayStudyTimeSeconds: 3600,
                      monthStudyTimeSeconds: 43200,
                      isLeader: false,
                      isCurrentUser: false,
                      dailyBreakdown: [],
                    ),
                    MemberStudyData(
                      userId: 'mock_user_4',
                      name: 'Diana',
                      avatarIndex: 4,
                      avatarColorValue: 0xFFF59E0B,
                      studyTimeSeconds: 5400, 
                      todayStudyTimeSeconds: 2700,
                      monthStudyTimeSeconds: 32400,
                      isLeader: false,
                      isCurrentUser: false,
                      dailyBreakdown: [],
                    ),
                    MemberStudyData(
                      userId: 'mock_user_5',
                      name: 'Wilson',
                      avatarIndex: 5,
                      avatarColorValue: 0xFF8B5CF6,
                      studyTimeSeconds: 3600, 
                      todayStudyTimeSeconds: 1800,
                      monthStudyTimeSeconds: 21600,
                      isLeader: false,
                      isCurrentUser: false,
                      dailyBreakdown: [],
                    ),
                  ];
                  
                  
                  final allMembers = [...stats.members, ...mockMembers];
                  
                  allMembers.sort((a, b) => b.studyTimeSeconds.compareTo(a.studyTimeSeconds));
                  
                  stats = GroupStatistics(
                    groupId: stats.groupId,
                    members: allMembers,
                    periodStart: stats.periodStart,
                    periodEnd: stats.periodEnd,
                  );
                }
                
                
                
                
                if (stats == null || stats.members.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context)!.noDataAvailable),
                  );
                }

                final topThree = stats.members.take(3).toList();
                final remaining = stats.members.skip(3).toList();

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 24.0,
                        ),
                        child: _TopThreePodium(
                          topThree: topThree,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                      
                      if (remaining.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: remaining.length,
                            itemBuilder: (context, index) {
                              final member = remaining[index];
                              final rank = index + 4;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _RankListTile(
                                  member: member,
                                  rank: rank,
                                  isCurrentUser: member.userId == widget.currentUserId,
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final StatisticsPeriod selectedPeriod;
  final ValueChanged<StatisticsPeriod> onPeriodChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final period in StatisticsPeriod.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => onPeriodChanged(period),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedPeriod == period
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      period.shortLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selectedPeriod == period
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopThreePodium extends StatelessWidget {
  final List<MemberStudyData> topThree;
  final String currentUserId;

  const _TopThreePodium({
    required this.topThree,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        
        SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              
              if (topThree.length >= 2)
                Positioned(
                  left: 5,
                  bottom: 20,
                  child: _PodiumMember(
                    member: topThree[1],
                    rank: 2,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              
              if (topThree.length >= 3)
                Positioned(
                  right: 5,
                  bottom: 20,
                  child: _PodiumMember(
                    member: topThree[2],
                    rank: 3,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
              
              if (topThree.isNotEmpty)
                Positioned(
                  bottom: 50,
                  child: _PodiumMember(
                    member: topThree[0],
                    rank: 1,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodiumMember extends StatefulWidget {
  final MemberStudyData member;
  final int rank;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _PodiumMember({
    required this.member,
    required this.rank,
    required this.colorScheme,
    required this.theme,
  });

  @override
  _PodiumMemberState createState() => _PodiumMemberState();
}

class _PodiumMemberState extends State<_PodiumMember>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return const Color(0xFFCD7F32); 
      default:
        return widget.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final rank = widget.rank;
    final theme = widget.theme;
    final colorScheme = widget.colorScheme;

    final isFirst = rank == 1;
    final size = isFirst ? 100.0 : 80.0;
    final ringColor = _rankColor(rank);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Icon(
              Icons.emoji_events_rounded,
              color: ringColor,
              size: 32,
            ),
          ),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                final t = _pulseAnim.value;
                final glowOpacity = 0.10 + 0.05 * t;
                final blur = isFirst ? (20 + 6 * t) : (14 + 4 * t);
                final spread = isFirst ? (2 + 1.0 * t) : (1.2 + 0.8 * t);

                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withValues(alpha: glowOpacity),
                        blurRadius: blur,
                        spreadRadius: spread,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: UniversalAvatar(
                userId: member.userId,
                name: member.name,
                initialAvatarIndex: member.avatarIndex,
                initialAvatarColorValue: member.avatarColorValue,
                initialAvatarBase64: member.avatarBase64,
                size: size,
                fontSize: isFirst ? 40 : 32,
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ringColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  AppLocalizations.of(context)!.rankLabel(rank),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: isFirst ? 140 : 110,
          child: Column(
            children: [
              Text(
                member.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatStudyTime(context, member.studyTimeSeconds),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankListTile extends StatelessWidget {
  final MemberStudyData member;
  final int rank;
  final bool isCurrentUser;

  const _RankListTile({
    required this.member,
    required this.rank,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCurrentUser
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          
          SizedBox(
            width: 32,
            child: Text(
              AppLocalizations.of(context)!.rankLabel(rank),
              style: theme.textTheme.titleMedium?.copyWith(
                color: isCurrentUser
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          UniversalAvatar(
            userId: member.userId,
            name: member.name,
            initialAvatarIndex: member.avatarIndex,
            initialAvatarColorValue: member.avatarColorValue,
            initialAvatarBase64: member.avatarBase64,
            size: 48,
            fontSize: 20,
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCurrentUser)
                  Text(
                    AppLocalizations.of(context)!.youMember,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatStudyTime(context, member.studyTimeSeconds),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
String _formatStudyTime(BuildContext context, int totalSeconds) {
  final l10n = AppLocalizations.of(context)!;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours${l10n.hUnit} $minutes${l10n.mUnit}';
  } else if (minutes > 0) {
    return '$minutes${l10n.mUnit} $seconds${l10n.sUnit}';
  } else {
    return '$seconds${l10n.sUnit}';
  }
}
