import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:numer_app/l10n/app_localizations.dart';

class PresetNamingRow extends StatelessWidget {
  const PresetNamingRow({
    super.key,
    required this.color,
    required this.controller,
    required this.formKey,
    required this.focusNode,
    required this.showActions,
    required this.onCancel,
    required this.onConfirm,
  });

  final Color color;
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final FocusNode focusNode;

  // while typing the sheet shows one save button instead
  final bool showActions;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Form(key: formKey, child: _field(context)),
          ),
          if (showActions) ..._actions(context),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: onCancel,
        visualDensity: VisualDensity.compact,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      IconButton(
        icon: const Icon(Icons.check, size: 20),
        onPressed: onConfirm,
        visualDensity: VisualDensity.compact,
        color: color,
      ),
    ];
  }

  Widget _field(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.presetName,
        isDense: true,
        border: InputBorder.none,
        counterText: "",
        contentPadding: EdgeInsets.zero,
      ),
      maxLength: 16,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\p{L} ]', unicode: true)),
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.startsWith(' ')) {
            return oldValue;
          }
          return newValue;
        }),
      ],
      validator: _validate,
      onFieldSubmitted: (_) => onConfirm(),
    );
  }

  // an empty message keeps the error subtle
  String? _validate(String? v) {
    if (v == null || v.isEmpty) return "";
    if (v.startsWith(' ')) return "";
    if (!RegExp(r'^[\p{L} ]+$', unicode: true).hasMatch(v)) return "";
    return null;
  }
}
