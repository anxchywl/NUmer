import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/app_theme.dart';
import 'package:numer_app/app/numer_app.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/firebase_options.dart';
import 'package:numer_app/core/notifications/notifications.dart';
import 'package:numer_app/core/notifications/recording_notification_service.dart';
import 'package:numer_app/core/startup_metrics.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/groups/groups.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/shared/widgets/loading_screen.dart';

// activates firebase app check, skipped on web, emulator and non-release builds
Future<void> _activateAppCheck({required bool useEmulator}) async {
  if (useEmulator) return;
  if (kIsWeb) {
    return;
  }

  final enableAppCheck =
      kReleaseMode ||
      const bool.fromEnvironment('ENABLE_APPCHECK', defaultValue: false);
  if (!enableAppCheck) {
    return;
  }

  // Use debug provider in non-release builds.
  final useDebugProvider = !kReleaseMode;

  if (useDebugProvider) {
    debugPrint('AppCheck: Using Debug Provider');
  } else {
    debugPrint('AppCheck: Using Production Provider');
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: useDebugProvider
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: useDebugProvider
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
  );
}

// app entrypoint, preloads the stored theme then mounts the bootstrap widget
Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupMetrics.markAppStart();

  // Preload stored theme to avoid initial flicker to system theme.
  // This MUST happen before runApp() so the first frame uses the correct theme.
  final (prefs, packageInfo) = await (
    SharedPreferences.getInstance(),
    PackageInfo.fromPlatform(),
  ).wait;
  final storedTheme = prefs.getString(AppState.kThemePrefsKey);
  final initialTheme = _parseThemeMode(storedTheme);
  AppState.setInitialThemeMode(initialTheme);

  const useEmulator = bool.fromEnvironment(
    'USE_FIRESTORE_EMULATOR',
    defaultValue: false,
  );
  final initFuture = _initializeApp(useEmulator: useEmulator);

  runApp(
    NumerBootstrapApp(
      initFuture: initFuture,
      initialTheme: initialTheme,
      prefs: prefs,
      appBuild: int.tryParse(packageInfo.buildNumber) ?? 0,
    ),
  );
}

Future<Map<String, dynamic>?> _fetchAppConfig() async {
  // a firestore cache fallback would count as a fresh read
  final snapshot = await FirebaseFirestore.instance
      .doc('config/app')
      .get(const GetOptions(source: Source.server));
  return snapshot.data();
}

// converts a stored preference string into a thememode
ThemeMode _parseThemeMode(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

// one-time firebase and hive bootstrap that runs before the app is usable
Future<void> _initializeApp({required bool useEmulator}) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  // Ensure local storage is scoped as early as possible for restored sessions.
  final cachedUser = FirebaseAuth.instance.currentUser;
  if (cachedUser != null) {
    try {
      await Storage.configureForUser(cachedUser.uid);
    } catch (_) {}
  }

  await _activateAppCheck(useEmulator: useEmulator);

  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }

  await LocalDatabase.instance.initCore();
  await Notifs.init();
  await RecordingNotifService.init();
}

// root widget, shows a loading shell until init completes then hands off to approot
class NumerBootstrapApp extends StatelessWidget {
  final Future<void> initFuture;
  final ThemeMode initialTheme;
  final SharedPreferences prefs;
  final int appBuild;
  const NumerBootstrapApp({
    super.key,
    required this.initFuture,
    required this.initialTheme,
    required this.prefs,
    required this.appBuild,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AppConfigService>(
                create: (_) => AppConfigService(
                  prefs: prefs,
                  fetch: _fetchAppConfig,
                  build: appBuild,
                ),
              ),
              ChangeNotifierProvider<SyncService>(
                create: (_) => SyncService(appBuild: appBuild),
              ),
              Provider<PublicProfileSource>(
                create: (_) => FirestorePublicProfileSource(),
              ),
              Provider<GroupService>(
                create: (context) => GroupService(
                  profileSource: context.read<PublicProfileSource>(),
                ),
              ),
              Provider<HabitService>(create: (_) => HabitService()),
              ChangeNotifierProxyProvider2<SyncService, HabitService, AppState>(
                create: (_) => AppState(),
                update: (_, syncService, habitService, appState) {
                  final state = appState ?? AppState();
                  state.bindSyncService(syncService);
                  state.bindHabitService(habitService);
                  return state;
                },
              ),
              ChangeNotifierProxyProvider<SyncService, AuthController>(
                create: (_) => AuthController(),
                update: (_, syncService, authController) =>
                    authController!..attachSyncService(syncService),
              ),
            ],
            child: const AppRoot(),
          );
        }

        // Use the preloaded theme for the loading screen to avoid flicker.
        // Use exact native splash colors for seamless transition.
        final systemBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final isDark =
            initialTheme == ThemeMode.dark ||
            (initialTheme == ThemeMode.system &&
                systemBrightness == Brightness.dark);
        // Match native splash colors exactly: #FFFFFF (light) / #121212 (dark)
        final bgColor = isDark
            ? const Color(0xFF121212)
            : const Color(0xFFFFFFFF);
        final fgColor = isDark ? Colors.white70 : Colors.black87;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightFallbackTheme,
          darkTheme: darkFallbackTheme,
          themeMode: initialTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final message =
                  AppLocalizations.of(context)?.loadingProfile ??
                  'Loading your profile';
              return LoadingScreen(
                message: message,
                backgroundColor: bgColor,
                foregroundColor: fgColor,
              );
            },
          ),
        );
      },
    );
  }
}
