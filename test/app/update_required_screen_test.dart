import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/auth_gate.dart';
import 'package:numer_app/app/update_required_screen.dart';
import 'package:numer_app/core/config/app_config.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _screen(Locale locale, {double textScale = 1}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: UpdateRequiredScreen(onRecheck: () async {}),
);

// keeps the gate on its loader once the update screen is lifted
class _FakeAuth extends ChangeNotifier implements AuthController {
  @override
  bool get isInitialized => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConfig {
  int minimum = 11;
  int calls = 0;

  Future<Map<String, dynamic>?> fetch() async {
    calls++;
    return {'minSupportedBuild': minimum};
  }
}

// a gate blocked by the cache, after one successful read so the throttle applies
Future<void> _pumpBlockedGate(WidgetTester tester, _FakeConfig remote) async {
  SharedPreferences.setMockInitialValues({
    'app_config_v1': const AppConfig(
      minSupportedBuild: 11,
      modules: {},
    ).toJson(),
  });
  final config = AppConfigService(
    prefs: await SharedPreferences.getInstance(),
    fetch: remote.fetch,
    build: 10,
  );
  await config.refresh();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigService>.value(value: config),
        ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<AppState>(create: (_) => AppState()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthGate(),
      ),
    ),
  );
}

Future<void> _moveThrough(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  testWidgets('rechecks every 60 s and lifts the gate', (tester) async {
    final remote = _FakeConfig();
    await _pumpBlockedGate(tester, remote);

    await tester.pump(const Duration(seconds: 59));
    expect(remote.calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(remote.calls, 2);
    expect(find.byType(UpdateRequiredScreen), findsOneWidget);

    remote.minimum = 10;
    await tester.pump(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(UpdateRequiredScreen), findsNothing);

    await tester.pump(const Duration(minutes: 5));
    expect(remote.calls, 3);
  });

  testWidgets('rechecks on every resume and not in the background', (
    tester,
  ) async {
    final remote = _FakeConfig();
    await _pumpBlockedGate(tester, remote);

    await _moveThrough(tester, _toBackground);
    await tester.pump(const Duration(minutes: 5));
    expect(remote.calls, 1);

    await _moveThrough(tester, _toForeground);
    expect(remote.calls, 2);

    await _moveThrough(tester, _toBackground);
    remote.minimum = 10;
    await _moveThrough(tester, _toForeground);
    await tester.pump(const Duration(seconds: 1));
    expect(remote.calls, 3);
    expect(find.byType(UpdateRequiredScreen), findsNothing);
  });

  testWidgets('shows the title, body and action', (tester) async {
    await tester.pumpWidget(_screen(const Locale('en')));

    expect(find.text('Update NUmer'), findsOneWidget);
    expect(
      find.text(
        'This version is no longer supported. '
        'Install the latest version to continue.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('holds at text scale 1.3 in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen(locale, textScale: 1.3));

      expect(tester.takeException(), isNull);
      final button = tester.getSize(find.byType(FilledButton));
      expect(button.width, 320 - 32);
      expect(button.height, greaterThanOrEqualTo(48));
    });
  }
}
