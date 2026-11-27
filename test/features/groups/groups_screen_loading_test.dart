import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

class _FakeState extends ChangeNotifier implements AppState {
  @override
  String? get profileName => 'Aru';

  @override
  int? get profileAvatarIndex => null;

  @override
  int? get profileAvatarColorValue => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedInAuth extends ChangeNotifier implements AuthController {
  final User _user = _FakeUser();

  @override
  User? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// neither stream ever answers, so the screen stays in its loading state
class _SilentGroups implements GroupService {
  final memberships = StreamController<List<GroupMembership>>();
  final groups = StreamController<List<Group>>();

  @override
  Stream<List<GroupMembership>> watchUserMemberships(String userId) =>
      memberships.stream;

  @override
  Stream<List<Group>> watchPublicGroups() => groups.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _boxes = find.descendant(
  of: find.byType(NumerSkeleton),
  matching: find.byType(DecoratedBox),
);

void main() {
  testWidgets('loading shows nothing for 299 ms, then a skeleton', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
          ChangeNotifierProvider<AuthController>(
            create: (_) => _SignedInAuth(),
          ),
          Provider<GroupService>(create: (_) => _SilentGroups()),
        ],
        child: MaterialApp(
          theme: NumerTheme.build(
            seed: Colors.indigo,
            brightness: Brightness.light,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GroupsScreen(),
        ),
      ),
    );

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(_boxes, findsNothing);
    await tester.pump(const Duration(milliseconds: 299));
    expect(_boxes, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    // three rows of a title line and a meta line
    expect(_boxes, findsNWidgets(6));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
