import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:numer_app/models/group_statistics.dart';
import 'package:numer_app/services/group_service.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/widgets/universal_avatar.dart';
import 'package:numer_app/widgets/app_toast.dart';

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

  StreamSubscription? _profileSubscription;

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
    
    // Watch profile changes in real-time
    _watchProfile();
  }
  
  void _watchProfile() {
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _profileData = {
           'major': data['major'],
           'profileGoal': data['profileGoal'],
           'profileContact': data['profileContact'],
          };
        });
      }
    });
  }
  
  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine max height dynamically
    return StreamBuilder<MemberSubjectStats>(
      stream: _statsStream,
      initialData: widget.preloadedStats,
      builder: (context, snapshot) {
        final hasData = snapshot.hasData && 
                        snapshot.data != null && 
                        snapshot.data!.subjectStats.isNotEmpty;
                        
        final maxHeight = MediaQuery.of(context).size.height * (hasData ? 0.8 : 0.5);

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
                    color: colorScheme.onSurfaceVariant.withAlpha(theme.brightness == Brightness.dark ? 120 : 60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
                Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    UniversalAvatar(
                      userId: widget.userId,
                      name: widget.name,
                      initialAvatarColorValue: widget.avatarColorValue,
                      size: 64,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Info Section (No Icons)
                          Builder(
                            builder: (context) {
                              final data = _profileData;
                              final major = data?['major'] as String?;
                              final goal = data?['profileGoal'] as String?;
                              final contact = data?['profileContact'] as String?;
                              
                              if (data == null && _isUpdating) return const SizedBox.shrink();
                              
                              final hasMajor = major != null && major.isNotEmpty;
                              final hasGoal = goal != null && goal.isNotEmpty;
                              final hasContact = contact != null && contact.isNotEmpty;

                              if (!hasMajor && !hasGoal && !hasContact) return const SizedBox.shrink();

                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     if (hasMajor)
                                       Text(
                                         major,
                                         style: theme.textTheme.bodyMedium?.copyWith(
                                           color: colorScheme.onSurfaceVariant,
                                           fontWeight: FontWeight.w500,
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     if (hasGoal)
                                       Text(
                                         goal,
                                         style: theme.textTheme.bodySmall?.copyWith(
                                           color: colorScheme.onSurfaceVariant,
                                           fontStyle: FontStyle.italic,
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     if (hasContact)
                                       InkWell(
                                         onTap: () {
                                            Clipboard.setData(ClipboardData(text: contact));
                                            showAppMessage(context, AppLocalizations.of(context)!.copiedToClipboard);
                                         },
                                         child: Text(
                                           contact,
                                           style: theme.textTheme.bodySmall?.copyWith(
                                             color: colorScheme.primary,
                                             fontWeight: FontWeight.w600,
                                           ),
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                         ),
                                       ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
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
                child: Builder( // Used to be StreamBuilder, now handled by outer loop but we kept logic structure
                  builder: (context) {
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
                      itemCount: subjects.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Total Time Header - CENTERED
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                 '${AppLocalizations.of(context)!.total}: ${_formatSeconds(stats.totalSeconds)}',
                                 style: theme.textTheme.titleSmall?.copyWith(
                                   color: colorScheme.onSurfaceVariant,
                                   fontWeight: FontWeight.bold,
                                   fontFeatures: [const FontFeature.tabularFigures()],
                                 ),
                              ),
                            ),
                          );
                        }
                        
                        final subject = subjects[index - 1];

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
  },
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
