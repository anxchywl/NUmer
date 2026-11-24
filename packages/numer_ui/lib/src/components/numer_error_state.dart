import 'package:flutter/material.dart';

import 'numer_empty_state.dart';

class NumerErrorState extends StatelessWidget {
  const NumerErrorState({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return NumerEmptyState(
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}
