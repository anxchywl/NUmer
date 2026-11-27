import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../screens/settings_screen.dart';
import 'universal_avatar.dart';

class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key, required this.title, this.actions = const []});

  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.profileName?.trim() ?? '';
    return NumerShellHeader(
      title: title,
      actions: actions,
      avatar: UniversalAvatar(
        name: name,
        avatarIndex: state.profileAvatarIndex,
        avatarColorValue: state.profileAvatarColorValue,
        alwaysShowSilhouette: true,
        size: 32,
      ),
      avatarTooltip: AppLocalizations.of(context)!.settingsTooltip,
      onAvatarPressed: () => openSettings(context),
    );
  }
}

Future<void> openSettings(BuildContext context) async {
  // a second tap lands before settings covers the avatar
  if (ModalRoute.of(context)?.isCurrent == false) return;
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/settings'),
      builder: (_) => const SettingsScreen(),
    ),
  );
}
