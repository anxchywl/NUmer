import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

void main() {
  for (final tone in NumerStatusTone.values) {
    testWidgets('${tone.name} colours plain text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NumerTheme.build(
            seed: const Color.fromARGB(255, 68, 138, 255),
            brightness: Brightness.light,
          ),
          home: Scaffold(body: NumerStatusLabel('Open', tone: tone)),
        ),
      );
      final scheme = Theme.of(
        tester.element(find.byType(NumerStatusLabel)),
      ).colorScheme;
      final expected = switch (tone) {
        NumerStatusTone.neutral => scheme.onSurfaceVariant,
        NumerStatusTone.positive => NumerColors.light.success,
        NumerStatusTone.caution => NumerColors.light.warning,
        NumerStatusTone.negative => scheme.error,
        NumerStatusTone.highlighted => scheme.primary,
      };
      final style = tester.widget<Text>(find.text('Open')).style!;

      expect(style.color, expected);
      expect(style.fontWeight, FontWeight.w500);
      for (final type in [DecoratedBox, Container]) {
        expect(
          find.descendant(
            of: find.byType(NumerStatusLabel),
            matching: find.byType(type),
          ),
          findsNothing,
        );
      }
    });
  }
}
