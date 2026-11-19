import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class AddHabitExtrasStep extends StatelessWidget {
  final Key navKey;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onPickStart;
  final VoidCallback onToggleEnd;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const AddHabitExtrasStep({
    super.key,
    required this.navKey,
    required this.startDate,
    required this.endDate,
    required this.isEditing,
    required this.isSaving,
    required this.onPickStart,
    required this.onToggleEnd,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- Step 4: When? --
        Text(l10n.habitChooseTimeRangeTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 16),

        _startTile(l10n),
        const Divider(),
        _endTile(l10n),

        const SizedBox(height: 32),

        // Navigation & Create
        _navigation(l10n),
      ],
    );
  }

  Widget _startTile(AppLocalizations l10n) {
    return ListTile(
      title: Text(l10n.habitStartDateLabel),
      subtitle: Text(DateFormat.yMMMd(l10n.localeName).format(startDate)),
      trailing: const Icon(Icons.calendar_today),
      onTap: isEditing ? null : onPickStart,
    );
  }

  Widget _endTile(AppLocalizations l10n) {
    return ListTile(
      title: Text(l10n.habitEndDateLabel),
      subtitle: Text(
        endDate == null
            ? l10n.habitNoEndDate
            : DateFormat.yMMMd(l10n.localeName).format(endDate!),
      ),
      trailing: endDate == null
          ? const Icon(Icons.add)
          : const Icon(Icons.close),
      onTap: isEditing ? null : onToggleEnd,
    );
  }

  Widget _navigation(AppLocalizations l10n) {
    return Row(
      key: navKey,
      children: [
        TextButton(onPressed: onBack, child: Text(l10n.habitBack)),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: isSaving ? null : onSubmit,
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.habitCreateAction),
          ),
        ),
      ],
    );
  }
}
