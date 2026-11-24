import 'package:flutter/widgets.dart';

import '../tokens/numer_motion.dart';
import '../tokens/numer_space.dart';

// folds, the sheet resize and the button swap share it, different speeds read as a wobble
const Duration _duration = Duration(milliseconds: 240);

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

  // false under a parent that animates its height, nested AnimatedSizes make the outer snap
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

// with one field left there is nothing for a gap to separate
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
