import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/identity/module_session.dart';
import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/core/upcoming/upcoming_store.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/features/sessions/sessions.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_fakes.dart';

class HomeHarness {
  HomeHarness({FakeState? state, FakeSync? sync})
    : state = state ?? FakeState(),
      sync = sync ?? FakeSync();

  final FakeState state;
  final FakeSync sync;
  final habits = FakeHabits();
  final session = CountingSession();
  late final LastCourseStore lastCourse;
  late final UpcomingStore upcoming;
  final upcomingOpened = <UpcomingItem>[];
  int studyOpened = 0;
  int habitsOpened = 0;

  Future<void> pump(
    WidgetTester tester, {
    String? lastCourseId,
    Locale locale = const Locale('en'),
    TargetPlatform platform = TargetPlatform.android,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'home_last_course_id_v1': ?lastCourseId,
    });
    final prefs = await SharedPreferences.getInstance();
    lastCourse = LastCourseStore(prefs);
    upcoming = UpcomingStore(prefs);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<SyncService>.value(value: sync),
          ChangeNotifierProvider<AuthController>(create: (_) => FakeAuth()),
          ChangeNotifierProvider<LastCourseStore>.value(value: lastCourse),
          Provider<HabitService>.value(value: habits),
          Provider<ModuleSession>.value(value: session),
          ChangeNotifierProvider<UpcomingStore>.value(value: upcoming),
        ],
        child: MaterialApp(
          theme: NumerTheme.build(
            seed: Colors.indigo,
            brightness: Brightness.light,
          ).copyWith(platform: platform),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: HomeScreen(
            onOpenStudy: () => studyOpened++,
            onOpenHabits: () => habitsOpened++,
            openUpcoming: (_, item) {
              upcomingOpened.add(item);
              return true;
            },
          ),
        ),
      ),
    );
  }
}
