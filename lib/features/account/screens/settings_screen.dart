import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../data/sign_out.dart';
import '../widgets/settings/settings_about_section.dart';
import '../widgets/settings/settings_appearance_section.dart';
import '../widgets/settings/settings_delete_section.dart';
import '../widgets/settings/settings_display_section.dart';
import '../widgets/settings/settings_identity_card.dart';
import '../widgets/settings/settings_language_section.dart';
import '../widgets/settings/settings_profile_section.dart';
import '../widgets/settings/settings_switches_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _signOut() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await signOutAndReset(context);
    navigator.popUntil((route) => route.isFirst);
  }

  Widget _appBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      title: Text(
        AppLocalizations.of(context)!.settingsTitle,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _signedOut(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _appBar(context),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.pleaseSignInToViewAccount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections() {
    final divider = Divider(color: Colors.grey.shade300, thickness: 1);
    return [
      SettingsIdentityCard(onSignOut: _signOut),
      const SizedBox(height: 32),
      const SettingsProfileSection(),
      const SizedBox(height: 32),
      const SettingsAppearanceSection(),
      const SizedBox(height: 32),
      const SettingsLanguageSection(),
      const SizedBox(height: 24),
      divider,
      const SizedBox(height: 16),
      const SettingsDisplaySection(),
      const SizedBox(height: 24),
      divider,
      const SizedBox(height: 24),
      const SettingsSwitchesSection(),
      const SizedBox(height: 24),
      const SettingsAboutSection(),
      divider,
      SettingsDeleteSection(hostContext: context),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().currentUser == null) {
      return _signedOut(context);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _appBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate(_sections())),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + NumerSpace.xl,
            ),
          ),
        ],
      ),
    );
  }
}
