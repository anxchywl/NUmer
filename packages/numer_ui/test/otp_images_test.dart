@Tags(['images'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

const _accent = 0xFF448AFF;

// the default test font draws every glyph as a square
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Bold']) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
    );
    loader.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

enum _State {
  empty(''),
  partial('123'),
  focused('12'),
  error(''),
  disabled('123');

  const _State(this.value);

  final String value;
}

void main() {
  setUpAll(_loadRoboto);

  for (final state in _State.values) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.3]) {
        final name = 'otp_${state.name}_${brightness.name}_$scale';

        testWidgets(name, (tester) async {
          tester.view.physicalSize = const Size(1170, 360);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final controller = TextEditingController(text: state.value);
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(_accent),
                  brightness: brightness,
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NumerSpace.lg),
                    child: NumerOtpField(
                      semanticsLabel: 'Code',
                      controller: controller,
                      autofocus: state == _State.focused,
                      hasError: state == _State.error,
                      enabled: state != _State.disabled,
                      onCompleted: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
