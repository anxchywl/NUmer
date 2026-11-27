import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/shell/shell_tabs.dart';
import 'package:numer_app/core/config/app_config.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/ai_analysis/ai_analysis.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/features/stats/stats.dart';
import 'package:numer_app/features/study/study.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeState extends ChangeNotifier implements AppState {
  _FakeState([this.courses = const []]);

  @override
  final List<Course> courses;

  @override
  String? get profileName => null;

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  HomeSummaryRange get homeSummaryRange => HomeSummaryRange.off;

  @override
  ProgressView get progressView => ProgressView.off;

  @override
  double? goalHoursForCourse(String id) => null;

  @override
  Map<String, bool> get timerRunning => const {};

  @override
  Map<String, bool> get stopwatchRunning => const {};

  @override
  Map<String, bool> get pomodoroRunning => const {};

  final List<bool> sheetOpen = [];

  @override
  void setCourseSheetOpen(bool value) => sheetOpen.add(value);

  @override
  Map<String, bool> get pomodoroPaused => const {};

  @override
  Map<String, DateTime?> get timerStart => const {};

  @override
  Duration currentElapsedTimer(String courseId) => Duration.zero;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends ChangeNotifier implements AuthController {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes extends NavigatorObserver {
  Route<dynamic>? last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    last = route;
  }
}

Course _course(String id, String name) => Course(
  id: id,
  name: name,
  day: 'Mon',
  start: '09:00',
  end: '10:00',
  colorValue: 0xFF3B82F6,
);

List<Course> _twoCourses() => [
  _course('a', 'Algebra'),
  _course('b', 'Biology'),
];

Widget _app(Widget home, {_Routes? routes}) => MaterialApp(
  theme: NumerTheme.build(seed: Colors.indigo, brightness: Brightness.light),
  navigatorObservers: [?routes],
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _pump(
  WidgetTester tester, {
  _FakeState? state,
  _Routes? routes,
  List<Course> courses = const [],
  List<ModuleDescriptor> modules = const [],
  List<ModuleDescriptor>? opened,
}) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AppState>(
      create: (_) => state ?? _FakeState(courses),
      child: _app(
        StudyScreen(
          modules: modules,
          onOpenModule: (module) => opened?.add(module),
        ),
        routes: routes,
      ),
    ),
  );
}

// the study tab as the shell builds it, with a test registry
Future<void> _pumpShellStudy(
  WidgetTester tester,
  ModuleDescriptor module,
) async {
  SharedPreferences.setMockInitialValues({
    'app_config_v1': AppConfig.fromMap({
      'modules': {
        module.flagId: {
          'enabled': true,
          'allow': ['u1'],
        },
      },
    }).toJson(),
  });
  final config = AppConfigService(
    prefs: await SharedPreferences.getInstance(),
    fetch: () async => null,
    build: 10,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigService>.value(value: config),
        ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
      ],
      child: _app(
        Builder(
          builder: (context) => buildShellTabs(
            context,
            registry: [module],
          ).singleWhere((tab) => tab.label == 'Study').builder(context),
        ),
      ),
    ),
  );
}

ModuleDescriptor _gpaModule(VoidCallback onBuild) => ModuleDescriptor(
  id: 'gpa',
  title: (_) => 'GPA',
  subtitle: (_) => 'Grades and average',
  icon: Icons.calculate_outlined,
  section: ModuleSection.study,
  flagId: 'gpa',
  builder: (_) {
    onBuild();
    return const NumerModuleScaffold(title: 'GPA', body: SizedBox());
  },
);

List<String> _rowTitles(WidgetTester tester) => [
  for (final row in tester.widgetList<NumerRow>(find.byType(NumerRow)))
    row.title,
];

void main() {
  for (final (title, matcher, courses) in [
    ('Statistics', isA<StatsScreen>(), <Course>[]),
    ('History', isA<HistoryScreen>(), <Course>[]),
    ('Course analysis', isA<AiAnalysisScreen>(), _twoCourses()),
  ]) {
    testWidgets('the $title row opens its screen', (tester) async {
      final routes = _Routes();
      await _pump(tester, routes: routes, courses: courses);

      await tester.tap(find.text(title));
      final route = routes.last! as MaterialPageRoute<void>;

      // the pushed screen needs the full app state, so it is never mounted
      expect(route.builder(tester.element(find.byType(StudyScreen))), matcher);
      route.navigator!.removeRoute(route);
    });
  }

  testWidgets('without courses it offers to add one', (tester) async {
    await _pump(tester);

    expect(find.text('No courses yet.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add course'), findsOneWidget);
    expect(find.byType(CourseListSliver), findsNothing);
    expect(_rowTitles(tester), ['Statistics', 'History']);
  });

  testWidgets('with courses it lists them above course analysis', (
    tester,
  ) async {
    await _pump(tester, courses: _twoCourses());

    expect(find.text('Algebra'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.byType(NumerEmptyState), findsNothing);
    expect(_rowTitles(tester), ['Statistics', 'History', 'Course analysis']);
    final analysis = tester.widget<NumerRow>(
      find.widgetWithText(NumerRow, 'Course analysis'),
    );
    expect(analysis.showChevron, isFalse);
    expect(
      find.widgetWithText(NumerStatusLabel, 'Coming soon'),
      findsOneWidget,
    );
  });

  testWidgets('a study module is the last row and opens through the host', (
    tester,
  ) async {
    final module = _gpaModule(() {});
    final opened = <ModuleDescriptor>[];
    await _pump(
      tester,
      courses: _twoCourses(),
      modules: [module],
      opened: opened,
    );

    expect(_rowTitles(tester), [
      'Statistics',
      'History',
      'Course analysis',
      'GPA',
    ]);
    expect(find.text('Grades and average'), findsOneWidget);
    await tester.tap(find.text('GPA'));

    expect(opened, [module]);
  });

  testWidgets('the shell builds a study module only when its row is tapped', (
    tester,
  ) async {
    var built = 0;
    await _pumpShellStudy(tester, _gpaModule(() => built++));

    expect(built, 0);
    await tester.tap(find.text('GPA'));
    await tester.pumpAndSettle();

    expect(built, 1);
    expect(find.byType(NumerModuleScaffold), findsOneWidget);
  });

  testWidgets('tapping a course row opens its time sheet', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = _FakeState(_twoCourses());
    await _pump(tester, state: state);

    await tester.tap(find.text('Algebra'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Algebra')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(TabBarView)),
      findsOneWidget,
    );
    expect(state.sheetOpen, [true]);
  });

  testWidgets('the header adds a course and nothing floats', (tester) async {
    await _pump(tester, courses: _twoCourses());

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(AddCourseSheet), findsNothing);
    await tester.tap(find.byTooltip('Add course'));
    await tester.pumpAndSettle();

    expect(find.byType(AddCourseSheet), findsOneWidget);
  });
}
