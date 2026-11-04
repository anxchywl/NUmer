import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

void main() {
  test('spacing and radii sit on the 4 pt grid', () {
    const values = [
      NumerSpace.xs,
      NumerSpace.sm,
      NumerSpace.md,
      NumerSpace.lg,
      NumerSpace.xl,
      NumerSpace.xxl,
      NumerSpace.xxxl,
      NumerRadius.sm,
      NumerRadius.md,
      NumerRadius.lg,
      NumerRadius.xl,
    ];

    for (final value in values) {
      expect(value % 4, 0, reason: '$value');
    }
  });

  test('motion durations', () {
    expect(NumerMotion.fast, const Duration(milliseconds: 150));
    expect(NumerMotion.base, const Duration(milliseconds: 200));
    expect(NumerMotion.slow, const Duration(milliseconds: 250));
  });

  for (final disabled in [false, true]) {
    testWidgets('motion with animations disabled: $disabled', (tester) async {
      late Duration duration;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: Builder(
            builder: (context) {
              duration = NumerMotion.of(context, NumerMotion.base);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(duration, disabled ? Duration.zero : NumerMotion.base);
    });
  }

  testWidgets('text styles follow the type scale', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      ),
    );
    final text = context.text;
    final styles = [
      text.display,
      text.screenTitle,
      text.sectionTitle,
      text.rowTitle,
      text.body,
      text.meta,
      text.status(),
    ];

    expect(styles.map((style) => style.fontSize), [45, 22, 16, 16, 14, 12, 12]);
    expect(styles.map((style) => style.fontWeight), [
      FontWeight.w400,
      FontWeight.w700,
      FontWeight.w700,
      FontWeight.w400,
      FontWeight.w400,
      FontWeight.w400,
      FontWeight.w500,
    ]);

    final colors = Theme.of(context).colorScheme;
    expect(styles.map((style) => style.color), [
      colors.onSurface,
      colors.primary,
      colors.onSurface,
      colors.onSurface,
      colors.onSurface,
      colors.onSurfaceVariant,
      colors.onSurfaceVariant,
    ]);
    expect(text.status(colors.error).color, colors.error);
    expect(text.display.fontFeatures, const [FontFeature.tabularFigures()]);
  });

  test('semantic colours copy and interpolate', () {
    final copy = NumerColors.light.copyWith(success: NumerColors.dark.success);
    final end = NumerColors.light.lerp(NumerColors.dark, 1);

    expect(copy.success, NumerColors.dark.success);
    expect(copy.warning, NumerColors.light.warning);
    expect(end.success, NumerColors.dark.success);
    expect(end.warning, NumerColors.dark.warning);
  });
}
