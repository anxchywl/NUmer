import 'package:flutter/material.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/features/stats/stats.dart';

class ShellTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  const ShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}

List<ShellTab> buildShellTabs(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return <ShellTab>[
    ShellTab(
      label: l10n.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      builder: (_) => const HomeScreen(),
    ),
    ShellTab(
      label: l10n.habitsNavLabel,
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
      builder: (_) => const HabitsScreen(),
    ),
    ShellTab(
      label: l10n.statistics,
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      builder: (_) => const StatsScreen(),
    ),
    // connections is built but intentionally hidden, add its ShellTab here to enable it
    ShellTab(
      label: l10n.groups,
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
      builder: (_) => const GroupsScreen(),
    ),
    ShellTab(
      label: l10n.account,
      icon: Icons.person_outline,
      selectedIcon: Icons.settings,
      builder: (_) => const SettingsScreen(),
    ),
  ];
}
