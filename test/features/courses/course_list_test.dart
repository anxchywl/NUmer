import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeAppState extends ChangeNotifier implements AppState {
  final List<(int, int)> reorders = [];
  final List<String> removed = [];

  @override
  List<Course> courses = [_course('a', 'Algebra'), _course('b', 'Biology')];

  @override
  HomeSummaryRange get homeSummaryRange => HomeSummaryRange.off;

  @override
  ProgressView get progressView => ProgressView.off;

  @override
  double? goalHoursForCourse(String id) => null;

  @override
  Future<void> reorderCourses(int oldIndex, int newIndex) async {
    reorders.add((oldIndex, newIndex));
  }

  @override
  Future<void> removeCourse(String id) async {
    removed.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Course _course(String id, String name) => Course(
  id: id,
  name: name,
  day: 'Mon',
  start: '09:00',
  end: '10:00',
  colorValue: 0xFF3B82F6,
);

Future<void> _pumpList(
  WidgetTester tester,
  _FakeAppState state, {
  List<Course>? opened,
}) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [CourseListSliver(onOpenCourse: (c) => opened?.add(c))],
          ),
        ),
      ),
    ),
  );
}

Future<void> _swipeFirstRow(WidgetTester tester) async {
  await tester.drag(find.text('Algebra'), const Offset(500, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows both courses in order', (tester) async {
    await _pumpList(tester, _FakeAppState());

    final first = tester.getTopLeft(find.text('Algebra'));
    final second = tester.getTopLeft(find.text('Biology'));
    expect(first.dy, lessThan(second.dy));
  });

  testWidgets('tapping a row opens its course', (tester) async {
    final state = _FakeAppState();
    final opened = <Course>[];
    await _pumpList(tester, state, opened: opened);

    await tester.tap(find.text('Algebra'));

    expect(opened, [state.courses.first]);
  });

  testWidgets('confirming a swipe removes the course', (tester) async {
    final state = _FakeAppState();
    await _pumpList(tester, state);

    await _swipeFirstRow(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(state.removed, ['a']);
  });

  testWidgets('cancelling a swipe keeps the course', (tester) async {
    final state = _FakeAppState();
    await _pumpList(tester, state);

    await _swipeFirstRow(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(state.removed, isEmpty);
  });

  testWidgets('long press drag reorders the courses', (tester) async {
    final state = _FakeAppState();
    await _pumpList(tester, state);
    final start = tester.getCenter(find.text('Algebra'));
    final end = tester.getCenter(find.text('Biology'));

    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(Offset(0, (end.dy - start.dy + 20) / 10));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(state.reorders, [(0, 2)]);
  });
}
