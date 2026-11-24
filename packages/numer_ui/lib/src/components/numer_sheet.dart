import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';
import 'numer_focus_actions.dart';
import 'numer_focus_fold.dart';
import 'numer_sheet_focus_mode.dart';

Future<T?> showNumerSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? primaryAction,
}) {
  return showNumerFormSheet<T>(
    context,
    builder: (_) => NumerSheetBody(
      title: title,
      builder: builder,
      primaryAction: primaryAction,
    ),
  );
}

// for a form whose State owns a focus mode, so its nodes live as long as its fields
Future<T?> showNumerFormSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
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
    builder: builder,
  );
}

class NumerSheetBody extends StatelessWidget {
  const NumerSheetBody({
    super.key,
    required this.title,
    required this.builder,
    this.primaryAction,
    this.focusMode,
    this.doneLabel,
  });

  final String title;

  // build the fields here, it re-runs when focus or the keyboard changes
  final WidgetBuilder builder;
  final Widget? primaryAction;
  final NumerSheetFocusMode? focusMode;

  // null keeps the primary action while typing, for a form whose one field it submits
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
        ?_footer(),
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
    final action = primaryAction;
    if (focus == null || label == null) {
      if (action == null) return null;
      return Padding(
        padding: const EdgeInsets.all(NumerSpace.lg),
        child: action,
      );
    }
    final shows = action != null || focus.isTyping;
    // stays mounted so done arrives and leaves with the same animation as the folds
    return NumerFocusFold(
      hidden: false,
      child: Padding(
        padding: shows ? const EdgeInsets.all(NumerSpace.lg) : EdgeInsets.zero,
        child: NumerFocusActions(
          isTyping: focus.isTyping,
          doneLabel: label,
          onDone: focus.release,
          actions: action ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
