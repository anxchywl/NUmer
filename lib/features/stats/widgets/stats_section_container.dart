import 'package:flutter/material.dart';

class StatsSectionContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final bool useCard;
  final Widget? trailingHeader;

  const StatsSectionContainer({
    super.key,
    required this.title,
    required this.child,
    this.useCard = true,
    this.trailingHeader,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              ?trailingHeader,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: useCard
              ? Container(
                  clipBehavior: Clip.none,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: child,
                )
              : child,
        ),
      ],
    );
  }
}
