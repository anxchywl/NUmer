import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _seed = Color.fromARGB(255, 68, 138, 255);

void main() {
  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      final theme = NumerTheme.build(seed: _seed, brightness: brightness);
      final scheme = ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      );

      test('keeps the seeded material 3 scheme and semantic colours', () {
        final colors = brightness == Brightness.dark
            ? NumerColors.dark
            : NumerColors.light;

        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.primary, scheme.primary);
        expect(theme.extension<NumerColors>(), colors);
      });

      test('sheets, app bars and the floating action are flat', () {
        final sheet = theme.bottomSheetTheme;
        final shape = sheet.shape! as RoundedRectangleBorder;

        expect(
          shape.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(20)),
        );
        expect(sheet.backgroundColor, scheme.surfaceContainerLow);
        expect(sheet.modalBackgroundColor, scheme.surfaceContainerLow);
        expect(sheet.showDragHandle, isNull);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.floatingActionButtonTheme.elevation, 0);
        expect(theme.floatingActionButtonTheme.highlightElevation, 0);
      });

      test('a selected switch takes the seed', () {
        final thumb = theme.switchTheme.thumbColor!;

        expect(thumb.resolve({WidgetState.selected}), _seed);
        expect(thumb.resolve({}), isNull);
      });

      testWidgets('a filled button is 48 high with radius 12', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: FilledButton(onPressed: () {}, child: const Text('Go')),
              ),
            ),
          ),
        );
        final surface = find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        );
        final shape =
            tester.widget<Material>(surface).shape! as RoundedRectangleBorder;

        expect(tester.getSize(surface).height, 48);
        expect(shape.borderRadius, BorderRadius.circular(12));
      });

      testWidgets('a text field is filled and outlined only on focus', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: TextField()),
          ),
        );
        InputDecoration decoration() => tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration;
        final idle = decoration().enabledBorder! as OutlineInputBorder;
        final focused = decoration().focusedBorder! as OutlineInputBorder;

        expect(decoration().filled, isTrue);
        expect(decoration().fillColor, scheme.surfaceContainerHighest);
        expect(idle.borderSide, BorderSide.none);
        expect(idle.borderRadius, BorderRadius.circular(12));
        expect(focused.borderSide.color, scheme.primary);
        expect(focused.borderSide.width, 2);
      });
    });
  }
}
