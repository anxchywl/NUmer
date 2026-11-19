import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/stats/models/stats_models.dart';
import 'package:numer_app/features/stats/stats_format.dart';
import 'package:numer_app/l10n/app_localizations.dart';

void main() {
  test('fmtHMS pads hours, minutes and seconds', () {
    expect(fmtHMS(0), '00:00:00');
    expect(fmtHMS(59), '00:00:59');
    expect(fmtHMS(3661), '01:01:01');
    expect(fmtHMS(360000), '100:00:00');
  });

  test('pickUnit switches at one minute and one hour', () {
    expect(pickUnit(0), TimeUnit.seconds);
    expect(pickUnit(59), TimeUnit.seconds);
    expect(pickUnit(60), TimeUnit.minutes);
    expect(pickUnit(3599), TimeUnit.minutes);
    expect(pickUnit(3600), TimeUnit.hours);
  });

  test('niceInterval picks a step for the chart maximum', () {
    expect(niceInterval(0), 0.2);
    expect(niceInterval(1), 0.2);
    expect(niceInterval(2), 0.5);
    expect(niceInterval(5), 1.0);
    expect(niceInterval(10), 2.0);
    expect(niceInterval(20), 5.0);
    expect(niceInterval(50), 10.0);
    expect(niceInterval(51), 20.0);
  });

  testWidgets('fmtTotalVerbose joins the non-zero parts', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final l10n = AppLocalizations.of(context)!;
    final total = l10n.total.toLowerCase();

    expect(fmtTotalVerbose(0, context), '0 ${l10n.seconds_plural} $total');
    expect(fmtTotalVerbose(1, context), '1 ${l10n.second} $total');
    expect(fmtTotalVerbose(3600, context), '1 ${l10n.hour} $total');
    expect(
      fmtTotalVerbose(7322, context),
      '2 ${l10n.hours_plural} 2 ${l10n.minutes_plural} '
      '2 ${l10n.seconds_plural} $total',
    );
  });
}
