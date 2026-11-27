import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_fakes.dart';
import '../home/home_harness.dart';

Future<void> _tapStart(WidgetTester tester) =>
    tester.tap(find.byIcon(Icons.play_arrow));

Future<void> _startTimer(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(1), '5');
  await _tapStart(tester);
}

Future<void> _startStopwatch(WidgetTester tester) async {
  await tester.tap(find.text('Stopwatch'));
  await tester.pumpAndSettle();
  await _tapStart(tester);
}

Future<void> _startPomodoro(WidgetTester tester) async {
  await tester.tap(find.text('Pomodoro'));
  await tester.pumpAndSettle();
  await _tapStart(tester);
}

void main() {
  for (final (kind, start) in [
    ('timer', _startTimer),
    ('stopwatch', _startStopwatch),
    ('pomodoro', _startPomodoro),
  ]) {
    for (final accepted in [true, false]) {
      testWidgets('a $kind start that returns $accepted', (tester) async {
        final home = HomeHarness(
          state: FakeState(courses: [course('a', 'Algebra')])
            ..startAccepted = accepted,
        );
        await home.pump(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Algebra'));
        await tester.pumpAndSettle();

        await start(tester);
        await tester.pumpAndSettle();

        expect(home.lastCourse.id, accepted ? 'a' : null);
      });
    }
  }
}
