import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

class _FakeState extends ChangeNotifier implements AppState {
  @override
  String? get profileName => 'Aru';

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedOutAuth extends ChangeNotifier implements AuthController {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes extends NavigatorObserver {
  final pushed = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
  }
}

const _page = Scaffold(
  body: CustomScrollView(slivers: [ShellHeader(title: Text('Study'))]),
);

Future<void> _pump(WidgetTester tester, _Routes routes, {bool nested = true}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
        ChangeNotifierProvider<AuthController>(create: (_) => _SignedOutAuth()),
      ],
      child: MaterialApp(
        theme: NumerTheme.build(
          seed: Colors.indigo,
          brightness: Brightness.light,
        ),
        navigatorObservers: [routes],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: nested
            ? Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => _page),
              )
            : _page,
      ),
    ),
  );
}

void main() {
  testWidgets('the avatar opens settings on the root navigator', (
    tester,
  ) async {
    final routes = _Routes();
    await _pump(tester, routes);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(routes.pushed.last, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('the avatar button is a full touch target', (tester) async {
    await _pump(tester, _Routes());

    final size = tester.getSize(
      find.ancestor(
        of: find.byType(UniversalAvatar),
        matching: find.byType(IconButton),
      ),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a second press opens no second settings', (tester) async {
    final routes = _Routes();
    await _pump(tester, routes, nested: false);

    // two presses delivered in one frame, before settings covers the avatar
    final avatar = tester.widget<IconButton>(find.byType(IconButton));
    avatar.onPressed!();
    avatar.onPressed!();
    await tester.pumpAndSettle();

    expect(routes.pushed.where((name) => name == '/settings'), hasLength(1));
  });
}
