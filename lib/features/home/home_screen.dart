import 'package:flutter/material.dart';

import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/sessions/sessions.dart';

import 'streak_title.dart';
import 'sync_status_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  double _iosBottomNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const navHeight = 66.0;
    const extra = 8.0;
    return navHeight + navBottomOffset + extra;
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const ShellHeader(title: StreakTitle(), actions: [SyncStatusChip()]),
          const SliverToBoxAdapter(
            child: Column(
              children: [
                FirstRunCreditsGate(),
                AutoFinishWatcher(),
                ActiveSessionBar(),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: isIos
                  ? _iosBottomNavClearance(context)
                  : MediaQuery.of(context).padding.bottom + 80,
            ),
          ),
        ],
      ),
    );
  }
}
