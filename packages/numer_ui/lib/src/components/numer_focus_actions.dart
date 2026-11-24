import 'package:flutter/material.dart';

import '../tokens/numer_motion.dart';
import 'numer_focus_fold.dart';

const Offset _enterOffset = Offset(0, 0.08);

class NumerFocusActions extends StatelessWidget {
  const NumerFocusActions({
    super.key,
    required this.isTyping,
    required this.doneLabel,
    required this.onDone,
    required this.actions,
  });

  final bool isTyping;
  final String doneLabel;
  final VoidCallback onDone;

  // what sits there when the keyboard is down
  final Widget actions;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: NumerFocusFold.durationOf(context),
    switchInCurve: NumerMotion.enter,
    switchOutCurve: NumerMotion.exit,
    // the outgoing button is held out of the layout so it never sets the height
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [
        for (final child in previous)
          Positioned(top: 0, left: 0, right: 0, child: child),
        ?current,
      ],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: _enterOffset,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: SizedBox(
      key: ValueKey<bool>(isTyping),
      width: double.infinity,
      child: isTyping
          ? FilledButton(onPressed: onDone, child: Text(doneLabel))
          : actions,
    ),
  );
}
