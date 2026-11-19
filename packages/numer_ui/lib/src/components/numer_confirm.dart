import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';
import 'numer_sheet.dart';

Future<bool> showNumerConfirm(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showNumerSheet<bool>(
    context,
    title: title,
    builder: (context) => body == null
        ? const SizedBox.shrink()
        : Text(body, style: context.text.body),
    primaryAction: _NumerConfirmActions(
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _NumerConfirmActions extends StatelessWidget {
  const _NumerConfirmActions({
    required this.confirmLabel,
    required this.destructive,
  });

  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
        const SizedBox(height: NumerSpace.sm),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
