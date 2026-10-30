import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:numer_app/app/shell/shell_tabs.dart';

// model for a single item in the ios-style bottom navigation bar
class _IosNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _IosNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class IosTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ShellTab> tabs;

  const IosTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final items = tabs
        .map(
          (tab) => _IosNavItem(
            label: tab.label,
            icon: tab.icon,
            selectedIcon: tab.selectedIcon,
          ),
        )
        .toList();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const barHeight = 66.0;
    const horizontalMargin = 14.0;
    const bottomSpacing = 2.0;
    const innerPadding = 8.0;
    const highlightInset = 4.0;
    final overlayHeight = barHeight + bottomSpacing + bottomInset;
    return SizedBox(
      height: overlayHeight,
      child: Stack(
        children: [
          Positioned(
            left: horizontalMargin,
            right: horizontalMargin,
            bottom: barBottomOffset,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth =
                    (constraints.maxWidth - innerPadding * 2) / items.length;
                final activeWidth = slotWidth + 12;
                final activeLeft =
                    innerPadding +
                    currentIndex * slotWidth +
                    ((slotWidth - activeWidth) / 2);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: SizedBox(
                    height: barHeight,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          left: activeLeft,
                          top: highlightInset,
                          width: activeWidth,
                          height: barHeight - (highlightInset * 2),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.09 : 0.24,
                                    ),
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.05 : 0.16,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.transparent),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: innerPadding,
                          ),
                          child: Row(
                            children: List.generate(items.length, (i) {
                              final selected = currentIndex == i;
                              final item = items[i];
                              return Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => onTap(i),
                                  child: SizedBox(
                                    height: barHeight,
                                    child: AnimatedScale(
                                      scale: selected ? 1.08 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            selected
                                                ? item.selectedIcon
                                                : item.icon,
                                            size: selected ? 24 : 20,
                                            color: selected
                                                ? scheme.primary
                                                : scheme.onSurface.withValues(
                                                    alpha: 0.72,
                                                  ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: selected
                                                      ? 12.0
                                                      : 11.0,
                                                  color: selected
                                                      ? scheme.primary
                                                      : scheme.onSurface
                                                            .withValues(
                                                              alpha: 0.74,
                                                            ),
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
