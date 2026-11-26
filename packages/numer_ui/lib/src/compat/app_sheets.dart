import 'package:flutter/material.dart';

import '../components/numer_message.dart';
import '../components/numer_row.dart';
import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

const double _maxHeightFraction = 0.9;

abstract final class AppBottomSheet {
  // not built on showNumerSheet, which fixes dismissal, drag, height and a title
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeightFraction,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: enableDrag,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetBody(
        title: title,
        maxHeightFraction: maxHeightFraction ?? _maxHeightFraction,
        child: child,
      ),
    );
  }

  static Future<T?> showSelection<T>({
    required BuildContext context,
    required String title,
    required List<AppBottomSheetOption<T>> options,
    T? selectedValue,
  }) {
    return show<T>(
      context: context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _optionRow(option, selected: option.value == selectedValue),
        ],
      ),
    );
  }

  static Widget _optionRow<T>(
    AppBottomSheetOption<T> option, {
    required bool selected,
  }) {
    return Builder(
      builder: (context) => Semantics(
        selected: selected,
        child: NumerRow(
          leading: option.leading,
          title: option.title,
          subtitle: option.subtitle,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(option.value),
        ),
      ),
    );
  }
}

class AppBottomSheetOption<T> {
  const AppBottomSheetOption({
    required this.title,
    required this.value,
    this.subtitle,
    this.leading,
  });

  final String title;
  final T value;
  final String? subtitle;
  final Widget? leading;
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.maxHeightFraction,
    required this.child,
  });

  final String? title;
  final double maxHeightFraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: NumerSpace.sm),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) _heading(context, title),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: NumerSpace.lg,
        right: NumerSpace.lg,
        bottom: NumerSpace.lg,
      ),
      child: Text(title, style: context.text.sectionTitle),
    );
  }
}

abstract final class AppToast {
  static void showSuccess(BuildContext context, String message) {
    showNumerMessage(context, message);
  }

  static void showInfo(BuildContext context, String message) {
    showNumerMessage(context, message);
  }

  static void showWarning(BuildContext context, String message) {
    showNumerMessage(context, message);
  }

  static void showError(BuildContext context, String message) {
    showNumerMessage(context, message, isError: true);
  }
}
