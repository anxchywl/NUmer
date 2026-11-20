import 'package:flutter/material.dart';

import 'package:numer_app/l10n/app_localizations.dart';

class CourseTimeTabBar extends StatelessWidget {
  const CourseTimeTabBar({
    super.key,
    required this.controller,
    required this.isCondensed,
  });

  final TabController controller;
  final bool isCondensed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTextTabBarHeight,
      width: double.infinity,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        firstCurve: Curves.easeInOut,
        secondCurve: Curves.easeInOut,
        crossFadeState: isCondensed
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: _condensedTab(context),
        secondChild: _tabs(context),
      ),
    );
  }

  Widget _condensedTab(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => controller.animateTo(0),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: const StadiumBorder(),
        ),
        child: Text(
          AppLocalizations.of(context)!.timerTab,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Align(
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
    );
  }
}
