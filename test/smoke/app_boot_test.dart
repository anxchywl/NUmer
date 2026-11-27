import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/main.dart';

void main() {
  testWidgets('bootstrap app renders its loading shell while initializing', (
    WidgetTester tester,
  ) async {
    // this exercises real app code without needing Firebase/Hive.
    await tester.pumpWidget(
      NumerBootstrapApp(
        initFuture: Completer<void>().future,
        initialTheme: ThemeMode.system,
      ),
    );

    expect(find.byType(NumerBootstrapApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
