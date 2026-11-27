import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/groups/models/group_statistics.dart';
import 'package:numer_app/features/groups/data/group_service.dart';

import 'package:numer_app/features/groups/widgets/user_subjects_bottom_sheet.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

String _displayName(BuildContext context, MemberStudyData member) =>
    member.name.isEmpty
    ? AppLocalizations.of(context)!.memberFallbackName
    : member.name;

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
  Stream<GroupStatistics>? _statsStream;
  final Map<StatisticsPeriod, GroupStatistics> _statsCache =
      <StatisticsPeriod, GroupStatistics>{};
  int _periodDirection = 1;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(GroupLeaderboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _statsCache.clear();
      _updateStream();
    }
  }

  void _updateStream() {
    final groupService = context.read<GroupService>();
    _statsStream = groupService.watchGroupStatistics(
      widget.groupId,
      _selectedPeriod,
    );
  }

  void _showUserSubjects(MemberStudyData member) async {
    if (!mounted) return;

    final groupService = context.read<GroupService>();
    final cachedRecord = await groupService.getCachedMemberSubjectStats(
      groupId: widget.groupId,
      userId: member.userId,
      period: _selectedPeriod,
    );
    final cachedStats = cachedRecord?.stats;

    // Refresh if no cache, or if total seconds mismatch (content changed)
    final shouldRefresh =
        cachedStats == null ||
        cachedStats.totalSeconds != member.studyTimeSeconds;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserSubjectsBottomSheet(
        groupId: widget.groupId,
        userId: member.userId,
        name: _displayName(this.context, member),
        avatarIndex: member.avatarIndex,
        avatarColorValue: member.avatarColorValue,
        avatarImageBase64: member.avatarBase64,
        period: _selectedPeriod,
        preloadedStats: cachedStats,
        shouldRefresh: shouldRefresh,
      ),
    );
  }

  String _getDateRangeLabel(StatisticsPeriod period) {
    final range = period.getDateRange();
    final start = range.$1;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String formatDate(DateTime d) =>
        '${twoDigits(d.day)}.${twoDigits(d.month)}.${twoDigits(d.year % 100)}';

    if (period == StatisticsPeriod.today) {
      return formatDate(start);
    }

    return '${formatDate(start)} – ${formatDate(range.$2)}';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              _PeriodSelector(
                selectedPeriod: _selectedPeriod,
                onPeriodChanged: (period) {
                  if (_selectedPeriod != period) {
                    final nextDirection = period.index > _selectedPeriod.index
                        ? 1
                        : -1;
                    setState(() {
                      _periodDirection = nextDirection;
                      _selectedPeriod = period;
                      _updateStream();
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _getDateRangeLabel(_selectedPeriod),
                      key: ValueKey<String>('range-${_selectedPeriod.name}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        StreamBuilder<GroupStatistics>(
          stream: _statsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.errorLoadingLeaderboard(snapshot.error.toString()),
                ),
              );
            }

            if (snapshot.hasData) {
              _statsCache[_selectedPeriod] = snapshot.data!;
            }
            final stats = snapshot.data ?? _statsCache[_selectedPeriod];

            if (snapshot.connectionState == ConnectionState.waiting &&
                stats == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final child = (stats == null || stats.members.isEmpty)
                ? Center(
                    key: ValueKey<String>('empty-${_selectedPeriod.name}'),
                    child: Text(AppLocalizations.of(context)!.noDataAvailable),
                  )
                : Column(
                    key: ValueKey<String>('data-${_selectedPeriod.name}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: _TopThreePodium(
                          topThree: stats.members.take(3).toList(),
                          groupId: widget.groupId,
                          currentUserId: widget.currentUserId,
                          onMemberTap: _showUserSubjects,
                          onSendNudge: _sendNudge,
                        ),
                      ),
                      if (stats.members.length > 3)
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          clipBehavior: Clip.none,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stats.members.length - 3,
                          itemBuilder: (context, index) {
                            final member = stats.members[index + 3];
                            final rank = index + 4;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _RankListTile(
                                member: member,
                                rank: rank,
                                isCurrentUser:
                                    member.userId == widget.currentUserId,
                                onTap: () => _showUserSubjects(member),
                                onSendNudge: _sendNudge,
                                groupId: widget.groupId,
                                currentUserId: widget.currentUserId,
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  );

            final directionFactor = _periodDirection >= 0 ? 1.0 : -1.0;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: Offset(-0.06 * directionFactor, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: child,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
      child: SegmentedButton<StatisticsPeriod>(
        segments: [
          for (final period in StatisticsPeriod.values)
            ButtonSegment(
              value: period,
              label: Text(_periodLabel(context, period)),
            ),
        ],
        selected: {selectedPeriod},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          HapticFeedback.selectionClick();
          onPeriodChanged(selection.first);
        },
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
    final ringColor = _rankColor(rank);
    final isFirst = rank == 1;
    final size = isFirst ? 100.0 : 80.0;
    final buttonSize = isFirst ? 26.0 : 24.0;

    // Check locally if session has expired
    final expiration = member.sessionRunUntil;
    final isLocallyActive =
        member.isStudying &&
        (expiration == null || DateTime.now().isBefore(expiration));
    final isStudying = isLocallyActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Icon(Icons.emoji_events_rounded, color: ringColor, size: 32),
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

                final gapColor = isStudying
                    ? const Color(0xFF4CAF50)
                    : Colors.white;
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
              child: Builder(
                builder: (context) {
                  // Rebuild when session expires
                  final expiration = member.sessionRunUntil;
                  if (expiration != null) {
                    final now = DateTime.now();
                    if (expiration.isAfter(now)) {
                      // Note: AnimatedBuilder rebuilds every frame, so we don't need a separate timer here.
                    }
                  }

                  return UniversalAvatar(
                    name: _displayName(context, member),
                    avatarIndex: member.avatarIndex,
                    avatarColorValue: member.avatarColorValue,
                    avatarImageBase64: member.avatarBase64,
                    size: size,
                    fontSize: isFirst ? 40 : 32,
                  );
                },
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
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  AppLocalizations.of(context)!.rankLabel(rank),
                  style: widget.theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (member.userId != widget.currentUserId)
              Positioned(
                bottom: (size + 12) / 2 * (1 - 0.7071) - (buttonSize / 2),
                right: (size + 12) / 2 * (1 - 0.7071) - (buttonSize / 2),
                child: _NudgeHandButton(
                  canReceiveNudges: member.canReceiveNudges,
                  allowsNudges: member.allowsNudges,
                  isCurrentUser: false,
                  size: buttonSize,
                  groupId: widget.groupId,
                  targetUserId: member.userId,
                  onSend: () => widget.onSendNudge(member.userId),
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
                _displayName(context, member),
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: widget.theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatStudyTime(context, member.studyTimeSeconds),
                textAlign: TextAlign.center,
                style: widget.theme.textTheme.labelMedium?.copyWith(
                  color: widget.colorScheme.primary,
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
  final Future<void> Function(String targetUserId) onSendNudge;
  final String groupId;
  final String currentUserId;

  const _RankListTile({
    required this.member,
    required this.rank,
    required this.isCurrentUser,
    required this.onTap,
    required this.onSendNudge,
    required this.groupId,
    required this.currentUserId,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                UniversalAvatar(
                  name: _displayName(context, member),
                  avatarIndex: member.avatarIndex,
                  avatarColorValue: member.avatarColorValue,
                  avatarImageBase64: member.avatarBase64,
                  size: 48,
                  fontSize: 20,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: _UserStatusDot(
                    userId: member.userId,
                    size: 14,
                    isStudyingOverride: member.isStudying,
                    sessionRunUntil: member.sessionRunUntil,
                  ),
                ),
                if (!isCurrentUser)
                  Positioned(
                    bottom: -4,
                    right: -6,
                    child: _NudgeHandButton(
                      canReceiveNudges: member.canReceiveNudges,
                      allowsNudges: member.allowsNudges,
                      isCurrentUser: false,
                      size: 22,
                      groupId: groupId,
                      targetUserId: member.userId,
                      onSend: () => onSendNudge(member.userId),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName(context, member),
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

class _UserStatusDot extends StatefulWidget {
  final String userId;
  final double size;
  final bool? isStudyingOverride;
  final DateTime? sessionRunUntil;

  const _UserStatusDot({
    required this.userId,
    required this.size,
    this.isStudyingOverride,
    this.sessionRunUntil,
  });

  @override
  State<_UserStatusDot> createState() => _UserStatusDotState();
}

class _UserStatusDotState extends State<_UserStatusDot> {
  Timer? _expirationTimer;

  @override
  void initState() {
    super.initState();
    _scheduleExpiration();
  }

  @override
  void didUpdateWidget(covariant _UserStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionRunUntil != widget.sessionRunUntil) {
      _scheduleExpiration();
    }
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  void _scheduleExpiration() {
    _expirationTimer?.cancel();
    final expiration = widget.sessionRunUntil;
    if (expiration != null) {
      final now = DateTime.now();
      if (expiration.isAfter(now)) {
        final duration = expiration.difference(now);
        _expirationTimer = Timer(duration, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  bool get _isLocallyActive {
    if (widget.isStudyingOverride != true) return false;
    final expiration = widget.sessionRunUntil;
    if (expiration == null) {
      return true; // No expiration set, assume active unless stopped
    }
    return DateTime.now().isBefore(expiration);
  }

  @override
  Widget build(BuildContext context) {
    bool isStudying = _isLocallyActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isStudying ? const Color(0xFF4CAF50) : Colors.grey.shade400,
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

  Future<void> _handleTap(
    bool isOnCooldown,
    Duration? remainingCooldown,
  ) async {
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

    setState(() => _sending = true);
    try {
      await widget.onSend();
      if (mounted) {
        showAppMessage(context, l10n.nudgeSent);
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(
          context,
          l10n.failedToSendNudge(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCurrentUser) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final groupService = context.watch<GroupService>();

    return StreamBuilder<DateTime?>(
      stream: groupService.watchNudgeCooldown(
        groupId: widget.groupId,
        targetUserId: widget.targetUserId,
      ),
      builder: (context, snapshot) {
        final lastNudge = snapshot.data;
        Duration? remaining;
        if (lastNudge != null) {
          final end = lastNudge.add(const Duration(hours: 1));
          final now = DateTime.now();
          if (end.isAfter(now)) {
            remaining = end.difference(now);
          }
        }

        final isOnCooldown = remaining != null && remaining.inSeconds > 0;

        return GestureDetector(
          onTap: () => _handleTap(isOnCooldown, remaining),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: isOnCooldown
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: _sending
                  ? SizedBox(
                      width: widget.size * 0.6,
                      height: widget.size * 0.6,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isOnCooldown
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: widget.size * 0.75,
                          height: widget.size * 0.75,
                          child: CircularProgressIndicator(
                            value: remaining.inSeconds / 3600.0,
                            strokeWidth: 2,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          remaining.inMinutes > 0
                              ? '${remaining.inMinutes}m'
                              : '${remaining.inSeconds}s',
                          style: TextStyle(
                            fontSize: widget.size * 0.28,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    )
                  : Text('👋', style: TextStyle(fontSize: widget.size * 0.6)),
            ),
          ),
        );
      },
    );
  }
}

String _periodLabel(BuildContext context, StatisticsPeriod period) {
  final l10n = AppLocalizations.of(context)!;
  return switch (period) {
    StatisticsPeriod.today => l10n.today,
    StatisticsPeriod.last7Days => l10n.week,
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
