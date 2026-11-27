import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import '../profile_form.dart';
import 'settings_heading.dart';

class SettingsProfileSection extends StatelessWidget {
  const SettingsProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeading(l10n.profile),
        const SizedBox(height: 12),
        auth.isProfileReady && state.isLoaded
            ? SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _form(context, state, auth),
                ),
              )
            : const Card(child: NumerSkeleton()),
      ],
    );
  }

  Widget _form(BuildContext context, AppState state, AuthController auth) {
    return ProfileForm(
      initialName: state.profileName ?? '',
      initialMajor: state.major,
      initialContact: state.profileContact,
      initialGoal: state.profileGoal,
      initialAvatarIndex: state.profileAvatarIndex,
      initialAvatarColorValue: state.profileAvatarColorValue,
      initialAvatarBytes: state.profileAvatarImage,
      primaryButtonLabel: AppLocalizations.of(context)!.save,
      onSubmit: (data) async {
        final appState = context.read<AppState>();
        await appState.saveProfile(
          name: data.name,
          goal: data.goal,
          majorText: data.major,
          contact: data.contact,
          avatarIndex: data.avatarIndex,
          avatarColorValue: data.avatarColorValue,
          uid: auth.currentUser?.uid,
        );
      },
    );
  }
}
