import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/update_required_screen.dart';
import 'package:numer_app/l10n/app_localizations.dart';

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
  home: const UpdateRequiredScreen(),
);

void main() {
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
