import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/stats/models/stats_models.dart';
import 'package:numer_app/features/stats/widgets/habit_statistics.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHabits implements HabitService {
  @override
  Stream<List<Habit>> habitsStream(String userId) => Stream.value([
    Habit(
      id: 'h1',
      name: 'Read',
      color: Colors.blue,
      iconCodePoint: Icons.school.codePoint,
      category: 'Study',
      type: HabitType.yesNo,
      targetValue: 1,
      comparator: HabitComparator.atLeast,
      frequencyType: HabitFrequencyType.daily,
      startDate: DateTime(2026),
      createdAt: DateTime(2026),
    ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// the default test font is far wider than the system one, so wrapping would lie
Future<void> _loadRoboto() {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final bytes = File(
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ).readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  return loader.load();
}

void main() {
  setUpAll(_loadRoboto);

  for (final scale in [1.0, 1.15, 1.3]) {
    testWidgets('the habit card fits Kazakh labels at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FirebaseAuth?>.value(value: _FakeFirebaseAuth()),
            Provider<HabitService>.value(value: _FakeHabits()),
          ],
          child: MaterialApp(
            theme: NumerTheme.build(
              seed: Colors.indigo,
              brightness: Brightness.light,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('kk'),
            home: Scaffold(
              body: HabitStatistics(
                statsByHabit: const {'h1': HabitStatsResult(10, 7, 3, 70)},
                loading: false,
                pageController: controller,
                reportMonth: DateTime(2026, 5),
                onLoadStats: (_) {},
                onHabitsShown: (_) {},
                onHabitSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
