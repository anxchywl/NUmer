import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'habit_input_decoration.dart';

class NumericTargetFields extends StatelessWidget {
  final FocusNode targetFocus;
  final FocusNode unitFocus;
  final TextEditingController targetController;
  final TextEditingController unitController;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onUnitChanged;

  const NumericTargetFields({
    super.key,
    required this.targetFocus,
    required this.unitFocus,
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
        Expanded(
          child: TextFormField(
            focusNode: targetFocus,
            controller: targetController,
            keyboardType: TextInputType.number,
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
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            focusNode: unitFocus,
            controller: unitController,
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
          ),
        ),
      ],
    );
  }
}
