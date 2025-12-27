import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../models/group_statistics.dart';
import '../services/group_service.dart';

import '../screens/groups/widgets/user_subjects_bottom_sheet.dart';
import '../l10n/app_localizations.dart';
import 'app_toast.dart';
import 'universal_avatar.dart';

class GroupLeaderboard extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupLeaderboard({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<GroupLeaderboard> createState() => _GroupLeaderboardState();
}

class _GroupLeaderboardState extends State<GroupLeaderboard> {
  StatisticsPeriod _selectedPeriod = StatisticsPeriod.today;

  Future<void> _showUserSubjects(MemberStudyData member) async {
    
    bool isDialogOpen = true; 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    ).then((_) => isDialogOpen = false);

    try {
      final groupService = context.read<GroupService>();
      final stats = await groupService.fetchMemberSubjectStats(
        groupId: widget.groupId,
        userId: member.userId,
        period: _selectedPeriod,
      );

      if (!mounted) return;
      
      if (isDialogOpen) {
        Navigator.pop(context); 
      } else {
        return; 
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => UserSubjectsBottomSheet(
          groupId: widget.groupId,
          userId: member.userId,
          name: member.name,
          avatarColorValue: member.avatarColorValue,
          period: _selectedPeriod,
          preloadedStats: stats,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      if (isDialogOpen) {
        Navigator.pop(context); 
        final errorMessage = e is StateError ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToLoadUserData(errorMessage))),
        );
      }
    }
  }

  String _getDateRangeLabel(StatisticsPeriod period) {
    final now = DateTime.now();
    final range = period.getDateRange(now);
    final start = range.$1;
    final end = range.$2;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String formatDate(DateTime d) =>
        '${twoDigits(d.day)}.${twoDigits(d.month)}.${twoDigits(d.year % 100)}';

    
    if (period == StatisticsPeriod.today) {
      return formatDate(start);
    }

    return '${formatDate(start)} – ${formatDate(end)}';
  }

  Future<void> _sendNudge(String targetUserId) {
    final groupService = context.read<GroupService>();
    return groupService.sendNudge(
      groupId: widget.groupId,
      targetUserId: targetUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupService = context.read<GroupService>();

    return Column(
      children: [
        
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              _PeriodSelector(
                selectedPeriod: _selectedPeriod,
                onPeriodChanged: (period) {
                  setState(() {
                    _selectedPeriod = period;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _getDateRangeLabel(_selectedPeriod),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        
        StreamBuilder<GroupStatistics>(
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

            // Use the actual member list from statistics (no temporary placeholders).
            List<MemberStudyData> membersWithPlaceholders = [];

            if (stats != null) {
              membersWithPlaceholders = List<MemberStudyData>.from(stats.members);
            }

            if (stats == null || stats.members.isEmpty) {
              return Center(
                child: Text(AppLocalizations.of(context)!.noDataAvailable),
              );
            }

            final topThree = membersWithPlaceholders.take(3).toList();
            final remaining = membersWithPlaceholders.skip(3).toList();

            return Column(
              children: [
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: _TopThreePodium(
                    topThree: topThree,
                    groupId: widget.groupId,
                    currentUserId: widget.currentUserId,
                    onMemberTap: _showUserSubjects,
                    onSendNudge: _sendNudge,
                  ),
                ),
                
                if (remaining.isNotEmpty)
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    clipBehavior: Clip.none,
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
                          onTap: () => _showUserSubjects(member),
                          groupId: widget.groupId,
                          currentUserId: widget.currentUserId,
                          onSendNudge: _sendNudge,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ],
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
                      _periodLabel(context, period),
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
  final String groupId;
  final String currentUserId;
  final ValueChanged<MemberStudyData> onMemberTap;
  final Future<void> Function(String targetUserId) onSendNudge;

  const _TopThreePodium({
    required this.topThree,
    required this.groupId,
    required this.currentUserId,
    required this.onMemberTap,
    required this.onSendNudge,
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
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              if (topThree.length >= 2)
                Positioned(
                  left: 21,
                  bottom: 20,
                  child: GestureDetector(
                    onTap: () => onMemberTap(topThree[1]),
                    child: _PodiumMember(
                      member: topThree[1],
                      rank: 2,
                      colorScheme: colorScheme,
                      theme: theme,
                      groupId: groupId,
                      currentUserId: currentUserId,
                      onSendNudge: onSendNudge,
                    ),
                  ),
                ),
              
              if (topThree.length >= 3)
                Positioned(
                  right: 21,
                  bottom: 20,
                  child: GestureDetector(
                    onTap: () => onMemberTap(topThree[2]),
                    child: _PodiumMember(
                      member: topThree[2],
                      rank: 3,
                      colorScheme: colorScheme,
                      theme: theme,
                      groupId: groupId,
                      currentUserId: currentUserId,
                      onSendNudge: onSendNudge,
                    ),
                  ),
                ),
              
              if (topThree.isNotEmpty)
                Positioned(
                  bottom: 50,
                  child: GestureDetector(
                    onTap: () => onMemberTap(topThree[0]),
                    child: _PodiumMember(
                      member: topThree[0],
                      rank: 1,
                      colorScheme: colorScheme,
                      theme: theme,
                      groupId: groupId,
                      currentUserId: currentUserId,
                      onSendNudge: onSendNudge,
                    ),
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
  final String groupId;
  final String currentUserId;
  final Future<void> Function(String targetUserId) onSendNudge;

  const _PodiumMember({
    required this.member,
    required this.rank,
    required this.colorScheme,
    required this.theme,
    required this.groupId,
    required this.currentUserId,
    required this.onSendNudge,
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
    final buttonSize = isFirst ? 26.0 : 24.0;

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
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(member.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                bool isStudying = false;
                if (snapshot.hasData && snapshot.data?.data() != null) {
                  final data = snapshot.data!.data()!;
                  isStudying = data['isStudying'] == true;
                }

                final avatar = AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    final t = _pulseAnim.value;
                    final glowOpacity = 0.10 + 0.05 * t;
                    final blur = isFirst ? (20 + 6 * t) : (14 + 4 * t);
                    final spread = isFirst ? (2 + 1.0 * t) : (1.2 + 0.8 * t);

                    
                    final gapColor = isStudying ? const Color(0xFF4CAF50) : Colors.white;
                    
                    
                    
                    
                    final shadowColor = isStudying 
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.4 + 0.2 * t) 
                        : ringColor.withValues(alpha: glowOpacity);

                    return Container(
                      padding: const EdgeInsets.all(3), 
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ringColor, 
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: blur,
                            spreadRadius: spread,
                          ),
                        ],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(3), 
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gapColor, 
                        ),
                        child: child,
                      ),
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
                );

                return avatar;
              },
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
                      color: Colors.black.withValues(alpha: 0.2),
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
            Positioned(
              bottom: (size + 12) / 2 * (1 - 0.7071) - (buttonSize / 2),
              right: (size + 12) / 2 * (1 - 0.7071) - (buttonSize / 2),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(member.userId)
                    .snapshots(),
                builder: (ctx, snap) {
                  bool allowsNudges = true;
                  bool canReceiveNudges = false;
                  if (snap.hasData && snap.data?.data() != null) {
                    final d = snap.data!.data()!;
                    allowsNudges = d['allowNudges'] != false;
                    canReceiveNudges = d['fcmEnabled'] == true;
                  }
                  if (member.userId == widget.currentUserId) return const SizedBox.shrink();

                  return _NudgeHandButton(
                    canReceiveNudges: canReceiveNudges,
                    allowsNudges: allowsNudges,
                    isCurrentUser: member.userId == widget.currentUserId,
                    size: buttonSize,
                    groupId: widget.groupId,
                    targetUserId: member.userId,
                    onSend: () => widget.onSendNudge(member.userId),
                  );
                },
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
  final VoidCallback onTap;
  final String groupId;
  final String currentUserId;
  final Future<void> Function(String targetUserId) onSendNudge;

  const _RankListTile({
    required this.member,
    required this.rank,
    required this.isCurrentUser,
    required this.onTap,
    required this.groupId,
    required this.currentUserId,
    required this.onSendNudge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? colorScheme.primaryContainer.withAlpha(50)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentUser
                ? colorScheme.primary.withAlpha(100)
                : colorScheme.outlineVariant.withAlpha(80),
            width: 1,
          ),
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
            
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(member.userId).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final isStudying = data?['isStudying'] == true;
                final allowsNudges = data?['allowNudges'] != false;
                final canReceiveNudges = data?['fcmEnabled'] == true;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UniversalAvatar(
                      userId: member.userId,
                      name: member.name,
                      initialAvatarIndex: member.avatarIndex,
                      initialAvatarColorValue: member.avatarColorValue,
                      initialAvatarBase64: member.avatarBase64,
                      size: 48,
                      fontSize: 20,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _UserStatusDot(
                        userId: member.userId,
                        size: 14,
                        isStudyingOverride: isStudying,
                      ),
                    ),
                    if (!isCurrentUser)
                      Positioned(
                        bottom: -4,
                        right: -6,
                        child: _NudgeHandButton(
                          canReceiveNudges: canReceiveNudges,
                          allowsNudges: allowsNudges,
                          isCurrentUser: isCurrentUser,
                          size: 22,
                          groupId: groupId,
                          targetUserId: member.userId,
                          onSend: () => onSendNudge(member.userId),
                        ),
                      ),
                  ],
                );
              },
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
      ),
    );
  }
}

class _NudgeHandButton extends StatefulWidget {
  final bool canReceiveNudges;
  final bool allowsNudges;
  final bool isCurrentUser;
  final double size;
  final String groupId;
  final String targetUserId;
  final Future<void> Function() onSend;

  const _NudgeHandButton({
    required this.canReceiveNudges,
    required this.allowsNudges,
    required this.isCurrentUser,
    required this.size,
    required this.groupId,
    required this.targetUserId,
    required this.onSend,
  });

  @override
  State<_NudgeHandButton> createState() => _NudgeHandButtonState();
}

class _NudgeHandButtonState extends State<_NudgeHandButton> {
  bool _sending = false;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap(bool isOnCooldown, Duration? remainingCooldown) async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context)!;

    if (isOnCooldown && remainingCooldown != null) {
      final minutes = remainingCooldown.inMinutes;
      final seconds = remainingCooldown.inSeconds % 60;
      final msg = minutes > 0 
          ? l10n.nudgeWaitMinutes(minutes)
          : l10n.nudgeWaitSeconds(seconds);
      showAppMessage(context, msg, isError: true);
      return;
    }

    if (!widget.allowsNudges) {
      showAppMessage(context, l10n.userProhibitedNudge, isError: true);
      return;
    }
    if (!widget.canReceiveNudges) {
      showAppMessage(context, l10n.memberCannotReceiveNudges, isError: true);
      return;
    }
    if (widget.isCurrentUser) {
      showAppMessage(context, l10n.cannotNudgeSelf, isError: true);
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSend();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      showAppMessage(context, l10n.nudgeSent);
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError ? e.message : e.toString();
      showAppMessage(
        context,
        l10n.failedToSendNudge(message),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  String _formatRemainingTime(BuildContext context, Duration remaining) {
    final l10n = AppLocalizations.of(context)!;
    if (remaining.inMinutes >= 1) {
      return '${remaining.inMinutes}${l10n.mUnit}';
    } else {
      return '${remaining.inSeconds}${l10n.sUnit}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groupService = context.read<GroupService>();

    return StreamBuilder<DateTime?>(
      stream: groupService.watchNudgeCooldown(
        groupId: widget.groupId,
        targetUserId: widget.targetUserId,
      ),
      builder: (context, snapshot) {
        DateTime? lastNudgeTime = snapshot.data;
        bool isOnCooldown = false;
        Duration? remainingCooldown;

        if (lastNudgeTime != null) {
          final now = DateTime.now();
          final cooldownEnd = lastNudgeTime.add(const Duration(hours: 1));
          
          if (now.isBefore(cooldownEnd)) {
            isOnCooldown = true;
            remainingCooldown = cooldownEnd.difference(now);
            
            // Schedule a rebuild when cooldown expires
            _cooldownTimer?.cancel();
            _cooldownTimer = Timer(remainingCooldown, () {
              if (mounted) {
                setState(() {});
              }
            });
          }
        }

        final enabled = widget.allowsNudges &&
            widget.canReceiveNudges &&
            !_sending &&
            !widget.isCurrentUser &&
            !isOnCooldown;

        final bgColor = enabled
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest;
        final iconColor = enabled
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant;

        return GestureDetector(
          onTap: () => _handleTap(isOnCooldown, remainingCooldown),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.scaffoldBackgroundColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _sending
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : isOnCooldown && remainingCooldown != null
                    ? Center(
                        child: Text(
                          _formatRemainingTime(context, remainingCooldown),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: iconColor,
                            fontWeight: FontWeight.bold,
                            fontSize: widget.size * 0.28,
                          ),
                        ),
                      )
                    : Transform.rotate(
                        angle: -0.4,
                        child: Icon(
                          Icons.touch_app_rounded,
                          size: widget.size * 0.6,
                          color: iconColor,
                        ),
                      ),
          ),
        );
      },
    );
  }
}


class _UserStatusDot extends StatelessWidget {
  final String userId;
  final double size;
  final bool? isStudyingOverride;

  const _UserStatusDot({
    required this.userId,
    required this.size,
    this.isStudyingOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (isStudyingOverride != null) {
      return _buildDot(context, isStudyingOverride!);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        bool isStudying = false;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          isStudying = data['isStudying'] == true;
        }

        return _buildDot(context, isStudying);
      },
    );
  }

  Widget _buildDot(BuildContext context, bool isStudying) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isStudying
            ? const Color(0xFF4CAF50) 
            : Colors.grey.shade400, 
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
        boxShadow: [
          if (isStudying)
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }
}

String _periodLabel(BuildContext context, StatisticsPeriod period) {
  final l10n = AppLocalizations.of(context)!;
  return switch (period) {
    StatisticsPeriod.today => l10n.today,
    StatisticsPeriod.last7Days => l10n.weeklyGoal,
    StatisticsPeriod.lastMonth => l10n.month,
  };
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
