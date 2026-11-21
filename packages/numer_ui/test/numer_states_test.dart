import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app(Widget state) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [state],
      ),
    ),
  );
}

void _expectLayout(WidgetTester tester, Type type, String message) {
  final state = tester.getRect(find.byType(type));
  final text = tester.getRect(find.text(message));

  expect(text.top - state.top, 32);
  expect(text.center.dx, 400);
  expect(find.byType(Icon), findsNothing);
}

void main() {
  testWidgets('empty centres one sentence and one text button', (tester) async {
    await tester.pumpWidget(
      _app(
        NumerEmptyState(
          message: 'No courses yet.',
          actionLabel: 'Add course',
          onAction: () {},
        ),
      ),
    );

    _expectLayout(tester, NumerEmptyState, 'No courses yet.');
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(
      tester.getRect(find.byType(TextButton)).top -
          tester.getRect(find.text('No courses yet.')).bottom,
      12,
    );
  });

  testWidgets('empty can make its action primary', (tester) async {
    await tester.pumpWidget(
      _app(
        NumerEmptyState(
          message: 'No courses yet.',
          actionLabel: 'Add course',
          onAction: () {},
          primaryAction: true,
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('error offers retry as a text button', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(
        NumerErrorState(
          message: 'Could not load news.',
          retryLabel: 'Retry',
          onRetry: () => retries++,
        ),
      ),
    );

    _expectLayout(tester, NumerErrorState, 'Could not load news.');
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
