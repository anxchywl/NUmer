import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeUser implements User {
  @override
  String get uid => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends ChangeNotifier implements AuthController {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHabits implements HabitService {
  final created = <(String, Habit)>[];
  final createdCategories = <HabitCategory>[];

  @override
  Stream<List<HabitCategory>> getCategories(String uid) => Stream.value([]);

  @override
  Future<void> createHabit(String userId, Habit habit) async {
    created.add((userId, habit));
  }

  @override
  Future<void> createCategory(String uid, HabitCategory category) async {
    createdCategories.add(category);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppState extends ChangeNotifier implements AppState {
  @override
  WeekStart get weekStart => WeekStart.monday;

  @override
  List<Course> get courses => const [
    Course(
      id: 'course-1',
      name: 'Calculus',
      day: 'Mon',
      start: '09:00',
      end: '10:00',
      colorValue: 0xFF2196F3,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeHabits> _openSheet(WidgetTester tester, {Habit? habit}) async {
  final habits = _FakeHabits();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<AppState>(create: (_) => _FakeAppState()),
        Provider<HabitService>.value(value: habits),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddHabitSheet(habit: habit),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return habits;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _nameAndContinue(WidgetTester tester, String name) async {
  await _enter(tester, find.byType(TextFormField), name);
  await _tap(tester, find.text('Next'));
}

SegmentedButton<HabitType> _typeButton(WidgetTester tester) =>
    tester.widget(find.byType(SegmentedButton<HabitType>));

void main() {
  testWidgets('creates a daily yes or no habit', (tester) async {
    final habits = await _openSheet(tester);

    await _nameAndContinue(tester, 'Read');
    await _tap(tester, find.text('Calculus'));
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Create habit'));

    final (uid, habit) = habits.created.single;
    expect(uid, 'user-1');
    expect(habit.name, 'Read');
    expect(habit.category, 'Study');
    expect(habit.type, HabitType.yesNo);
    expect(habit.targetValue, 1);
    expect(habit.frequencyType, HabitFrequencyType.daily);
    expect(habit.connectedCourseIds, ['course-1']);
    expect(find.byType(AddHabitSheet), findsNothing);
  });

  testWidgets('picks the habit type with one segmented control', (
    tester,
  ) async {
    await _openSheet(tester);
    await _nameAndContinue(tester, 'Water');
    expect(find.byType(SegmentedButton<HabitType>), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await _tap(tester, find.text('Numeric'));

    expect(_typeButton(tester).selected, {HabitType.numeric});
    expect(find.widgetWithText(TextFormField, 'Unit'), findsOneWidget);
  });

  testWidgets('creates a numeric habit on specific days', (tester) async {
    final habits = await _openSheet(tester);

    await _nameAndContinue(tester, 'Water');
    await _tap(tester, find.text('Numeric'));
    await _enter(tester, find.widgetWithText(TextFormField, 'Value'), '20000');
    await _enter(tester, find.widgetWithText(TextFormField, 'Unit'), 'ml');
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Specific days'));
    await _tap(tester, find.text('M'));
    await _tap(tester, find.text('F'));
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Create habit'));

    final habit = habits.created.single.$2;
    expect(habit.name, 'Water');
    expect(habit.type, HabitType.numeric);
    expect(habit.targetValue, 10000);
    expect(habit.unit, 'ml');
    expect(habit.frequencyType, HabitFrequencyType.specificDays);
    expect(habit.frequencyPeriod, HabitPeriod.week);
    expect(habit.weekDays, {1, 5});
  });

  testWidgets('creates a time habit on a work and rest cycle', (tester) async {
    final habits = await _openSheet(tester);

    await _nameAndContinue(tester, 'Gym');
    await _tap(tester, find.text('Time'));
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Work / Rest'));
    await _enter(tester, find.byKey(const ValueKey('work_days_input')), '999');
    await _enter(tester, find.byKey(const ValueKey('rest_days_input')), '2');
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Create habit'));

    final habit = habits.created.single.$2;
    expect(habit.name, 'Gym');
    expect(habit.type, HabitType.time);
    expect(habit.targetValue, 0);
    expect(habit.frequencyType, HabitFrequencyType.interval);
    expect(habit.intervalDays, 365);
    expect(habit.frequencyGoal, 2);
  });

  testWidgets('clamps a times per period goal to the period', (tester) async {
    final habits = await _openSheet(tester);

    await _nameAndContinue(tester, 'Run');
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Days per period'));
    final goal = find.byKey(const ValueKey('frequency_goal_input'));
    await _enter(tester, goal, '40');
    await _tap(tester, find.text('WEEK'));
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Create habit'));

    final habit = habits.created.single.$2;
    expect(habit.frequencyType, HabitFrequencyType.repeatsInPeriod);
    expect(habit.frequencyPeriod, HabitPeriod.month);
    expect(habit.frequencyGoal, 7);
  });

  testWidgets('creates a category and selects it', (tester) async {
    final habits = await _openSheet(tester);

    await _tap(tester, find.text('Create custom'));
    await _enter(tester, find.byType(TextField).last, 'Garden');
    await _tap(tester, find.text('Save'));

    expect(habits.createdCategories.single.name, 'Garden');
    expect(find.text('Create custom'), findsOneWidget);
  });

  testWidgets('keeps the old rule when an edit changes the target', (
    tester,
  ) async {
    final old = Habit(
      id: 'habit-1',
      name: 'Pages',
      color: Colors.blue,
      iconCodePoint: Icons.school.codePoint,
      category: 'Study',
      type: HabitType.numeric,
      targetValue: 5,
      unit: 'pages',
      comparator: HabitComparator.atLeast,
      frequencyType: HabitFrequencyType.daily,
      startDate: DateTime(2026, 1, 5),
      createdAt: DateTime(2026, 1, 5),
    );
    final habits = await _openSheet(tester, habit: old);

    await _tap(tester, find.text('Next'));
    expect(
      _typeButton(tester).segments.where((s) => s.enabled).map((s) => s.value),
      [HabitType.numeric],
    );
    await _enter(tester, find.widgetWithText(TextFormField, 'Value'), '8');
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Next'));
    await _tap(tester, find.text('Create habit'));

    final habit = habits.created.single.$2;
    expect(habit.id, 'habit-1');
    expect(habit.targetValue, 8);
    expect(habit.previousRules.single.targetValue, 5);
  });
}
