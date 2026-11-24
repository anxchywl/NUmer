import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

Future<T?> showNumerSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? primaryAction,
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
    ),
  );
}

class _NumerSheetBody extends StatelessWidget {
  const _NumerSheetBody({
    required this.title,
    required this.builder,
    this.primaryAction,
  });

  final String title;
  final WidgetBuilder builder;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: NumerSpace.lg,
                right: NumerSpace.lg,
                bottom: NumerSpace.lg,
              ),
              child: Text(title, style: context.text.sectionTitle),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
                child: builder(context),
              ),
            ),
            if (primaryAction != null)
              Padding(
                padding: const EdgeInsets.all(NumerSpace.lg),
                child: primaryAction,
              ),
          ],
        ),
      ),
    );
  }
}
