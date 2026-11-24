import 'package:flutter/material.dart';

import '../tokens/numer_colors.dart';
import '../tokens/numer_text.dart';

enum NumerStatusTone { neutral, positive, caution, negative, highlighted }

class NumerStatusLabel extends StatelessWidget {
  const NumerStatusLabel(
    this.text, {
    super.key,
    this.tone = NumerStatusTone.neutral,
  });

  final String text;
  final NumerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.text.status(_color(Theme.of(context))));
  }

  Color _color(ThemeData theme) {
    final scheme = theme.colorScheme;
    return switch (tone) {
      NumerStatusTone.neutral => scheme.onSurfaceVariant,
      NumerStatusTone.positive => theme.extension<NumerColors>()!.success,
      NumerStatusTone.caution => theme.extension<NumerColors>()!.warning,
      NumerStatusTone.negative => scheme.error,
      NumerStatusTone.highlighted => scheme.primary,
    };
  }
}
