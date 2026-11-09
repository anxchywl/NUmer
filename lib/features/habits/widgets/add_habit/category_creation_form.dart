import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'category_color_row.dart';
import 'category_icon_row.dart';

class CategoryCreationForm extends StatelessWidget {
  final Color color;
  final IconData icon;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<IconData> onIconChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const CategoryCreationForm({
    super.key,
    required this.color,
    required this.icon,
    required this.onNameChanged,
    required this.onColorChanged,
    required this.onIconChanged,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: l10n.habitCategoryNameLabel,
            hintText: l10n.habitCategoryNameHint,
          ),
          onChanged: onNameChanged,
          autofocus: true,
          inputFormatters: [
            LengthLimitingTextInputFormatter(32),
            FilteringTextInputFormatter.allow(
              RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        CategoryColorRow(selected: color, onSelected: onColorChanged),
        const SizedBox(height: 16),
        CategoryIconRow(
          selected: icon,
          color: color,
          onSelected: onIconChanged,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            TextButton(onPressed: onBack, child: Text(l10n.habitBack)),
            const Spacer(),
            FilledButton(onPressed: onSave, child: Text(l10n.save)),
          ],
        ),
      ],
    );
  }
}
