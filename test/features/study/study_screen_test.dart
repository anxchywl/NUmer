import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/features/stats/stats.dart';
import 'package:numer_app/features/study/study.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

class _FakeState extends ChangeNotifier implements AppState {
  @override
  String? get profileName => null;

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

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

Future<void> _pump(WidgetTester tester, _Routes routes) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AppState>(
      create: (_) => _FakeState(),
      child: MaterialApp(
        theme: NumerTheme.build(
          seed: Colors.indigo,
          brightness: Brightness.light,
        ),
        navigatorObservers: [routes],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StudyScreen(),
      ),
    ),
  );
}

void main() {
  for (final (title, matcher) in [
    ('Statistics', isA<StatsScreen>()),
    ('History', isA<HistoryScreen>()),
  ]) {
    testWidgets('the $title row opens its screen', (tester) async {
      final routes = _Routes();
      await _pump(tester, routes);

      await tester.tap(find.text(title));
      final route = routes.last! as MaterialPageRoute<void>;

      // the pushed screen needs the full app state, so it is never mounted
      expect(route.builder(tester.element(find.byType(StudyScreen))), matcher);
      route.navigator!.removeRoute(route);
    });
  }

  testWidgets('statistics and history are rows that navigate', (tester) async {
    await _pump(tester, _Routes());

    final rows = tester.widgetList<NumerRow>(find.byType(NumerRow)).toList();
    expect(rows.map((row) => row.title), ['Statistics', 'History']);
    expect(rows.every((row) => row.showChevron), isTrue);
    expect(rows.every((row) => row.onTap != null), isTrue);
  });
}
