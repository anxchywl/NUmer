import 'package:flutter/widgets.dart';

import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/l10n/app_localizations.dart';

// a notification arrives with no widget context, so the locale comes from storage
Future<String> fallbackNudgeTitle() async {
  final saved = await Storage.getLocale();
  final locale = saved != null
      ? Locale(saved)
      : basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          AppLocalizations.supportedLocales,
        );
  return lookupAppLocalizations(locale).nudgeNotificationTitle;
}
