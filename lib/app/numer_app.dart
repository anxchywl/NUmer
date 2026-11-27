import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/app_theme.dart';
import 'package:numer_app/app/auth_gate.dart';
import 'package:numer_app/app/routes.dart';
import 'package:numer_app/app/shell/app_shell.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/observability/crash_reporter.dart';
import 'package:numer_app/core/startup_metrics.dart';
import 'package:numer_app/features/auth/auth.dart';

// top-level app widget, feeds theme, locale and accent colour into materialapp and routes
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late final AuthController _auth;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthController>()..addListener(_handleAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupMetrics.markFirstFrame();
      _syncActiveSessions();
      context.read<AppState>().loadThemeMode();
      _handleAuthChanged();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_handleAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncActiveSessions();
      _refreshConfig();
    }
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final uid = _auth.currentUser?.uid;
    if (uid == _uid) return;
    if (_uid == null) _refreshConfig();
    _uid = uid;
    context.read<CrashReporter>().setUser(uid);
  }

  void _refreshConfig() {
    // deliberately not awaited, startup must not wait for the network
    context.read<AppConfigService>().refresh();
  }

  void _syncActiveSessions() {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (auth.currentUser == null || !auth.isSyncReady || auth.isBootstrapping) {
      return;
    }
    final appState = context.read<AppState>();
    unawaited(appState.enforceActiveSessionBounds());
    final syncService = context.read<SyncService>();
    unawaited(syncService.syncNow(full: false));
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, (ThemeMode, Locale?, Color)>(
      selector: (_, state) =>
          (state.effectiveThemeMode, state.locale, state.accentColor),
      builder: (context, data, _) {
        final themeMode = data.$1;
        final locale = data.$2;
        final accentColor = data.$3;

        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'Numer',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          theme: buildAppTheme(accentColor, Brightness.light),
          darkTheme: buildAppTheme(accentColor, Brightness.dark),
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
          routes: {routeShell: (_) => const AppShell()},
        );
      },
    );
  }
}
