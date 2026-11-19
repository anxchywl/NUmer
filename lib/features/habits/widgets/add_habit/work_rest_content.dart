import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'compact_number_field.dart';

class WorkRestContent extends StatelessWidget {
  final FocusNode workFocus;
  final FocusNode restFocus;
  final TextEditingController workController;
  final TextEditingController restController;
  final ValueChanged<String> onWorkChanged;
  final ValueChanged<String> onRestChanged;

  const WorkRestContent({
    super.key,
    required this.workFocus,
    required this.restFocus,
    required this.workController,
    required this.restController,
    required this.onWorkChanged,
    required this.onRestChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.habitFrequencyWorkRestDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _inputs(l10n),
      ],
    );
  }

  Widget _inputs(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("${l10n.habitWorkLabel} "),
        CompactNumberField(
          fieldKey: const ValueKey('work_days_input'),
          width: 60,
          focusNode: workFocus,
          controller: workController,
          hintText: "0",
          onChanged: onWorkChanged,
        ),
        const SizedBox(width: 12),
        const Text("×"),
        const SizedBox(width: 12),
        CompactNumberField(
          fieldKey: const ValueKey('rest_days_input'),
          width: 60,
          focusNode: restFocus,
          controller: restController,
          hintText: "0",
          onChanged: onRestChanged,
        ),
        Text(" ${l10n.habitRestLabel}"),
      ],
    );
  }
}
