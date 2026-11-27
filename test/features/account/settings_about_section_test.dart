import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/account/widgets/settings/settings_about_section.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class _FakeLaunch {
  _FakeLaunch({this.opens = true});

  final bool opens;
  final calls = <(Uri, LaunchMode)>[];

  Future<bool> call(
    Uri url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    calls.add((url, mode));
    return opens;
  }
}

Future<void> _pump(
  WidgetTester tester,
  String privacyUrl, {
  _FakeLaunch? launch,
}) async {
  PackageInfo.setMockInitialValues(
    appName: 'Numer',
    packageName: 'numer',
    version: '2.0.0',
    buildNumber: '20',
    buildSignature: '',
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: NumerTheme.build(
        seed: Colors.indigo,
        brightness: Brightness.light,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SettingsAboutSection(
          privacyUrl: privacyUrl,
          launch: (launch ?? _FakeLaunch()).call,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty privacy address hides its row', (tester) async {
    await _pump(tester, '');

    expect(find.text('Privacy policy'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('2.0.0 (20)'), findsOneWidget);
  });

  testWidgets('a privacy address shows its row', (tester) async {
    await _pump(tester, 'https://example.test/privacy');

    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('the rows open the policy outside and the support mail', (
    tester,
  ) async {
    final launch = _FakeLaunch();
    await _pump(tester, 'https://example.test/privacy', launch: launch);

    await tester.tap(find.text('Privacy policy'));
    await tester.tap(find.text('Contact support'));
    await tester.pump();

    expect(launch.calls.first, (
      Uri.parse('https://example.test/privacy'),
      LaunchMode.externalApplication,
    ));
    expect(launch.calls.last.$1.scheme, 'mailto');
    expect(find.text('Could not open the link.'), findsNothing);
  });

  testWidgets('a link that cannot open shows a message', (tester) async {
    await _pump(tester, '', launch: _FakeLaunch(opens: false));

    await tester.tap(find.text('Contact support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not open the link.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
