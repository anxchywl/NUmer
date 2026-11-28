import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/history/widgets/add_time_sheet.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

class _Sessions extends FakeState {
  _Sessions({this.overlaps = false}) : super(courses: [course('a', 'Algebra')]);

  final bool overlaps;
  final saved = <(String, DateTime, DateTime)>[];

  @override
  Future<void> addManualSession({
    required String courseId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (overlaps) throw SessionOverlapException('overlap');
    saved.add((courseId, start, end));
  }
}

Future<void> _save(
  WidgetTester tester,
  _Sessions state, {
  required String start,
  required String end,
}) async {
  await openSheet(
    tester,
    (context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTimeSheet(day: DateTime(2020, 5, 4)),
    ),
    providers: [ChangeNotifierProvider<AppState>.value(value: state)],
  );
  await tester.enterText(fieldLabeled('Start'), start);
  await tester.enterText(fieldLabeled('End'), end);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a valid range is saved to the course', (tester) async {
    final state = _Sessions();

    await _save(tester, state, start: '0930', end: '1015');

    expect(state.saved, [
      ('a', DateTime(2020, 5, 4, 9, 30), DateTime(2020, 5, 4, 10, 15)),
    ]);
    expect(find.text('Time added to Algebra'), findsOneWidget);
    expect(find.byType(AddTimeSheet), findsNothing);
  });

  testWidgets('an end before the start is refused', (tester) async {
    final state = _Sessions();

    await _save(tester, state, start: '1015', end: '0930');

    expect(state.saved, isEmpty);
    expect(find.textContaining('later than end time'), findsOneWidget);
    expect(find.byType(AddTimeSheet), findsNothing);
  });

  testWidgets('a missing time keeps the sheet open', (tester) async {
    final state = _Sessions();

    await _save(tester, state, start: '0930', end: '');

    expect(state.saved, isEmpty);
    expect(find.textContaining('Enter times as'), findsOneWidget);
    expect(find.byType(AddTimeSheet), findsOneWidget);
  });

  testWidgets('an overlapping range reports it', (tester) async {
    final state = _Sessions(overlaps: true);

    await _save(tester, state, start: '0930', end: '1015');

    expect(state.saved, isEmpty);
    expect(find.textContaining('already studied'), findsOneWidget);
    expect(find.byType(AddTimeSheet), findsNothing);
  });
}
