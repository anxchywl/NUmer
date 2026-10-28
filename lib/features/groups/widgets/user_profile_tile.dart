import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/groups/data/public_profile_source.dart';
import 'package:numer_app/features/groups/models/public_profile.dart';
import 'package:numer_app/l10n/app_localizations.dart';

// list tile that streams a member's public profile (avatar, name, major/goal)
class UserProfileTile extends StatefulWidget {
  const UserProfileTile({
    super.key,
    required this.userId,
    this.subtitle,
    this.trailing,
    this.showOnlyMajor = false,
  });

  final String userId;
  final Widget? subtitle;
  final Widget? trailing;
  final bool showOnlyMajor;

  @override
  State<UserProfileTile> createState() => _UserProfileTileState();
}

class _UserProfileTileState extends State<UserProfileTile> {
  late Stream<PublicProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = _watchProfile();
  }

  @override
  void didUpdateWidget(UserProfileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _profileStream = _watchProfile();
  }

  Stream<PublicProfile?> _watchProfile() =>
      context.read<PublicProfileSource>().watch(widget.userId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.hasError ? null : snapshot.data;
        final profileName = profile?.profileName ?? '';
        final name = profileName.isEmpty
            ? AppLocalizations.of(context)!.memberFallbackName
            : profileName;

        return ListTile(
          leading: UniversalAvatar(
            name: name,
            avatarIndex: profile?.avatarIndex,
            avatarColorValue: profile?.avatarColorValue,
            avatarImageBase64: profile?.avatarImageBase64,
            size: 48,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  softWrap: true,
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
            ],
          ),
          subtitle: _buildSubtitle(profile),
          trailing: widget.trailing,
        );
      },
    );
  }

  // composes major, goal and any custom subtitle, or null when there is nothing to show
  Widget? _buildSubtitle(PublicProfile? profile) {
    if (profile == null) return widget.subtitle;

    final major = profile.major;
    final goal = profile.profileGoal;
    final subtitle = widget.subtitle;
    final hasGoal = goal != null && goal.isNotEmpty;
    final hasMajor = major != null && major.isNotEmpty;

    if (!hasGoal && !hasMajor && subtitle == null) {
      return null;
    }

    if (widget.showOnlyMajor) {
      if (hasMajor) {
        return Text(major, softWrap: true);
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMajor) Text(major, softWrap: true),
        if (hasGoal) Text(goal, softWrap: true),
        ?subtitle,
      ],
    );
  }
}
