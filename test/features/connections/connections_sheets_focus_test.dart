import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/connections/connections.dart';
import 'package:provider/provider.dart';

import '../../shared/sheet_focus_harness.dart';
import '../home/home_fakes.dart';

class _Connections extends ChangeNotifier implements ConnectionsService {
  final created = <String>[];

  @override
  List<ContactGroup> get groups => [
    ContactGroup(
      id: 'g',
      name: 'Mentors',
      colorValue: 0xFF4285F4,
      iconCodePoint: Icons.group.codePoint,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<void> createGroup(String uid, ContactGroup group) async =>
      created.add(group.name);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Connections> _open(WidgetTester tester, Widget sheet) async {
  final service = _Connections();
  await openSheet(
    tester,
    (context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => sheet,
    ),
    providers: [
      ChangeNotifierProvider<ConnectionsService>.value(value: service),
      ChangeNotifierProvider<AuthController>(create: (_) => FakeAuth()),
    ],
  );
  return service;
}

void main() {
  testWidgets('add person keeps the typed field and done', (tester) async {
    await _open(tester, const AddPersonSheet());
    final fields = find.byType(TextFormField);

    await typeIn(tester, fields.first);

    expect(fields, findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Mentors'), findsNothing);
    expectAboveKeyboard(tester, fields);
    expectAboveKeyboard(tester, find.widgetWithText(FilledButton, 'Done'));

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(fields, findsOneWidget);
    expect(find.byIcon(Icons.tag), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);

    await tapDone(tester);

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Mentors'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
