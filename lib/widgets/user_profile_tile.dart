import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:numer_app/widgets/universal_avatar.dart';

class UserProfileTile extends StatelessWidget {
  const UserProfileTile({
    super.key, 
    required this.userId,
    this.role,
    this.subtitle,
    this.trailing,
    this.showOnlyMajor = false,
  });

  final String userId;
  final String? role;
  final Widget? subtitle;
  final Widget? trailing;
  final bool showOnlyMajor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _fallbackTile(context, showSpinner: false);
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return _fallbackTile(context, showSpinner: !snapshot.hasError && !snapshot.hasData);
        }

        final profileName = data['profileName'] as String?;
        final displayName = data['displayName'] as String?;
        final major = data['major'] as String?;
        final goal = data['profileGoal'] as String?;

        return ListTile(
          leading: UniversalAvatar(
            userId: userId,
            name: profileName ?? displayName,
            size: 48,
          ),
          title: Text(
            profileName ?? displayName ?? 'Anonymous User',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            softWrap: true,
          ),
          subtitle: _buildSubtitle(goal, major, subtitle, context),
          trailing: trailing,
        );
      },
    );
  }

  Widget _fallbackTile(BuildContext context, {required bool showSpinner}) {
    return ListTile(
      leading: UniversalAvatar(
        userId: userId,
        name: userId,
        size: 48,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              role == null ? 'Member' : 'Member · ${role!}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (showSpinner)
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
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  Widget? _buildSubtitle(String? goal, String? major, Widget? subtitle, BuildContext context) {
    final hasGoal = goal != null && goal.isNotEmpty;
    final hasMajor = major != null && major.isNotEmpty;
    final hasCustomSubtitle = subtitle != null;

    if (!hasGoal && !hasMajor && !hasCustomSubtitle) {
      return null;
    }

    if (showOnlyMajor) {
      if (hasMajor) {
        return Text(major, softWrap: true);
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMajor)
          Text(major, softWrap: true),
        if (hasGoal)
          Text(goal, softWrap: true),
        if (hasCustomSubtitle)
          subtitle,
      ],
    );
  }
}
