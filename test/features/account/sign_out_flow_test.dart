import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/auth_gate.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/core/upcoming/upcoming_store.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  String? get displayName => 'Aru';

  @override
  String? get email => 'student@example.test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// the gate stays on its loader until the user is gone
class _FakeAuth extends ChangeNotifier implements AuthController {
  User? user = _FakeUser();

  @override
  User? get currentUser => user;

  @override
  bool get isInitialized => user == null;

  @override
  bool get wasForcedLoggedOut => false;

  @override
  bool consumeAccountDeletedMessage() => false;

  @override
  Map<String, dynamic>? get profile => null;

  @override
  bool get isProfileReady => false;

  @override
  bool get isBusy => false;

  @override
  Future<void> signOut() async {
    user = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeState extends ChangeNotifier implements AppState {
  final calls = <String>[];

  @override
  Future<void> stopAndSaveAllActiveSessions() async => calls.add('stop');

  @override
  Future<void> waitForPendingReflections() async => calls.add('reflections');

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  bool get isLoaded => false;

  @override
  ThemeMode get effectiveThemeMode => ThemeMode.light;

  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  String? get profileName => 'Aru';

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  Color get accentColor => Colors.indigo;

  @override
  WeekStart get weekStart => WeekStart.monday;

  @override
  HomeSummaryRange get homeSummaryRange => HomeSummaryRange.off;

  @override
  ProgressView get progressView => ProgressView.off;

  @override
  bool get quickNotesEnabled => false;

  @override
  bool get allowNudges => false;

  @override
  bool get eisenhowerMatrixEnabled => false;

  @override
  bool get sessionNotificationsEnabled => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSync extends ChangeNotifier implements SyncService {
  int pushes = 0;

  @override
  SyncStatus get status => SyncStatus.upToDate;

  @override
  Future<void> pushNow() async => pushes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _item = UpcomingItem(
  id: 'events:1',
  moduleId: 'events',
  kind: UpcomingKind.eventReminder,
  title: 'Fair',
  startsAt: DateTime.utc(2100),
  route: '/module/events',
);

void main() {
  testWidgets('signing out returns to the auth gate', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Numer',
      packageName: 'numer',
      version: '2.0.0',
      buildNumber: '20',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final upcoming = UpcomingStore(prefs);
    for (final uid in ['u1', 'u2']) {
      await upcoming.put(uid, _item);
    }
    final config = AppConfigService(
      prefs: prefs,
      fetch: () async => null,
      build: 10,
    );
    final auth = _FakeAuth();
    final state = _FakeState();
    final sync = _FakeSync();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppConfigService>.value(value: config),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<SyncService>.value(value: sync),
          ChangeNotifierProvider<UpcomingStore>.value(value: upcoming),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: NumerTheme.build(
            seed: Colors.indigo,
            brightness: Brightness.light,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    // the loaders never settle, so frames are pumped by hand
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(state.calls, ['stop', 'reflections', 'reset']);
    expect(sync.pushes, 1);
    expect(upcoming.upcoming('u1'), isEmpty);
    expect(upcoming.upcoming('u2'), hasLength(1));
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(AuthGate), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });
}
