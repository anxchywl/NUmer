import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'settings_heading.dart';

class SettingsSwitchesSection extends StatelessWidget {
  const SettingsSwitchesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwitchCard(
          icon: Icons.notes_rounded,
          title: l10n.quickNotes,
          subtitle: l10n.quickNotesDescription,
          value: state.quickNotesEnabled,
          onChanged: state.setQuickNotesEnabled,
        ),
        const SizedBox(height: 16),
        _SwitchCard(
          icon: Icons.notifications_active_rounded,
          title: l10n.wantToReceiveNudges,
          subtitle: l10n.wantToReceiveNudgesDescription,
          value: state.allowNudges,
          onChanged: state.setAllowNudges,
        ),
        const SizedBox(height: 16),
        _SwitchCard(
          icon: Icons.grid_view_rounded,
          title: l10n.eisenhowerMatrix,
          subtitle: l10n.eisenhowerMatrixDescription,
          value: state.eisenhowerMatrixEnabled,
          onChanged: state.setEisenhowerMatrixEnabled,
        ),
        const SizedBox(height: 16),
        _SwitchCard(
          icon: Icons.mark_chat_unread_rounded,
          title: l10n.sessionNotification,
          subtitle: l10n.sessionNotificationDescription,
          value: state.sessionNotificationsEnabled,
          onChanged: state.setSessionNotificationsEnabled,
        ),
        const SizedBox(height: 16),
        const _ExportCard(),
      ],
    );
  }
}

TextStyle? _subtitleStyle(ThemeData theme) => theme.textTheme.bodySmall
    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 12);

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      child: SwitchListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        secondary: Icon(
          icon,
          color: value
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withAlpha(128),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: _subtitleStyle(theme)),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsCard(
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(l10n.exportToCalendar),
        subtitle: Text(
          l10n.exportToCalendarSubtitle,
          style: _subtitleStyle(Theme.of(context)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ExportSessionSheet(),
          );
        },
      ),
    );
  }
}
