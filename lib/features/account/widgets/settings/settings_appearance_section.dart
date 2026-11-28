import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

import '../accent_color_picker.dart';
import 'settings_heading.dart';
import 'settings_segment.dart';

class SettingsAppearanceSection extends StatelessWidget {
  const SettingsAppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsHeading(l10n.appearance),
        const SizedBox(height: 12),
        _themeSelector(context),
        const SizedBox(height: 16),
        _accentCard(context),
      ],
    );
  }

  Widget _themeSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mode = context.watch<AppState>().themeMode;
    return SettingsSegments<ThemeMode>(
      segments: [
        settingsSegment(
          ThemeMode.light,
          l10n.light,
          icon: Icons.light_mode_outlined,
        ),
        settingsSegment(
          ThemeMode.system,
          l10n.system,
          icon: Icons.settings_suggest_outlined,
        ),
        settingsSegment(
          ThemeMode.dark,
          l10n.dark,
          icon: Icons.dark_mode_outlined,
        ),
      ],
      selected: mode,
      onSelected: (mode) => context.read<AppState>().setThemeMode(mode),
    );
  }

  Widget _accentCard(BuildContext context) {
    final state = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    return SettingsCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: state.accentColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
        ),
        title: Text(l10n.accentColor),
        subtitle: Text(l10n.accentColorDescription),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showAccentSheet(context, state),
      ),
    );
  }

  void _showAccentSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AccentSheet(state: state),
    );
  }
}

class _AccentSheet extends StatefulWidget {
  const _AccentSheet({required this.state});

  final AppState state;

  @override
  State<_AccentSheet> createState() => _AccentSheetState();
}

class _AccentSheetState extends State<_AccentSheet> {
  final _focus = NumerSheetFocusMode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumerFocusFold(
              hidden: _focus.hidesChrome,
              child: _heading(context),
            ),
            AccentColorPicker(
              focus: _focus,
              currentColor: widget.state.accentColor,
              onColorChanged: (color) {
                widget.state.setAccentColor(color);
              },
              onSave: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.accentColor,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
