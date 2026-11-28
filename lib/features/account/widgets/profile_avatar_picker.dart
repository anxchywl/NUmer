import 'package:flutter/material.dart';

import 'package:numer_app/features/account/models/profile_avatar.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/color_picker_button.dart';

class ProfileAvatarChip extends StatelessWidget {
  const ProfileAvatarChip({
    super.key,
    required this.option,
    required this.backgroundColor,
    required this.selected,
    required this.onTap,
  });

  final ProfileAvatarOption option;
  final Color backgroundColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark =
        ThemeData.estimateBrightnessForColor(backgroundColor) ==
        Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final borderColor = selected
        ? backgroundColor
        : Theme.of(context).colorScheme.outlineVariant;

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: selected ? 1.05 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor.withAlpha(
              ((selected ? 1 : 0.7) * 255).round(),
            ),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: selected ? 3 : 1),
          ),
          child: Icon(option.icon, color: iconColor),
        ),
      ),
    );
  }
}

class ProfileColorChooser extends StatefulWidget {
  final int? selectedColorValue;
  final ValueChanged<int?> onColorChanged;

  const ProfileColorChooser({
    super.key,
    required this.selectedColorValue,
    required this.onColorChanged,
  });

  @override
  State<ProfileColorChooser> createState() => _ProfileColorChooserState();
}

class _ProfileColorChooserState extends State<ProfileColorChooser> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.iconColor,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        CustomColorPicker(
          initial: widget.selectedColorValue != null
              ? Color(widget.selectedColorValue!)
              : Colors.grey,
          onChanged: (c) => widget.onColorChanged(c.toARGB32()),
        ),
      ],
    );
  }
}
