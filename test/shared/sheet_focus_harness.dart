import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

const _pixelRatio = 3.0;
const _width = 390.0;
const _height = 844.0;
const _keyboardHeight = 336.0;

Future<void> openSheet(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open, {
  List<SingleChildWidget> providers = const [],
  double width = _width,
}) async {
  tester.view.devicePixelRatio = _pixelRatio;
  tester.view.physicalSize = Size(width, _height) * _pixelRatio;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    theme: NumerTheme.build(seed: Colors.indigo, brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> showKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(
    bottom: _keyboardHeight * _pixelRatio,
  );
  await tester.pumpAndSettle();
}

Future<void> hideKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, Finder field) async {
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pump();
  await showKeyboard(tester);
}

Future<void> tapDone(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Done'));
  await tester.pumpAndSettle();
  await hideKeyboard(tester);
}

Finder fieldLabeled(String label) => find.widgetWithText(TextField, label);

void expectAboveKeyboard(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  expect(
    tester.getBottomLeft(finder).dy,
    lessThanOrEqualTo(_height - _keyboardHeight),
  );
}
