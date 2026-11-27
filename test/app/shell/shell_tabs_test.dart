import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/shell/shell_tabs.dart';
import 'package:numer_app/core/config/app_config.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/auth/auth.dart';
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ModuleDescriptor _campusModule() => ModuleDescriptor(
  id: 'map',
  title: (_) => 'Map',
  subtitle: (_) => 'Rooms',
  icon: Icons.map_outlined,
  section: ModuleSection.campus,
  flagId: 'map',
  builder: (_) => const NumerModuleScaffold(title: 'Map', body: SizedBox()),
);

Future<List<ShellTab>> _tabs(
  WidgetTester tester, {
  List<ModuleDescriptor> registry = const [],
  List<String> allow = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'app_config_v1': AppConfig.fromMap({
      'modules': {
        'map': {'enabled': true, 'allow': allow},
      },
    }).toJson(),
  });
  final config = AppConfigService(
    prefs: await SharedPreferences.getInstance(),
    fetch: () async => null,
    build: 10,
  );
  late List<ShellTab> tabs;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfigService>.value(value: config),
        ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            tabs = buildShellTabs(context, registry: registry);
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return tabs;
}

void main() {
  testWidgets('without a visible module there are four tabs', (tester) async {
    final tabs = await _tabs(tester);

    expect(tabs.map((tab) => tab.label), ['Home', 'Habits', 'Study', 'Groups']);
    expect(tabs.map((tab) => tab.icon), [
      Icons.home_outlined,
      Icons.check_circle_outline,
      Icons.school_outlined,
      Icons.group_outlined,
    ]);
    expect(tabs.map((tab) => tab.selectedIcon), [
      Icons.home,
      Icons.check_circle,
      Icons.school,
      Icons.group,
    ]);
  });

  testWidgets('a visible campus module adds the campus tab last', (
    tester,
  ) async {
    final tabs = await _tabs(
      tester,
      registry: [_campusModule()],
      allow: ['u1'],
    );

    expect(tabs, hasLength(5));
    expect(tabs.last.label, 'Campus');
    expect(tabs.last.icon, Icons.apartment_outlined);
    expect(tabs.last.selectedIcon, Icons.apartment);
  });

  testWidgets('a hidden campus module adds no tab', (tester) async {
    final tabs = await _tabs(
      tester,
      registry: [_campusModule()],
      allow: ['someone-else'],
    );

    expect(tabs, hasLength(4));
  });
}
