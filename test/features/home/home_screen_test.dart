import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeState extends ChangeNotifier implements AppState {
  @override
  List<Course> get courses => [
    Course(
      id: 'a',
      name: 'Algebra',
      day: 'Mon',
      start: '09:00',
      end: '10:00',
      colorValue: 0xFF3B82F6,
    ),
  ];

  @override
  String? get profileName => null;

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  bool get requiresProfileSetup => false;

  @override
  bool get hasProfile => true;

  @override
  int get streakCount => 0;

  @override
  bool get hasStudyToday => false;

  @override
  Map<String, bool> get timerRunning => const {};

  @override
  Map<String, bool> get stopwatchRunning => const {};

  @override
  Map<String, bool> get pomodoroRunning => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSync extends ChangeNotifier implements SyncService {
  @override
  SyncStatus get status => SyncStatus.upToDate;

  @override
  String? get lastError => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('home keeps no course list or floating action on $platform', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
            ChangeNotifierProvider<SyncService>(create: (_) => _FakeSync()),
          ],
          child: MaterialApp(
            theme: NumerTheme.build(
              seed: Colors.indigo,
              brightness: Brightness.light,
            ).copyWith(platform: platform),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(CourseListSliver), findsNothing);
      expect(find.text('Algebra'), findsNothing);
      expect(find.byTooltip('Add course'), findsNothing);
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
}
