import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/stats/models/stats_models.dart';
import 'package:numer_app/features/stats/widgets/habit_report_selection_view.dart';
import 'package:numer_app/features/stats/widgets/period_range_selector.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app(Widget body) => MaterialApp(
  theme: NumerTheme.build(seed: Colors.indigo, brightness: Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: body),
);

void main() {
  testWidgets('the range segments report the chosen range', (tester) async {
    final chosen = <Range>[];
    await tester.pumpWidget(
      _app(PeriodRangeControl(range: Range.week, onSetRange: chosen.add)),
    );
    expect(find.byType(SegmentedButton<Range>), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('Month'));
    await tester.tap(find.text('Year'));

    expect(chosen, [Range.month, Range.year]);
  });

  testWidgets('the format segments report the chosen format', (tester) async {
    final chosen = <String>[];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => HabitReportSelectionView(
            l10n: AppLocalizations.of(context)!,
            theme: Theme.of(context),
            selectedMonth: DateTime(2026, 5),
            selectedFormat: 'excel',
            onMonthChanged: (_) {},
            onFormatChanged: chosen.add,
          ),
        ),
      ),
    );
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('CSV'));

    expect(chosen, ['csv']);
  });
}
