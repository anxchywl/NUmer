import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_ui/numer_ui.dart';

import 'home_fakes.dart';
import 'home_harness.dart';

const _offline = 'No connection. Your changes are saved on this device.';
const _failed = 'Could not sync. Your changes are saved on this device.';

List<Course> _courses() => [
  course('a', 'Algebra', credits: 6),
  course('b', 'Biology'),
];

NumerRow _row(WidgetTester tester, String title) => tester.widget<NumerRow>(
  find.byWidgetPredicate((w) => w is NumerRow && w.title == title),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('home keeps no course list or floating action on $platform', (
      tester,
    ) async {
      await HomeHarness(
        state: FakeState(courses: _courses()),
      ).pump(tester, platform: platform);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(CourseListSliver), findsNothing);
      expect(find.text('Algebra'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      // nothing is running, so the mounted widgets paint nothing
      for (final type in [
        AutoFinishWatcher,
        ActiveSessionBar,
        FirstRunCreditsGate,
      ]) {
        expect(find.byType(type, skipOffstage: false), findsOneWidget);
      }
    });
  }

  testWidgets('without courses the button adds one', (tester) async {
    await HomeHarness().pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add course'));
    await tester.pumpAndSettle();

    expect(find.byType(AddCourseSheet), findsOneWidget);
  });

  testWidgets('without a used course the button opens the picker', (
    tester,
  ) async {
    await HomeHarness(state: FakeState(courses: _courses())).pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
    await tester.pumpAndSettle();

    expect(find.text('Select course'), findsOneWidget);
    expect(find.text('Algebra'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
  });

  testWidgets('a used course is continued in its time sheet', (tester) async {
    final home = HomeHarness(state: FakeState(courses: _courses()));
    await home.pump(tester, lastCourseId: 'b');

    await tester.tap(find.widgetWithText(FilledButton, 'Continue Biology'));
    await tester.pumpAndSettle();

    expect(home.state.courseSheetOpen, isTrue);
    expect(find.text('Biology'), findsOneWidget);
  });

  testWidgets('a deleted used course counts as none', (tester) async {
    await HomeHarness(
      state: FakeState(courses: _courses()),
    ).pump(tester, lastCourseId: 'gone');

    expect(find.widgetWithText(FilledButton, 'Start session'), findsOneWidget);
  });

  testWidgets('a running session hides the button', (tester) async {
    final state = FakeState(courses: _courses())
      ..stopwatchRunning = {'a': true};
    await HomeHarness(state: state).pump(tester);

    expect(
      find.descendant(
        of: find.byType(NumerSection),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('the habits row waits for data and counts today', (tester) async {
    final home = HomeHarness();
    await home.pump(tester);
    expect(find.text('Habits'), findsNothing);

    home.habits.emit([]);
    await tester.pumpAndSettle();
    expect(find.text('Habits'), findsNothing);

    home.habits.emit([
      habit('read', done: 1),
      habit('run', done: 1),
      habit('sleep'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3 done'), findsOneWidget);
  });

  testWidgets('a pull reloads the habits', (tester) async {
    final home = HomeHarness();
    await home.pump(tester);
    home.habits.emit([habit('read')]);
    await tester.pumpAndSettle();

    await home.sync.listeners.single();
    await tester.pump();
    home.habits.emit([habit('read', done: 1)]);
    await tester.pumpAndSettle();

    expect(home.habits.controllers, hasLength(2));
    expect(find.text('1 of 1 done'), findsOneWidget);
  });

  testWidgets('the rows open their tabs', (tester) async {
    final home = HomeHarness();
    await home.pump(tester);
    home.habits.emit([habit('read')]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Study'));
    await tester.tap(find.text('Habits'));

    expect(home.studyOpened, 1);
    expect(home.habitsOpened, 1);
  });

  for (final (name, sync, shown) in [
    ('offline', FakeSync(status: SyncStatus.offline), _offline),
    (
      'failed',
      FakeSync(status: SyncStatus.offline, lastError: 'boom'),
      _failed,
    ),
    ('up to date', FakeSync(), null),
  ]) {
    testWidgets('the sync line when $name', (tester) async {
      await HomeHarness(sync: sync).pump(tester);

      for (final line in [_offline, _failed]) {
        expect(find.text(line), line == shown ? findsOneWidget : findsNothing);
      }
    });
  }

  testWidgets('goals off leaves the study row without a subtitle', (
    tester,
  ) async {
    await HomeHarness(state: FakeState(courses: _courses())).pump(tester);

    expect(_row(tester, 'Study').subtitle, isNull);
    expect(_row(tester, 'Study').value, '0 min');
  });

  testWidgets('goals on shows the daily goal of credited courses', (
    tester,
  ) async {
    final state = FakeState(courses: _courses(), goals: ProgressView.week)
      ..studiedSeconds = 3600;
    await HomeHarness(state: state).pump(tester);

    // 6 credits at 2 hours a week, spread over 7 days
    expect(_row(tester, 'Study').subtitle, 'Goal: 1 h of 1 h 42 min');
  });

  testWidgets('pulling forces a sync and asks no module for a token', (
    tester,
  ) async {
    final home = HomeHarness();
    await home.pump(tester);

    await tester.fling(find.text('Today'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(home.sync.forced, [true]);
    expect(home.session.tokenReads, 0);
  });

  testWidgets('an upcoming item appears below today and opens', (tester) async {
    final home = HomeHarness();
    await home.pump(tester);
    expect(find.text('Upcoming'), findsNothing);

    await home.upcoming.put(
      'u1',
      UpcomingItem(
        id: 'clavis:1',
        moduleId: 'clavis',
        kind: UpcomingKind.pianoBooking,
        title: 'Piano room',
        startsAt: DateTime.now().add(const Duration(days: 3)),
        route: '/module/clavis',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Upcoming')).dy,
      greaterThan(tester.getBottomLeft(find.text('Add course')).dy),
    );
    await tester.tap(find.text('Piano room'));
    expect(home.upcomingOpened.single.id, 'clavis:1');
  });
}
