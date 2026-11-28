import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

// for a sheet that keeps its own layout instead of NumerSheetBody
class SheetFocusBuilder extends StatelessWidget {
  const SheetFocusBuilder({
    super.key,
    required this.focus,
    required this.builder,
  });

  final NumerSheetFocusMode focus;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    focus.setKeyboardVisible(MediaQuery.viewInsetsOf(context).bottom > 0);
    return ListenableBuilder(
      listenable: focus,
      builder: (context, _) => builder(context),
    );
  }
}

class SheetDoneActions extends StatelessWidget {
  const SheetDoneActions({
    super.key,
    required this.focus,
    required this.actions,
  });

  final NumerSheetFocusMode focus;

  // what sits there when the keyboard is down
  final Widget actions;

  @override
  Widget build(BuildContext context) => NumerFocusActions(
    isTyping: focus.isTyping,
    doneLabel: AppLocalizations.of(context)!.focusDone,
    onDone: focus.release,
    actions: actions,
  );
}
