import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'settings_heading.dart';
import 'settings_segment.dart';

class SettingsLanguageSection extends StatelessWidget {
  const SettingsLanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeading(l10n.language),
        const SizedBox(height: 12),
        _languageSelector(context),
        const SizedBox(height: 32),
        SettingsHeading(l10n.weekStartsOn),
        const SizedBox(height: 12),
        _weekStartSelector(context),
      ],
    );
  }

  Widget _languageSelector(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    return SettingsSegments<String>(
      segments: [
        settingsSegment('ru', 'Русский', singleLine: true),
        settingsSegment('en', 'English', singleLine: true),
        settingsSegment('kk', 'Қазақша', singleLine: true),
      ],
      selected: current,
      onSelected: (code) async {
        if (code == current) return;
        await context.read<AppState>().setLocale(Locale(code));
      },
    );
  }

  Widget _weekStartSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSegments<WeekStart>(
      segments: [
        settingsSegment(WeekStart.monday, l10n.mon),
        settingsSegment(WeekStart.sunday, l10n.sun),
      ],
      selected: context.watch<AppState>().weekStart,
      onSelected: (day) => context.read<AppState>().setWeekStart(day),
    );
  }
}
