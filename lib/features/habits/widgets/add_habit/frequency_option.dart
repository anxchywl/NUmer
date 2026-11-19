import 'package:flutter/material.dart';

class FrequencyOption extends StatelessWidget {
  final String title;
  final bool selected;
  final bool disabled;
  final VoidCallback onSelect;
  final Widget child;

  const FrequencyOption({
    super.key,
    required this.title,
    required this.selected,
    required this.disabled,
    required this.onSelect,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(onTap: disabled ? null : onSelect, child: _tile(theme)),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: selected
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                    left: 16,
                    bottom: 8,
                  ), // Indent content below
                  child: child,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _tile(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : (disabled
                  ? theme.colorScheme.surfaceContainerHighest.withAlpha(20)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(50)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
