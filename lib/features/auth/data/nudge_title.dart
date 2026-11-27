import 'package:flutter/widgets.dart';

import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/l10n/app_localizations.dart';

// a notification arrives with no widget context, so the locale comes from storage
Future<String> fallbackNudgeTitle() async {
  // the nudge listener can fire before storage is opened for the user
  final ready = LocalDatabase.instance.currentUid != null;
  final saved = ready ? await Storage.getLocale() : null;
  final locale = saved != null
      ? Locale(saved)
      : basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          AppLocalizations.supportedLocales,
        );
  return lookupAppLocalizations(locale).nudgeNotificationTitle;
}
