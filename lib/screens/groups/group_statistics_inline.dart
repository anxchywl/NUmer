import 'package:flutter/material.dart';

import 'group_statistics_screen.dart';

class GroupStatisticsInline extends StatelessWidget {
  final String groupId;
  final String currentUserId;

  const GroupStatisticsInline({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: const Text('Group statistics'),
          subtitle: const Text('Tap to view detailed statistics'),
          trailing: IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GroupStatisticsScreen(
                  groupId: groupId,
                  groupName: groupId,
                  currentUserId: currentUserId,
                ),
              ));
            },
          ),
        ),
      ),
    );
  }
}
