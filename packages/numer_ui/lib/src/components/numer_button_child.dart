import 'package:flutter/material.dart';

import '../tokens/numer_space.dart';

const double _spinnerSize = 20;
const double _spinnerStrokeWidth = 2;

class NumerButtonChild extends StatelessWidget {
  const NumerButtonChild({
    super.key,
    required this.label,
    this.loading = false,
    this.loadingHint,
    this.icon,
  }) : assert(
         !loading || loadingHint != null,
         'say what a screen reader hears',
       );

  final String label;
  final bool loading;

  // the caller's localized word for a screen reader, this package has none
  final String? loadingHint;

  // belongs here so it hides with the label and the spinner centres over both
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: loading ? loadingHint : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // laid out while hidden so the button keeps its size
          ConstrainedBox(
            // a label narrower than the spinner would shrink it
            constraints: const BoxConstraints(
              minWidth: _spinnerSize,
              minHeight: _spinnerSize,
            ),
            child: Visibility(
              visible: !loading,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              maintainSemantics: true,
              child: _content(),
            ),
          ),
          if (loading) Positioned.fill(child: Center(child: _spinner(context))),
        ],
      ),
    );
  }

  Widget _content() {
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    final icon = this.icon;
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: NumerSpace.sm),
        Flexible(child: text),
      ],
    );
  }

  Widget _spinner(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;
    return SizedBox.square(
      dimension: _spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: _spinnerStrokeWidth,
        color: color,
      ),
    );
  }
}
