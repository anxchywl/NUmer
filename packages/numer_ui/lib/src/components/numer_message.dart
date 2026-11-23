import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';

const Duration _duration = Duration(seconds: 4);

void showNumerMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isError
              ? colorScheme.onErrorContainer
              : colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.primary,
            )
          : null,
      backgroundColor: isError
          ? colorScheme.errorContainer
          : colorScheme.primaryContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NumerRadius.lg),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: NumerSpace.lg,
        vertical: NumerSpace.lg,
      ),
      elevation: 4,
      duration: _duration,
    ),
  );
}
