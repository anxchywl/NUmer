import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';
import 'package:numer_app/features/campus/campus.dart';
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

const _names = [
  'Events',
  'Marketplace',
  'Piano room',
  'Map',
  'Library',
  'Dining',
  'Shuttle',
  'Sports',
  'Laundry',
];

var _builds = 0;

ModuleDescriptor _module(String name) => ModuleDescriptor(
  id: name,
  title: (_) => name,
  subtitle: (_) => 'About ${name.toLowerCase()}',
  icon: Icons.map_outlined,
  section: ModuleSection.campus,
  flagId: name,
  builder: (_) {
    _builds++;
    return NumerModuleScaffold(title: name, body: const SizedBox());
  },
);

List<ModuleDescriptor> _modules(int count) => [
  for (final name in _names.take(count)) _module(name),
];

Future<void> _pump(
  WidgetTester tester,
  List<ModuleDescriptor> modules, {
  void Function(ModuleDescriptor)? onOpen,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AppState>(
      create: (_) => _FakeState(),
      child: MaterialApp(
        theme: NumerTheme.build(seed: Colors.indigo, brightness: brightness),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: CampusScreen(modules: modules, onOpen: onOpen ?? (_) {}),
      ),
    ),
  );
}

List<String> _rowTitles(WidgetTester tester) => [
  for (final row in tester.widgetList<NumerRow>(find.byType(NumerRow)))
    row.title,
];

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

void main() {
  setUp(() => _builds = 0);

  testWidgets('no modules shows the header only', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Campus'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byType(NumerBlock), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('No matches.'), findsNothing);
  });

  testWidgets('a module is a row that opens without being built', (
    tester,
  ) async {
    final modules = _modules(1);
    final opened = <ModuleDescriptor>[];
    await _pump(tester, modules, onOpen: opened.add);

    expect(find.byType(NumerRow), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('About events'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.text('Events'));
    await tester.pump();

    expect(opened, [modules.single]);
    expect(_builds, 0);
  });

  testWidgets('eight modules have no search field', (tester) async {
    await _pump(tester, _modules(8));

    expect(find.byType(TextField), findsNothing);
    expect(_rowTitles(tester), _names.take(8));
  });

  testWidgets('typing a title filters to its row', (tester) async {
    await _pump(tester, _modules(9));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byTooltip('Clear'), findsNothing);

    await _search(tester, 'piano ROOM');

    expect(_rowTitles(tester), ['Piano room']);
  });

  testWidgets('a subtitle matches and the registry order stays', (
    tester,
  ) async {
    await _pump(tester, _modules(9));

    await _search(tester, 'about l');

    expect(_rowTitles(tester), ['Library', 'Laundry']);
  });

  testWidgets('the search matches the localized text in any case', (
    tester,
  ) async {
    final localized = ModuleDescriptor(
      id: 'localized',
      title: (l10n) => l10n.navStudy,
      subtitle: (_) => '',
      icon: Icons.map_outlined,
      section: ModuleSection.campus,
      flagId: 'localized',
      builder: (_) => const NumerModuleScaffold(title: '', body: SizedBox()),
    );
    await _pump(tester, [
      ..._modules(8),
      localized,
    ], locale: const Locale('ru'));

    await _search(tester, 'УЧЁ');

    expect(_rowTitles(tester), ['Учёба']);
  });

  testWidgets('no match replaces the block and clearing restores it', (
    tester,
  ) async {
    await _pump(tester, _modules(9));

    await _search(tester, 'zzz');

    expect(find.text('No matches.'), findsOneWidget);
    expect(find.byType(NumerBlock), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(_rowTitles(tester), _names);
    expect(find.text('No matches.'), findsNothing);
    expect(find.byTooltip('Clear'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('losing the field stops the filtering', (tester) async {
    await _pump(tester, _modules(9));
    await _search(tester, 'zzz');

    await _pump(tester, _modules(8));

    expect(find.byType(TextField), findsNothing);
    expect(_rowTitles(tester), _names.take(8));
  });

  testWidgets('the search field is filled and 56 high', (tester) async {
    await _pump(tester, _modules(9));

    final field = find.byType(TextField);
    expect(tester.getSize(field).height, 56);
    final decoration = tester
        .widget<InputDecorator>(find.byType(InputDecorator))
        .decoration;
    expect(decoration.filled, isTrue);
    expect(decoration.enabledBorder!.borderSide, BorderSide.none);

    await _search(tester, 'map');

    expect(tester.getSize(field).height, 56);
  });

  for (final brightness in Brightness.values) {
    for (final language in ['en', 'ru', 'kk']) {
      testWidgets(
        'search holds at text scale 1.3, $language ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await _pump(
            tester,
            _modules(9),
            locale: Locale(language),
            brightness: brightness,
            textScale: 1.3,
          );

          await _search(tester, 'zzz');

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
