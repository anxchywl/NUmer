import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/widgets/accent_color_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:numer_app/l10n/app_localizations.dart';

void main() {
  testWidgets('AccentColorPicker renders and updates color', (WidgetTester tester) async {
    Color selectedColor = Colors.indigo;
    
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AccentColorPicker(
            currentColor: selectedColor,
            onColorChanged: (color) {
              selectedColor = color;
            },
            onSave: () {},
          ),
        ),
      ),
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(AccentColorPicker)))!;

    // Verify sliders exist
    expect(find.text(l10n.hue), findsOneWidget);
    expect(find.text(l10n.saturation), findsOneWidget);
    expect(find.text(l10n.lightness), findsOneWidget);

    // Verify presets exist
    expect(find.text(l10n.defaultPreset), findsOneWidget);
    expect(find.text(l10n.emeraldPreset), findsOneWidget);

    // Test tapping a preset
    await tester.tap(find.text(l10n.emeraldPreset));
    await tester.pump();

    // Verify color changed to Emerald (callback updated local variable)
    expect(selectedColor.toARGB32(), const Color(0xFF10B981).toARGB32());

    // Test Save (just verify it exists and is tappable)
    await tester.tap(find.text(l10n.save));
    await tester.pump();
  });
}
