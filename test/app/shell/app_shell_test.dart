import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/shell/android_tab_bar.dart';
import 'package:numer_app/app/shell/app_shell.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/campus/campus.dart';
import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool get isProfileReady => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// an empty signed in state with nothing running
class _FakeState extends ChangeNotifier implements AppState {
  @override
  List<Course> get courses => const [];

  @override
  String? get profileName => null;

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  int get streakCount => 0;

  @override
  bool get hasStudyToday => false;

  @override
  bool get requiresProfileSetup => true;

  @override
  String? get activeSessionKind => null;

  @override
  String? get activeSessionCourseId => null;

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

// the shrinking page view lands on groups for a frame before jumping home
class _FakeGroups implements GroupService {
  @override
  Stream<List<GroupMembership>> watchUserMemberships(String uid) =>
      const Stream.empty();

  @override
  Stream<List<Group>> watchPublicGroups() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _module = ModuleDescriptor(
  id: 'map',
  title: (_) => 'Map',
  subtitle: (_) => 'Rooms',
  icon: Icons.map_outlined,
  section: ModuleSection.campus,
  flagId: 'map',
  builder: (_) => const NumerModuleScaffold(title: 'Map', body: SizedBox()),
);

void main() {
  testWidgets('losing the selected campus tab returns to home', (tester) async {
    var enabled = true;
    SharedPreferences.setMockInitialValues({});
    final config = AppConfigService(
      prefs: await SharedPreferences.getInstance(),
      fetch: () async => {
        'modules': {
          'map': {
            'enabled': enabled,
            'allow': ['u1'],
          },
        },
      },
      build: 10,
    );
    await config.refresh();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppConfigService>.value(value: config),
          ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
          ChangeNotifierProvider<SyncService>(create: (_) => _FakeSync()),
          Provider<GroupService>(create: (_) => _FakeGroups()),
        ],
        child: MaterialApp(
          theme: NumerTheme.build(
            seed: Colors.indigo,
            brightness: Brightness.light,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppShell(registry: [_module]),
        ),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AndroidTabBar),
        matching: find.text('Campus'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CampusScreen), findsOneWidget);

    enabled = false;
    await config.refresh(force: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CampusScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final bar = tester.widget<AndroidTabBar>(find.byType(AndroidTabBar));
    expect(bar.currentIndex, 0);
    expect(bar.tabs, hasLength(4));
  });
}
