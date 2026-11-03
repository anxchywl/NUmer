import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';

const double _spinnerSize = 16;
const double _spinnerStrokeWidth = 2;

class NumerButtonChild extends StatelessWidget {
  const NumerButtonChild({
    super.key,
    required this.label,
    this.loading = false,
  });

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    if (!loading) return text;

    final color =
        IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: NumerSpace.sm,
      children: [
        SizedBox.square(
          dimension: _spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: _spinnerStrokeWidth,
            color: color,
          ),
        ),
        Flexible(child: text),
      ],
    );
  }
}
