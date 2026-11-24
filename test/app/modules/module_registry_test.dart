import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/modules/module_registry.dart';
import 'package:numer_app/app/modules/open_module.dart';
import 'package:numer_app/core/config/app_config.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _builds = <String, int>{};

ModuleDescriptor _descriptor(String id, ModuleSection section) =>
    ModuleDescriptor(
      id: id,
      title: (_) => id,
      subtitle: (_) => id,
      icon: Icons.apps,
      section: section,
      flagId: id,
      builder: (_) {
        _builds[id] = (_builds[id] ?? 0) + 1;
        return const NumerModuleScaffold(title: 'x', body: SizedBox());
      },
    );

final _registry = [
  _descriptor('b', ModuleSection.campus),
  _descriptor('a', ModuleSection.campus),
  _descriptor('s', ModuleSection.study),
];

Future<AppConfigService> _config() async {
  const flag = ModuleFlag(
    enabled: true,
    rollout: 0,
    allow: ['u1'],
    minBuild: 0,
  );
  const off = ModuleFlag(enabled: false, rollout: 0, allow: [], minBuild: 0);
  SharedPreferences.setMockInitialValues({
    'app_config_v1': const AppConfig(
      minSupportedBuild: 0,
      modules: {'a': flag, 'b': off, 's': flag, 'c': flag},
    ).toJson(),
  });
  return AppConfigService(
    prefs: await SharedPreferences.getInstance(),
    fetch: () async => null,
    build: 1,
  );
}

class _Recorder extends NavigatorObserver {
  Route<dynamic>? pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed = route;
  }
}

void main() {
  setUp(_builds.clear);

  test('only allowed and enabled modules are visible', () async {
    final config = await _config();
    final campus = visibleModules(
      ModuleSection.campus,
      config,
      'u1',
      registry: _registry,
    );
    expect(campus.map((d) => d.id), ['a']);
    expect(
      visibleModules(ModuleSection.campus, config, 'u2', registry: _registry),
      isEmpty,
    );
  });

  test('keeps registry order and filters by section', () async {
    final config = await _config();
    final registry = [_descriptor('c', ModuleSection.campus), ..._registry];
    expect(
      visibleModules(
        ModuleSection.campus,
        config,
        'u1',
        registry: registry,
      ).map((d) => d.id),
      ['c', 'a'],
    );
    expect(
      visibleModules(
        ModuleSection.study,
        config,
        'u1',
        registry: registry,
      ).map((d) => d.id),
      ['s'],
    );
  });

  testWidgets('a module is built only when opened', (tester) async {
    final config = await _config();
    final visible = visibleModules(
      ModuleSection.campus,
      config,
      'u1',
      registry: _registry,
    );
    final recorder = _Recorder();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [recorder],
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                for (final d in visible)
                  NumerRow(title: d.id, onTap: () => openModule(context, d)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(_builds, isEmpty);

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(_builds['a'], 1);
    expect(recorder.pushed?.settings.name, '/module/a');
    expect(recorder.pushed?.isCurrent, isTrue);
    expect(recorder.pushed?.navigator, tester.state(find.byType(Navigator)));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(_builds['a'], 2);
  });
}
