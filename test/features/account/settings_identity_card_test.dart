import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/account/widgets/settings/settings_identity_card.dart';
import 'package:numer_app/features/auth/auth.dart';
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

class _FakeAuth extends ChangeNotifier implements AuthController {
  @override
  User? get currentUser => null;

  @override
  Map<String, dynamic>? get profile => null;

  @override
  bool get isBusy => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSync extends ChangeNotifier implements SyncService {
  _FakeSync(this.status);

  @override
  final SyncStatus status;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Size> _pumpSyncButton(WidgetTester tester, SyncStatus status) async {
  await tester.pumpWidget(
    MultiProvider(
      key: ValueKey(status),
      providers: [
        ChangeNotifierProvider<AppState>(create: (_) => _FakeState()),
        ChangeNotifierProvider<AuthController>(create: (_) => _FakeAuth()),
        ChangeNotifierProvider<SyncService>(create: (_) => _FakeSync(status)),
      ],
      child: MaterialApp(
        theme: NumerTheme.build(
          seed: Colors.indigo,
          brightness: Brightness.light,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsIdentityCard(onSignOut: () async {})),
      ),
    ),
  );
  return tester.getSize(find.byType(FilledButton));
}

void main() {
  testWidgets('the sync button keeps its size and shows a spinner', (
    tester,
  ) async {
    final idle = await _pumpSyncButton(tester, SyncStatus.upToDate);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final busy = await _pumpSyncButton(tester, SyncStatus.syncing);

    expect(busy, idle);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
