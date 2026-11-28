import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'group_style_pickers.dart';

class GroupEditorCard extends StatelessWidget {
  const GroupEditorCard({
    super.key,
    required this.focus,
    required this.title,
    required this.controller,
    required this.color,
    required this.icon,
    required this.onColor,
    required this.onIcon,
    required this.onCancel,
    required this.onSave,
    this.hint,
  });

  final NumerSheetFocusMode focus;
  final String title;
  final String? hint;
  final TextEditingController controller;
  final Color color;
  final IconData icon;
  final ValueChanged<Color> onColor;
  final ValueChanged<IconData> onIcon;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chrome = focus.hidesChrome;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumerFocusFold(
            hidden: chrome,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _nameField(context),
          const SizedBox(height: 16),
          NumerFocusFold(hidden: chrome, child: _style(context)),
          _actions(context),
        ],
      ),
    );
  }

  Widget _nameField(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focus.nodeFor('name'),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.groupNameLabel,
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      autofocus: true,
      inputFormatters: [LengthLimitingTextInputFormatter(32)],
    );
  }

  Widget _style(BuildContext context) {
    final labels = Theme.of(context).textTheme.labelMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppLocalizations.of(context)!.color, style: labels),
        const SizedBox(height: 8),
        GroupColorPicker(selected: color, onSelected: onColor),
        const SizedBox(height: 16),
        Text('Icon', style: labels),
        const SizedBox(height: 8),
        GroupIconPicker(selected: icon, color: color, onSelected: onIcon),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        if (!focus.hidesChrome)
          TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
        const Spacer(),
        // follows the text, or the button stays disabled while the name is typed
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => FilledButton(
            onPressed: controller.text.trim().isEmpty ? null : onSave,
            child: Text(l10n.save),
          ),
        ),
      ],
    );
  }
}
