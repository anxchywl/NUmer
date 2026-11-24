import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_ui/numer_ui.dart';

Widget _app({
  required bool visible,
  VoidCallback? onPressed,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      floatingActionButton: NumerFab(
        icon: Icons.add,
        label: 'New listing',
        visible: visible,
        onPressed: onPressed ?? () {},
      ),
    ),
  );
}

final _button = find.byType(FloatingActionButton);

void main() {
  testWidgets('hidden slides off the screen and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(visible: true, onPressed: () => taps++));
    final shown = tester.getRect(_button);
    await tester.tap(_button);
    expect(taps, 1);

    await tester.pumpWidget(_app(visible: false, onPressed: () => taps++));
    await tester.pumpAndSettle();
    final hidden = tester.getRect(_button);

    expect(hidden.top - shown.top, 2 * shown.height);
    expect(hidden.top, greaterThanOrEqualTo(600));

    await tester.pumpWidget(_app(visible: true, onPressed: () => taps++));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(visible: false, onPressed: () => taps++));
    await tester.tapAt(shown.center);
    expect(taps, 1);
  });

  testWidgets('takes no time when motion is reduced', (tester) async {
    await tester.pumpWidget(_app(visible: true, reduceMotion: true));
    await tester.pumpWidget(_app(visible: false, reduceMotion: true));
    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));

    expect(slide.duration, Duration.zero);
    await tester.pump();
    expect(tester.getRect(_button).top, greaterThanOrEqualTo(600));
  });
}
