import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/shared/widgets/sheet_focus.dart';

class ProfileSetupDialog extends StatefulWidget {
  const ProfileSetupDialog({super.key, required this.formBuilder});

  // the form takes the dialog's focus mode so both fold together
  final Widget Function(NumerSheetFocusMode focus) formBuilder;

  @override
  State<ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}

class _ProfileSetupDialogState extends State<ProfileSetupDialog> {
  final _focus = NumerSheetFocusMode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _dialog);

  Widget _dialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
      canPop: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              elevation: 8,
              borderRadius: BorderRadius.circular(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _content(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NumerFocusFold(
          hidden: _focus.hidesChrome,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Welcome!\nLet\'s create your profile.',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        widget.formBuilder(_focus),
      ],
    );
  }
}
