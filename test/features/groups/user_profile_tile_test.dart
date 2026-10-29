import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class FakePublicProfileSource implements PublicProfileSource {
  FakePublicProfileSource(this.profile);

  final PublicProfile? profile;

  @override
  Stream<PublicProfile?> watch(String uid) => Stream.value(profile);

  @override
  Future<PublicProfile?> fetch(String uid) async => profile;
}

Future<void> pumpTile(WidgetTester tester, PublicProfile? profile) async {
  await tester.pumpWidget(
    Provider<PublicProfileSource>.value(
      value: FakePublicProfileSource(profile),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(child: UserProfileTile(userId: 'u1')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the profile name', (tester) async {
    await pumpTile(tester, const PublicProfile(uid: 'u1', profileName: 'Aru'));

    expect(find.text('Aru'), findsOneWidget);
  });

  testWidgets('shows the fallback name without a profile', (tester) async {
    await pumpTile(tester, null);

    expect(find.text('Member'), findsOneWidget);
  });

  testWidgets('shows the fallback name for an unnamed profile', (tester) async {
    await pumpTile(tester, const PublicProfile(uid: 'u1', profileName: ''));

    expect(find.text('Member'), findsOneWidget);
  });
}
