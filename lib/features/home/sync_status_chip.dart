import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color background;
    Color foreground;
    IconData icon;
    String label;

    switch (sync.status) {
      case SyncStatus.offline:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        icon = Icons.cloud_off;
        label = AppLocalizations.of(context)!.syncOffline;
        break;
      case SyncStatus.syncing:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        icon = Icons.sync;
        label = AppLocalizations.of(context)!.syncSyncing;
        break;
      case SyncStatus.upToDate:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.cloud_done;
        label = AppLocalizations.of(context)!.syncUpToDate;
        break;
    }

    final tooltip = sync.lastError;

    final chip = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );

    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}
