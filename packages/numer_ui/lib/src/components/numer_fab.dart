import 'package:flutter/material.dart';

import '../tokens/numer_motion.dart';

const Offset _hiddenOffset = Offset(0, 2);

class NumerFab extends StatelessWidget {
  const NumerFab({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.visible = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : _hiddenOffset,
        duration: NumerMotion.of(context, NumerMotion.base),
        curve: visible ? NumerMotion.enter : NumerMotion.exit,
        child: IgnorePointer(
          ignoring: !visible,
          child: FloatingActionButton.extended(
            icon: Icon(icon),
            label: Text(label),
            onPressed: onPressed,
            heroTag: label,
          ),
        ),
      ),
    );
  }
}
