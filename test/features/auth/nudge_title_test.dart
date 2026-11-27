import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/auth/data/nudge_title.dart';
import 'package:numer_app/l10n/app_localizations.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  String titleIn(String code) =>
      lookupAppLocalizations(Locale(code)).nudgeNotificationTitle;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('nudge_title');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => directory.path,
    );
    binding.platformDispatcher.localesTestValue = const [Locale('ru')];
  });

  tearDownAll(() async {
    binding.platformDispatcher.clearLocalesTestValue();
    await Storage.closeForSignOut();
    await directory.delete(recursive: true);
  });

  test('uses the device locale before storage is configured', () async {
    expect(await fallbackNudgeTitle(), titleIn('ru'));
  });

  test('uses the saved locale once storage is configured', () async {
    await Storage.configureForUser('nudge');
    await Storage.setLocale('kk');

    expect(await fallbackNudgeTitle(), titleIn('kk'));
  });
}
