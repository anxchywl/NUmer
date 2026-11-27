import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

class _FakeGroups implements GroupService {
  final watched = <StatisticsPeriod>[];

  @override
  Stream<GroupStatistics> watchGroupStatistics(
    String groupId,
    StatisticsPeriod period,
  ) {
    watched.add(period);
    return Stream.value(
      GroupStatistics(
        groupId: groupId,
        members: const [],
        periodStart: DateTime(2026),
        periodEnd: DateTime(2026),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('choosing a period segment loads that period', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    final groups = _FakeGroups();
    await tester.pumpWidget(
      Provider<GroupService>.value(
        value: groups,
        child: MaterialApp(
          theme: NumerTheme.build(
            seed: Colors.indigo,
            brightness: Brightness.light,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: GroupLeaderboard(groupId: 'g1', currentUserId: 'u1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<StatisticsPeriod>), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(groups.watched, [
      StatisticsPeriod.today,
      StatisticsPeriod.last7Days,
    ]);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
  });
}
