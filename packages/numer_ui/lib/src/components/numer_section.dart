import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

class NumerSection extends StatelessWidget {
  const NumerSection({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.child,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: NumerSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.text.sectionTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (label != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(label)),
              ],
            ),
          ),
          const SizedBox(height: NumerSpace.sm),
          child,
        ],
      ),
    );
  }
}
