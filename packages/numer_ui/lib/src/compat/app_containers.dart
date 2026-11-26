import 'package:flutter/material.dart';

import '../components/numer_skeleton.dart';
import '../tokens/numer_radius.dart';
import '../tokens/numer_space.dart';
import '../tokens/numer_text.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
    this.backgroundColor,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  // accepted and ignored so module call sites compile until they drop it
  final Color? backgroundColor;

  // accepted and ignored so module call sites compile until they drop it
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(NumerSpace.lg),
      child: child,
    );
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(NumerRadius.lg),
        clipBehavior: clipBehavior,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.page = false});

  // an action shows its loading state in its own button, so only a page draws
  final bool page;

  @override
  Widget build(BuildContext context) {
    return page ? const NumerSkeleton() : const SizedBox.shrink();
  }
}

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.showPercentage = false,
  });

  final double progress;
  final String? label;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null || showPercentage) _caption(context, value),
        ClipRRect(
          borderRadius: BorderRadius.circular(NumerRadius.full),
          child: LinearProgressIndicator(
            value: value,
            color: scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _caption(BuildContext context, double value) {
    final label = this.label;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: NumerSpace.sm),
      child: Row(
        children: [
          // a label long enough to meet the figure wraps instead of overflowing
          Expanded(
            child: label == null
                ? const SizedBox.shrink()
                : Text(label, style: context.text.meta),
          ),
          if (showPercentage) ...[
            const SizedBox(width: NumerSpace.sm),
            Text(
              '${(value * 100).toInt()}%',
              style: context.text.meta.copyWith(color: primary),
            ),
          ],
        ],
      ),
    );
  }
}
