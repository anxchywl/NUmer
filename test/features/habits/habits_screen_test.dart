import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
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
  @override
  Stream<List<Habit>> habitsStream(String userId) => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeState extends ChangeNotifier implements AppState {
  @override
  WeekStart get weekStart => WeekStart.monday;

  @override
  bool get eisenhowerMatrixEnabled => false;

  @override
  String? get profileName => null;

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, TargetPlatform platform) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
        Provider<HabitService>.value(value: _FakeHabits()),
      ],
      child: MaterialApp(
        theme: NumerTheme.build(
          seed: Colors.indigo,
          brightness: Brightness.light,
        ).copyWith(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const HabitsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('the habit list has one add action on ${platform.name}', (
      tester,
    ) async {
      await _pump(tester, platform);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('My habits'));
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.text('Add habit')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(fab).dx,
        greaterThan(tester.getSize(find.byType(HabitsScreen)).width / 2),
      );
    });
  }
}
