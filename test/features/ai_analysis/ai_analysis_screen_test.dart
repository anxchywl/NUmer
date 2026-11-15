import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/ai_analysis/ai_analysis.dart';
import 'package:numer_app/l10n/app_localizations.dart';

void main() {
  const copy = {
    'en': ('Course analysis', 'Course analysis is coming soon.'),
    'ru': ('Анализ курса', 'Анализ курса скоро появится.'),
  };

  for (final MapEntry(key: language, value: (title, body)) in copy.entries) {
    testWidgets('shows the coming soon state in $language', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AiAnalysisScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  }
}
