import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';

const double _dividerThickness = 1;

class NumerBlock extends StatelessWidget {
  NumerBlock({super.key, required this.children})
    : assert(
        !children.any((child) => child is NumerBlock),
        'a block never contains a block',
      );

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final divider = Divider(
      height: _dividerThickness,
      thickness: _dividerThickness,
      indent: NumerSpace.lg,
      color: scheme.outlineVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(NumerRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) divider,
              child,
            ],
          ],
        ),
      ),
    );
  }
}
