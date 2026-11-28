import 'package:flutter/material.dart';

import 'package:numer_app/l10n/app_localizations.dart';

class CourseTimeTabBar extends StatelessWidget {
  const CourseTimeTabBar({super.key, required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTextTabBarHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.center,
        child: TabBar(
          controller: controller,
          labelColor: Theme.of(context).colorScheme.onSurface,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.timerTab),
            Tab(text: AppLocalizations.of(context)!.stopwatchTab),
            Tab(text: AppLocalizations.of(context)!.pomodoroTab),
          ],
        ),
      ),
    );
  }
}
