import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';
import 'numer_focus_actions.dart';
import 'numer_focus_fold.dart';
import 'numer_sheet_focus_mode.dart';

// the caller owns focusMode and disposes it; without a doneLabel the primary
// action stays while typing, for a form whose one field it submits
Future<T?> showNumerSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? primaryAction,
  NumerSheetFocusMode? focusMode,
  String? doneLabel,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NumerRadius.xl)),
    ),
    builder: (context) => _NumerSheetBody(
      title: title,
      builder: builder,
      primaryAction: primaryAction,
      focusMode: focusMode,
      doneLabel: doneLabel,
    ),
  );
}

class _NumerSheetBody extends StatelessWidget {
  const _NumerSheetBody({
    required this.title,
    required this.builder,
    this.primaryAction,
    this.focusMode,
    this.doneLabel,
  });

  final String title;
  final WidgetBuilder builder;
  final Widget? primaryAction;
  final NumerSheetFocusMode? focusMode;
  final String? doneLabel;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final focus = focusMode;
    focus?.setKeyboardVisible(keyboard > 0);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: focus == null
            ? _content(context)
            : ListenableBuilder(
                listenable: focus,
                builder: (context, _) => _content(context),
              ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final footer = _footer();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
            child: builder(context),
          ),
        ),
        if (footer != null)
          Padding(padding: const EdgeInsets.all(NumerSpace.lg), child: footer),
      ],
    );
  }

  Widget _title(BuildContext context) {
    final heading = Padding(
      padding: const EdgeInsets.only(
        left: NumerSpace.lg,
        right: NumerSpace.lg,
        bottom: NumerSpace.lg,
      ),
      child: Text(title, style: context.text.sectionTitle),
    );
    final focus = focusMode;
    if (focus == null) return heading;
    return NumerFocusFold(hidden: focus.hidesChrome, child: heading);
  }

  Widget? _footer() {
    final focus = focusMode;
    final label = doneLabel;
    if (focus == null || label == null) return primaryAction;
    if (primaryAction == null && !focus.isTyping) return null;
    return NumerFocusActions(
      isTyping: focus.isTyping,
      doneLabel: label,
      onDone: focus.release,
      actions: primaryAction ?? const SizedBox.shrink(),
    );
  }
}
