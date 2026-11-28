import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import 'habit_input_decoration.dart';

class NumericTargetFields extends StatelessWidget {
  final NumerSheetFocusMode focus;
  final TextEditingController targetController;
  final TextEditingController unitController;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onUnitChanged;

  const NumericTargetFields({
    super.key,
    required this.focus,
    required this.targetController,
    required this.unitController,
    required this.onTargetChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // keyed, so the field that stays keeps its element when the other leaves
        if (!focus.hides('target'))
          Expanded(
            key: const ValueKey('target'),
            child: _targetField(theme, l10n),
          ),
        if (!focus.hidesChrome) const SizedBox(width: 12),
        if (!focus.hides('unit'))
          Expanded(key: const ValueKey('unit'), child: _unitField(theme, l10n)),
      ],
    );
  }

  Widget _targetField(ThemeData theme, AppLocalizations l10n) {
    return TextFormField(
      focusNode: focus.nodeFor('target'),
      controller: targetController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => focus.moveTo('unit'),
      decoration: habitInputDecoration(
        theme,
        radius: 16,
        labelText: l10n.habitValueLabel,
      ),
      onChanged: onTargetChanged,
      inputFormatters: [
        LengthLimitingTextInputFormatter(5),
        FilteringTextInputFormatter.digitsOnly,
      ],
    );
  }

  Widget _unitField(ThemeData theme, AppLocalizations l10n) {
    return TextFormField(
      focusNode: focus.nodeFor('unit'),
      controller: unitController,
      textInputAction: TextInputAction.done,
      decoration: habitInputDecoration(
        theme,
        radius: 16,
        labelText: l10n.habitUnitLabel,
        hintText: l10n.habitUnitHint,
      ),
      onChanged: onUnitChanged,
      inputFormatters: [
        LengthLimitingTextInputFormatter(16),
        FilteringTextInputFormatter.allow(
          RegExp(r"[\p{L}\p{N}\s'\-]", unicode: true),
        ),
      ],
    );
  }
}
