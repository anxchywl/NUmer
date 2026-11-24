import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

void main() {
  testWidgets('fills a rounded surface and divides its rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumerBlock(
            children: const [
              NumerRow(title: 'One'),
              NumerRow(title: 'Two'),
              NumerRow(title: 'Three'),
            ],
          ),
        ),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(NumerBlock)),
    ).colorScheme;
    final surface = find.descendant(
      of: find.byType(NumerBlock),
      matching: find.byType(Material),
    );
    final material = tester.widget<Material>(surface);
    final dividers = tester.widgetList<Divider>(find.byType(Divider));

    expect(material.color, scheme.surfaceContainerHighest);
    expect(material.borderRadius, BorderRadius.circular(16));
    expect(tester.getRect(surface).left, 16);
    expect(dividers, hasLength(2));
    for (final divider in dividers) {
      expect(divider.indent, 16);
      expect(divider.thickness, 1);
      expect(divider.color, scheme.outlineVariant);
    }
  });

  test('a block cannot hold a block', () {
    expect(
      () => NumerBlock(children: [NumerBlock(children: const [])]),
      throwsAssertionError,
    );
  });
}
