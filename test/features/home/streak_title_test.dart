import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_fakes.dart';
import 'home_harness.dart';

class _Streak extends FakeState {
  _Streak(this.streakCount, this.hasStudyToday);

  @override
  final int streakCount;
  @override
  final bool hasStudyToday;
}

void main() {
  for (final (today, icon) in [
    (true, Icons.local_fire_department),
    (false, Icons.local_fire_department_outlined),
  ]) {
    testWidgets('the streak shows whether today counts: $today', (
      tester,
    ) async {
      await HomeHarness(state: _Streak(3, today)).pump(tester);
      final scheme = Theme.of(tester.element(find.byIcon(icon))).colorScheme;
      final color = today ? scheme.primary : scheme.onSurfaceVariant;

      expect(tester.widget<Icon>(find.byIcon(icon)).color, color);
      expect(
        tester.widget<Text>(find.text('3 days streak')).style!.color,
        color,
      );
    });
  }
}
