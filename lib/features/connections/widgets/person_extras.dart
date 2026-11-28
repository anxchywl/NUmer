import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../models/contact_group.dart';

class PersonGroupPicker extends StatelessWidget {
  const PersonGroupPicker({
    super.key,
    required this.groups,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<ContactGroup> groups;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context)!.groupsLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Text(
            'No groups yet. Create one in group management.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: groups.map(_chip).toList()),
      ],
    );
  }

  Widget _chip(ContactGroup group) {
    final isSelected = selectedIds.contains(group.id);
    return FilterChip(
      label: Text(group.name),
      selected: isSelected,
      selectedColor: group.color.withAlpha(51),
      avatar: isSelected
          ? null
          : CircleAvatar(
              backgroundColor: group.color.withAlpha(51),
              child: Icon(group.icon, size: 14, color: group.color),
            ),
      onSelected: (selected) => onChanged(group.id, selected),
    );
  }
}

class PersonContactOptions extends StatelessWidget {
  const PersonContactOptions({
    super.key,
    required this.lastContactedAt,
    required this.remind,
    required this.onPickDate,
    required this.onClearDate,
  });

  final DateTime? lastContactedAt;
  final bool remind;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _lastContacted(context),
        const SizedBox(height: 12),
        _reminder(context),
      ],
    );
  }

  Widget _lastContacted(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = lastContactedAt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.calendar_today_outlined, color: colorScheme.primary),
      title: Text(AppLocalizations.of(context)!.lastContactedLabel),
      subtitle: Text(
        date != null ? DateFormat.yMMMd().format(date) : 'Not set',
        style: TextStyle(
          color: date != null
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (date != null)
            IconButton(icon: const Icon(Icons.clear), onPressed: onClearDate),
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            onPressed: onPickDate,
          ),
        ],
      ),
    );
  }

  // disabled until reminders exist
  Widget _reminder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(AppLocalizations.of(context)!.remindMeLabel),
      subtitle: Text(
        'Coming soon',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      value: remind,
      onChanged: null,
      secondary: Icon(
        Icons.notifications_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
