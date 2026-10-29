import 'package:flutter/material.dart';

import 'package:numer_app/app/shell/shell_tabs.dart';

class AndroidTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ShellTab> tabs;

  const AndroidTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = tabs
        .map(
          (tab) => NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
        )
        .toList();
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 64,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.4),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final theme = Theme.of(context);
          if (states.contains(WidgetState.selected)) {
            return theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final theme = Theme.of(context);
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: theme.colorScheme.primary, size: 26);
          }
          return IconThemeData(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            size: 24,
          );
        }),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        selectedIndex: currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: destinations,
        onDestinationSelected: onTap,
      ),
    );
  }
}
