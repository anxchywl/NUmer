import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app({required bool loading}) {
  return MaterialApp(
    home: Scaffold(
      body: FilledButton(
        onPressed: null,
        child: NumerButtonChild(label: 'Verify', loading: loading),
      ),
    ),
  );
}

Finder get _spinner =>
    find.byWidgetPredicate((widget) => widget is ProgressIndicator);

void main() {
  testWidgets('idle shows only the label', (tester) async {
    await tester.pumpWidget(_app(loading: false));

    expect(find.text('Verify'), findsOneWidget);
    expect(_spinner, findsNothing);
  });

  testWidgets('loading keeps the label after a spinner', (tester) async {
    await tester.pumpWidget(_app(loading: true));

    expect(find.text('Verify'), findsOneWidget);
    expect(tester.getSize(_spinner), const Size.square(16));
    expect(
      tester.getRect(find.text('Verify')).left - tester.getRect(_spinner).right,
      NumerSpace.sm,
    );
    final indicator = tester.widget<ProgressIndicator>(_spinner);
    expect(indicator.color, IconTheme.of(tester.element(_spinner)).color);
  });
}
