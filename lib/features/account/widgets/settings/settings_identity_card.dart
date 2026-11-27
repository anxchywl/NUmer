import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import '../universal_avatar.dart';
import 'settings_heading.dart';

class SettingsIdentityCard extends StatelessWidget {
  const SettingsIdentityCard({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final profile = auth.profile;
    final displayName =
        (state.profileName != null && state.profileName!.trim().isNotEmpty)
        ? state.profileName!.trim()
        : (((profile?['displayName'] as String?) ??
                  user?.displayName ??
                  'Unknown user')
              .trim());
    final loginLabel =
        (profile?['login'] as String?) ?? user?.email ?? 'Unknown login';

    return SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UniversalAvatar(
                name: displayName,
                avatarIndex: state.profileAvatarIndex,
                avatarColorValue: state.profileAvatarColorValue,
                alwaysShowSilhouette: true,
                size: 48,
              ),
              title: Text(displayName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(loginLabel)],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _signOutButton(context, auth.isBusy),
                const Spacer(),
                _syncButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle get _compactStyle => const ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    minimumSize: WidgetStatePropertyAll(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
  );

  Widget _signOutButton(BuildContext context, bool isBusy) {
    return TextButton.icon(
      onPressed: isBusy ? null : onSignOut,
      style: _compactStyle,
      icon: const Icon(Icons.logout, size: 18),
      label: Text(AppLocalizations.of(context)!.signOut),
    );
  }

  Widget _syncButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final syncing = context.watch<SyncService>().status == SyncStatus.syncing;
    return FilledButton(
      onPressed: syncing
          ? null
          : () => context.read<SyncService>().syncNow(full: true),
      style: _compactStyle,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: NumerButtonChild(
          label: l10n.syncNow,
          icon: const Icon(Icons.sync, size: 18),
          loading: syncing,
          loadingHint: l10n.syncing,
        ),
      ),
    );
  }
}
