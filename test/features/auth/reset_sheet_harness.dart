import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'fake_auth_code_api.dart';

const resetEmail = 'a.student@nu.edu.kz';
const resetPassword = 'correct-horse-1';

class SignedOutAuth implements FirebaseAuth {
  int signOuts = 0;

  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FakeAuthCodeApi resetApi() => FakeAuthCodeApi()
  ..sendResult = const CodeOk({'status': 'accepted'})
  ..verifyResult = const CodeOk({'resetTicket': 'ticket'});

Future<void> openResetSheet(
  WidgetTester tester,
  FakeAuthCodeApi api, {
  SignedOutAuth? auth,
  Locale locale = const Locale('en'),
  double textScale = 1,
  String? initialEmail = resetEmail,
}) async {
  final controller = AuthController(
    auth: auth ?? SignedOutAuth(),
    firestore: _FakeFirestore(),
    codeApi: api,
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showResetPasswordSheet(context, initialEmail: initialEmail),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> sendResetCode(WidgetTester tester) =>
    tapVisible(tester, find.byType(FilledButton));

Future<void> enterResetCode(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), '123456');
  await tester.pumpAndSettle();
}

Future<void> reachPasswordStep(WidgetTester tester) async {
  await sendResetCode(tester);
  await enterResetCode(tester);
}

Future<void> saveNewPassword(
  WidgetTester tester, {
  String password = resetPassword,
  String? repeated,
}) async {
  await tester.enterText(find.byType(TextField).first, password);
  await tester.testTextInput.receiveAction(TextInputAction.next);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, repeated ?? password);
  await tester.pumpAndSettle();
  // with the keyboard up the save button waits behind done
  final done = find.widgetWithText(FilledButton, _doneLabel(tester));
  if (done.evaluate().isNotEmpty) await tapVisible(tester, done);
  await tapVisible(tester, find.byType(FilledButton));
}

String _doneLabel(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(TextField).first),
)!.focusDone;

FilledButton submitButton(WidgetTester tester) =>
    tester.widget(find.byType(FilledButton));

List<bool> finishedAutofill(WidgetTester tester) => [
  for (final call in tester.testTextInput.log)
    if (call.method == 'TextInput.finishAutofillContext')
      call.arguments as bool,
];

List<String> visibleTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? '',
];
