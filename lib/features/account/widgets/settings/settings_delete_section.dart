import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../delete_account_sheet.dart';
import 'settings_delete_confirm.dart';

class SettingsDeleteSection extends StatelessWidget {
  const SettingsDeleteSection({super.key, required this.hostContext});

  // the tile can be disposed while the keyboard is up, so the flow runs on the screen
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthController>().isBusy;
    final l10n = AppLocalizations.of(context)!;
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(Icons.delete_forever, color: error, size: 20),
      title: Text(
        l10n.deleteAccount,
        style: TextStyle(color: error, fontSize: 14),
      ),
      subtitle: Text(
        l10n.deleteAccountSubtitle,
        style: const TextStyle(fontSize: 12),
      ),
      enabled: !busy,
      onTap: busy ? null : () => _confirmDeleteAccount(hostContext),
    );
  }
}

Future<void> _confirmDeleteAccount(BuildContext context) async {
  final auth = context.read<AuthController>();
  final appState = context.read<AppState>();
  final syncService = context.read<SyncService>();
  final navigator = Navigator.of(context, rootNavigator: true);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const _DeleteWarningDialog(),
  );

  if (confirmed != true || !context.mounted) return;

  final deleted = await showDeleteAccountSheet(
    context,
    onDelete: (password) => auth.deleteAccount(
      password: password,
      beforeDelete: () async {
        await appState.stopAndSaveAllActiveSessions();
        await appState.waitForPendingReflections();
        await syncService.pushNow();
      },
    ),
  );
  if (!deleted) return;

  navigator.pushNamedAndRemoveUntil('/', (route) => false);
}

class _DeleteWarningDialog extends StatelessWidget {
  const _DeleteWarningDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_rounded, color: scheme.error, size: 32),
      title: Text(l10n.deleteAccount),
      content: _warning(context),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        SizedBox(
          width: 110,
          child: HoldToConfirmButton(
            label: l10n.delete,
            holdDuration: const Duration(seconds: 5),
            backgroundColor: scheme.errorContainer,
            fillColor: scheme.error,
            textColor: scheme.error,
            onConfirmed: () async {
              // After hold, show second confirmation with text input
              final textConfirmed = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const DeleteAccountTextConfirmDialog(),
              );
              if (textConfirmed == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _warning(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This action is permanent and can not be undone.',
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.error),
        ),
        const SizedBox(height: 8),
        const Text('Deleting your account will:'),
        const SizedBox(height: 4),
        const Text('• Remove all your study sessions'),
        const Text('• Delete your courses and habits progress'),
        const Text(
          '• Remove you from your group and delete group you created if any',
        ),
        const Text('• Erase your profile and settings'),
        const SizedBox(height: 12),
        Text(l10n.deleteAccountHoldConfirmDetail),
      ],
    );
  }
}
