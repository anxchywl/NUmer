import 'package:flutter/widgets.dart';

import '../tokens/numer_motion.dart';
import '../tokens/numer_space.dart';

// one duration for a fold, the sheet resizing around it and the buttons
// swapping underneath: any two at different speeds read as a wobble
const Duration _duration = Duration(milliseconds: 240);

// folds out of the way while the keyboard belongs to something else,
// collapsing vertically so the content slides up under its own top edge
class NumerFocusFold extends StatelessWidget {
  const NumerFocusFold({
    super.key,
    required this.hidden,
    required this.child,
    this.animateSize = true,
  });

  static Duration durationOf(BuildContext context) {
    return NumerMotion.of(context, _duration);
  }

  final bool hidden;
  final Widget child;

  // false inside a parent that already animates its own height: two nested
  // AnimatedSizes reacting to one change fight, and the outer one snaps
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    final folded = hidden ? const SizedBox(width: double.infinity) : child;
    final duration = durationOf(context);
    if (!animateSize || duration == Duration.zero) return folded;
    return AnimatedSize(
      duration: duration,
      curve: NumerMotion.enter,
      alignment: Alignment.topCenter,
      child: folded,
    );
  }
}

// the space between two fields is chrome too: with one field left there is
// nothing for it to separate
class NumerFocusGap extends StatelessWidget {
  const NumerFocusGap({
    super.key,
    required this.hidden,
    this.height = NumerSpace.lg,
    this.animateSize = true,
  });

  final bool hidden;
  final double height;
  final bool animateSize;

  @override
  Widget build(BuildContext context) => NumerFocusFold(
    hidden: hidden,
    animateSize: animateSize,
    child: SizedBox(height: height),
  );
}
