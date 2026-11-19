import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

class NumerEmptyState extends StatelessWidget {
  const NumerEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.primaryAction = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = actionLabel;
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.only(
          top: NumerSpace.xxl,
          left: NumerSpace.lg,
          right: NumerSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: context.text.body.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (label != null && onAction != null) ...[
              const SizedBox(height: NumerSpace.md),
              primaryAction
                  ? FilledButton(onPressed: onAction, child: Text(label))
                  : TextButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
