import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

class _Habits extends FakeHabits {
  @override
  Stream<List<HabitCategory>> getCategories(String uid) => Stream.value([]);
}

Future<void> _open(WidgetTester tester) => openSheet(
  tester,
  (context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const AddHabitSheet(),
  ),
  providers: [
    ChangeNotifierProvider<AuthController>(create: (_) => FakeAuth()),
    ChangeNotifierProvider<AppState>(create: (_) => FakeState()),
    Provider<HabitService>(create: (_) => _Habits()),
  ],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _toSchedule(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'Run');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Next'));
}

Finder get _done => find.widgetWithText(FilledButton, 'Done');

void main() {
  testWidgets('the name step keeps the name and done', (tester) async {
    await _open(tester);

    await typeIn(tester, find.byType(TextFormField));

    expect(find.text('Create custom'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expectAboveKeyboard(tester, find.byType(TextFormField));
    expectAboveKeyboard(tester, _done);

    await tapDone(tester);

    expect(find.text('Create custom'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('a new category keeps its name and done', (tester) async {
    await _open(tester);
    await _tap(tester, find.text('Create custom'));

    await typeIn(tester, find.byType(TextField).last);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Back'), findsNothing);
    expectAboveKeyboard(tester, _done);

    await tapDone(tester);

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('the target step folds around the value and unit', (
    tester,
  ) async {
    await _open(tester);
    await _toSchedule(tester);
    await _tap(tester, find.text('Numeric'));
    final value = find.widgetWithText(TextFormField, 'Value');
    final unit = find.widgetWithText(TextFormField, 'Unit');

    await typeIn(tester, value);

    expect(unit, findsNothing);
    expect(find.byType(SegmentedButton<HabitType>), findsNothing);
    expect(find.text('Back'), findsNothing);
    expectAboveKeyboard(tester, value);
    expectAboveKeyboard(tester, _done);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(value, findsNothing);
    expect(unit, findsOneWidget);

    await tapDone(tester);

    expect(value, findsOneWidget);
    expect(find.byType(SegmentedButton<HabitType>), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('the work and rest cycle folds around one number', (
    tester,
  ) async {
    await _open(tester);
    await _toSchedule(tester);
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Work / Rest'));
    final work = find.byKey(const ValueKey('work_days_input'));
    final rest = find.byKey(const ValueKey('rest_days_input'));

    await typeIn(tester, work);

    expect(rest, findsNothing);
    expect(find.text('Every day'), findsNothing);
    expect(find.text('Days per period'), findsNothing);
    expectAboveKeyboard(tester, work);
    expectAboveKeyboard(tester, _done);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(work, findsNothing);
    expect(rest, findsOneWidget);

    await tapDone(tester);

    expect(work, findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets('the period goal folds the other frequencies', (tester) async {
    await _open(tester);
    await _toSchedule(tester);
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Days per period'));
    final goal = find.byKey(const ValueKey('frequency_goal_input'));

    await typeIn(tester, goal);

    expect(find.text('Every day'), findsNothing);
    expect(find.text('Work / Rest'), findsNothing);
    expectAboveKeyboard(tester, goal);
    expectAboveKeyboard(tester, _done);

    await tapDone(tester);

    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Work / Rest'), findsOneWidget);
  });
}
