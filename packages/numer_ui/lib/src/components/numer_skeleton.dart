import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';

const Duration _delay = Duration(milliseconds: 300);
const double _oneLineHeight = 56;
const double _twoLineHeight = 72;
const double _titleHeight = 16;
const double _titleWidth = 0.6;
const double _metaHeight = 12;
const double _metaWidth = 0.35;
const double _boxAlpha = 0.08;

class NumerSkeleton extends StatefulWidget {
  const NumerSkeleton({super.key, this.rows = 3, this.twoLine = true});

  final int rows;
  final bool twoLine;

  @override
  State<NumerSkeleton> createState() => _NumerSkeletonState();
}

class _NumerSkeletonState extends State<NumerSkeleton> {
  late final Timer _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_delay, () => setState(() => _visible = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < widget.rows; i++) _row(context)],
      ),
    );
  }

  Widget _row(BuildContext context) {
    return SizedBox(
      height: widget.twoLine ? _twoLineHeight : _oneLineHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NumerSpace.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(context, _titleWidth, _titleHeight),
            if (widget.twoLine) ...[
              const SizedBox(height: NumerSpace.xs),
              _box(context, _metaWidth, _metaHeight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context, double widthFactor, double height) {
    final color = Theme.of(context).colorScheme.onSurface;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: _boxAlpha),
            borderRadius: BorderRadius.circular(NumerRadius.sm),
          ),
        ),
      ),
    );
  }
}
