import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/app/modules/module_registry.dart';
import 'package:numer_app/app/modules/open_module.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/campus/campus.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/features/study/study.dart';

enum ShellDestination { home, habits, study, groups, campus }

class ShellTab {
  final ShellDestination destination;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  const ShellTab({
    required this.destination,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}

List<ShellTab> buildShellTabs(
  BuildContext context, {
  required void Function(ShellDestination) onSelect,
  List<ModuleDescriptor> registry = moduleRegistry,
}) {
  final l10n = AppLocalizations.of(context)!;
  final config = context.watch<AppConfigService>();
  final uid = context.watch<AuthController>().currentUser?.uid ?? '';
  List<ModuleDescriptor> modulesIn(ModuleSection section) =>
      visibleModules(section, config, uid, registry: registry);
  final studyModules = modulesIn(ModuleSection.study);
  final campusModules = modulesIn(ModuleSection.campus);
  return <ShellTab>[
    ShellTab(
      destination: ShellDestination.home,
      label: l10n.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      builder: (_) => HomeScreen(
        onOpenStudy: () => onSelect(ShellDestination.study),
        onOpenHabits: () => onSelect(ShellDestination.habits),
        openUpcoming: openNoUpcomingItem,
      ),
    ),
    ShellTab(
      destination: ShellDestination.habits,
      label: l10n.habitsNavLabel,
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
      builder: (_) => const HabitsScreen(),
    ),
    ShellTab(
      destination: ShellDestination.study,
      label: l10n.navStudy,
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      builder: (context) => StudyScreen(
        modules: studyModules,
        onOpenModule: (module) => openModule(context, module),
      ),
    ),
    // connections is built but intentionally hidden, add its ShellTab here to enable it
    ShellTab(
      destination: ShellDestination.groups,
      label: l10n.groups,
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
      builder: (_) => const GroupsScreen(),
    ),
    if (campusModules.isNotEmpty)
      ShellTab(
        destination: ShellDestination.campus,
        label: l10n.navCampus,
        icon: Icons.apartment_outlined,
        selectedIcon: Icons.apartment,
        builder: (context) => CampusScreen(
          modules: campusModules,
          onOpen: (module) => openModule(context, module),
        ),
      ),
  ];
}
