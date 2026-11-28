import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/groups/widgets/join_private_group_dialog.dart';

import '../../shared/sheet_focus_harness.dart';

void main() {
  testWidgets('the join dialog keeps the code and join', (tester) async {
    await openSheet(
      tester,
      (context) => showDialog<void>(
        context: context,
        builder: (_) =>
            JoinPrivateGroupDialog(groupName: 'Robotics', onJoin: (_) {}),
      ),
    );

    await typeIn(tester, find.byType(TextField));

    expect(find.textContaining('Robotics'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expectAboveKeyboard(tester, find.byType(FilledButton));

    await hideKeyboard(tester);

    expect(find.textContaining('Robotics'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
