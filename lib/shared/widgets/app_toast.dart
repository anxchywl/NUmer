import 'package:flutter/material.dart';

// shows a floating snackbar for transient feedback, styled for normal or error state
void showAppMessage(
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
              textColor:
                  isError ? colorScheme.onErrorContainer : colorScheme.primary,
            )
          : null,
      backgroundColor:
          isError ? colorScheme.errorContainer : colorScheme.primaryContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      elevation: 4,
      duration: const Duration(seconds: 4),
    ),
  );
}
