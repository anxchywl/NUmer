import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/account/widgets/settings/settings_appearance_section.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

class _Appearance extends FakeState {
  final presets = <String>[];

  @override
  Color get accentColor => Colors.indigo;
  @override
  ThemeMode get themeMode => ThemeMode.light;
  @override
  List<({String name, int colorValue})> get userColorPresets => [];

  @override
  Future<void> addUserColorPreset(String name, Color color) async =>
      presets.add(name);
}

Future<_Appearance> _openNaming(WidgetTester tester) async {
  final state = _Appearance();
  await openSheet(
    tester,
    (context) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SettingsAppearanceSection()),
      ),
    ),
    providers: [ChangeNotifierProvider<AppState>.value(value: state)],
    // the preview row does not fit a phone width in the square test font
    width: 500,
  );
  await tester.tap(find.text('Accent color'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Create preset'));
  await tester.tap(find.text('Create preset'));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('naming a preset keeps the name and save', (tester) async {
    await _openNaming(tester);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await typeIn(tester, find.byType(TextFormField));

    expect(find.text('Accent color'), findsOneWidget);
    expect(find.text('Presets'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Save'));

    await hideKeyboard(tester);

    expect(find.text('Accent color'), findsNWidgets(2));
    expect(find.text('Presets'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('save while typing adds the preset', (tester) async {
    final state = await _openNaming(tester);
    await typeIn(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Sea');

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(state.presets, ['Sea']);
    expect(find.text('Presets'), findsOneWidget);
  });
}
