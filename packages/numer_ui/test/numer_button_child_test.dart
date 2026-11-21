import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app({required bool loading, String label = 'Verify'}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: loading ? null : () {},
          child: NumerButtonChild(
            label: label,
            loading: loading,
            loadingHint: 'Loading',
          ),
        ),
      ),
    ),
  );
}

Finder get _spinner =>
    find.byWidgetPredicate((widget) => widget is ProgressIndicator);

bool _labelShows(WidgetTester tester) {
  return tester.widget<Visibility>(find.byType(Visibility)).visible;
}

void main() {
  testWidgets('idle shows only the label', (tester) async {
    await tester.pumpWidget(_app(loading: false));

    expect(find.text('Verify'), findsOneWidget);
    expect(_labelShows(tester), isTrue);
    expect(_spinner, findsNothing);
  });

  testWidgets('loading hides the label behind a centred spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_app(loading: true));

    expect(_labelShows(tester), isFalse);
    expect(tester.getSize(_spinner), const Size.square(20));
    expect(
      tester.getCenter(_spinner),
      tester.getCenter(find.byType(FilledButton)),
    );
    final indicator = tester.widget<ProgressIndicator>(_spinner);
    expect(indicator.color, IconTheme.of(tester.element(_spinner)).color);
    final dynamic circle = indicator;
    expect(circle.strokeWidth, 2);
  });

  for (final label in ['Go', 'Verify the code from the email ' * 3]) {
    testWidgets('the button keeps its size for ${label.length} characters', (
      tester,
    ) async {
      await tester.pumpWidget(_app(loading: false, label: label));
      final idle = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(_app(loading: true, label: label));
      await tester.pump(const Duration(seconds: 1));

      expect(tester.getSize(find.byType(FilledButton)), idle);
    });
  }

  testWidgets('screen readers keep the label and hear the hint', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(loading: false));
    expect(
      tester.getSemantics(find.byType(FilledButton)),
      containsSemantics(label: 'Verify', hint: ''),
    );

    await tester.pumpWidget(_app(loading: true));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getSemantics(find.byType(FilledButton)),
      containsSemantics(label: 'Verify', hint: 'Loading'),
    );
    semantics.dispose();
  });
}
