import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

// shows a floating snackbar for transient feedback, styled for normal or error state
void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showNumerMessage(
    context,
    message,
    isError: isError,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
