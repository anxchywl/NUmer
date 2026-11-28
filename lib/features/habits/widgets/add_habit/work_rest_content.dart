import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import 'compact_number_field.dart';

class WorkRestContent extends StatelessWidget {
  final NumerSheetFocusMode focus;
  final TextEditingController workController;
  final TextEditingController restController;
  final ValueChanged<String> onWorkChanged;
  final ValueChanged<String> onRestChanged;

  const WorkRestContent({
    super.key,
    required this.focus,
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
        NumerFocusFold(
          hidden: focus.hidesChrome,
          animateSize: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.habitFrequencyWorkRestDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        _inputs(l10n),
      ],
    );
  }

  Widget _inputs(AppLocalizations l10n) {
    final work = !focus.hides('work');
    final rest = !focus.hides('rest');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Visibility(visible: work, child: Text("${l10n.habitWorkLabel} ")),
        Visibility(visible: work, child: _workField()),
        Visibility(visible: !focus.hidesChrome, child: _times()),
        Visibility(visible: rest, child: _restField()),
        Visibility(visible: rest, child: Text(" ${l10n.habitRestLabel}")),
      ],
    );
  }

  Widget _times() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text("×"),
    );
  }

  Widget _workField() {
    return CompactNumberField(
      fieldKey: const ValueKey('work_days_input'),
      width: 60,
      focusNode: focus.nodeFor('work'),
      controller: workController,
      hintText: "0",
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => focus.moveTo('rest'),
      onChanged: onWorkChanged,
    );
  }

  Widget _restField() {
    return CompactNumberField(
      fieldKey: const ValueKey('rest_days_input'),
      width: 60,
      focusNode: focus.nodeFor('rest'),
      controller: restController,
      hintText: "0",
      onChanged: onRestChanged,
    );
  }
}
