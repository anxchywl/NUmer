import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/group_statistics.dart';
import '../../../services/group_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/universal_avatar.dart';
import '../../../widgets/app_toast.dart';

class UserSubjectsBottomSheet extends StatefulWidget {
  final String groupId;
  final String userId;
  final String name;
  final int avatarColorValue;
  final StatisticsPeriod period;
  final MemberSubjectStats? preloadedStats;
  final bool shouldRefresh;

  const UserSubjectsBottomSheet({
    super.key,
    required this.groupId,
    required this.userId,
    required this.name,
    required this.avatarColorValue,
    required this.period,
    this.preloadedStats,
    this.shouldRefresh = true,
  });

  @override
  State<UserSubjectsBottomSheet> createState() => _UserSubjectsBottomSheetState();
}

class _UserSubjectsBottomSheetState extends State<UserSubjectsBottomSheet> {
  late Stream<MemberSubjectStats> _statsStream;
  late bool _isUpdating;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    final groupService = context.read<GroupService>();
    final stale = widget.shouldRefresh ||
        groupService.isMemberStatsStale(
          groupId: widget.groupId,
          userId: widget.userId,
          period: widget.period,
        );
    _isUpdating = stale;

    // Initialize stream for delta sync
    _statsStream = groupService.watchMemberStats(
      groupId: widget.groupId,
      targetUserId: widget.userId,
      period: widget.period,
      forceRefresh: stale,
      onDeltaApplied: () {
        if (!mounted) return;
        setState(() {
          _isUpdating = false;
        });
      },
    );
    
    // Load profile from cache then fetch fresh if stale
    _loadProfile(groupService);
  }
  
  Future<void> _loadProfile(GroupService groupService) async {
    // 1. Show cached profile instantly
    final cached = await groupService.getCachedMemberProfile(
      groupId: widget.groupId,
      userId: widget.userId,
    );
    if (cached != null && mounted) {
      setState(() {
        _profileData = cached;
      });
    }
    
    // 2. Check if stale and fetch fresh
    final isStale = groupService.isMemberProfileStale(
      groupId: widget.groupId,
      userId: widget.userId,
    );
    if (isStale || cached == null) {
      final fresh = await groupService.fetchAndCacheMemberProfile(
        groupId: widget.groupId,
        userId: widget.userId,
      );
      if (fresh != null && mounted) {
        setState(() {
          _profileData = fresh;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UniversalAvatar(
                  userId: widget.userId,
                  name: widget.name,
                  initialAvatarColorValue: widget.avatarColorValue,
                  size: 56,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final data = _profileData;
                      final major = data?['major'] as String?;
                      final goal = data?['profileGoal'] as String?;
                      final contact = data?['profileContact'] as String?;
                      final hasMajor = major != null && major.isNotEmpty;
                      final hasGoal = goal != null && goal.isNotEmpty;
                      final hasContact = contact != null && contact.isNotEmpty;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            softWrap: true,
                          ),
                          if (hasMajor)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                major,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                softWrap: true,
                              ),
                            ),
                          if (hasGoal)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                goal,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                                softWrap: true,
                              ),
                            ),
                          if (hasContact)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: contact));
                                  showAppMessage(context, AppLocalizations.of(context)!.copiedToClipboard);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                  child: Text(
                                    contact,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                StreamBuilder<MemberSubjectStats>(
                  stream: _statsStream,
                  initialData: widget.preloadedStats,
                  builder: (context, snapshot) {
                     final stats = snapshot.data;
                     if (stats == null) return const SizedBox.shrink();

                     return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatSeconds(stats.totalSeconds),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
          if (_isUpdating)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updating...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          
          Flexible(
            child: StreamBuilder<MemberSubjectStats>(
              stream: _statsStream,
              initialData: widget.preloadedStats,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.failedToLoadUserData(snapshot.error.toString()),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final stats = snapshot.data;
                if (stats == null || stats.subjectStats.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.noDataAvailable,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                final subjects = stats.subjectStats.values
                    .where((s) => s.seconds > 0)
                    .toList()
                  ..sort((a, b) => b.seconds.compareTo(a.seconds));

                if (subjects.isEmpty) {
                   return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.noDataAvailable,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  itemCount: subjects.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    final seconds = subject.seconds;
                    final percentage = stats.totalSeconds > 0
                        ? (seconds / stats.totalSeconds)
                        : 0.0;

                    return Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(subject.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                  color: Color(subject.colorValue),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _formatSeconds(seconds),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    if (!mounted) return '';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
