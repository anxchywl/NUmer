import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/firebase_options.dart';
import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/features/account/screens/account.dart';
import 'package:numer_app/features/auth/screens/auth_screen.dart';
import 'package:numer_app/features/auth/screens/verification_status.dart';
import 'package:numer_app/features/auth/screens/profile_setup_screen.dart';
import 'package:numer_app/features/sessions/screens/alarms.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/features/stats/screens/stats.dart';
import 'package:numer_app/features/sessions/screens/timer.dart';
import 'package:numer_app/features/groups/screens/groups_screen.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/groups/data/group_service.dart';
import 'package:numer_app/features/habits/data/habit_service.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/habits/screens/habits_screen.dart';
import 'package:numer_app/features/account/widgets/profile_form.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/features/sessions/widgets/reflection_bottom_sheet.dart';
import 'package:numer_app/core/notifications/notifications.dart';
import 'package:numer_app/core/notifications/recording_notification_service.dart';
import 'package:numer_app/core/startup_metrics.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/shared/widgets/loading_screen.dart';

// activates firebase app check, skipped on web, emulator and non-release builds
Future<void> _activateAppCheck({required bool useEmulator}) async {
  if (useEmulator) return;
  if (kIsWeb) {
    return;
  }

  final enableAppCheck = kReleaseMode ||
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

// model for a single item in the ios-style bottom navigation bar
class _IosNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _IosNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

// app entrypoint, preloads the stored theme then mounts the bootstrap widget
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupMetrics.markAppStart();

  // Preload stored theme to avoid initial flicker to system theme.
  // This MUST happen before runApp() so the first frame uses the correct theme.
  final prefs = await SharedPreferences.getInstance();
  final storedTheme = prefs.getString(AppState.kThemePrefsKey);
  final initialTheme = _parseThemeMode(storedTheme);
  AppState.setInitialThemeMode(initialTheme);

  const useEmulator =
      bool.fromEnvironment('USE_FIRESTORE_EMULATOR', defaultValue: false);
  final initFuture = _initializeApp(useEmulator: useEmulator);

  runApp(NumerBootstrapApp(
    initFuture: initFuture,
    initialTheme: initialTheme,
  ));
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
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
  const NumerBootstrapApp({
    super.key,
    required this.initFuture,
    required this.initialTheme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<SyncService>(
                create: (_) => SyncService(),
              ),
              Provider<GroupService>(
                create: (_) => GroupService(),
              ),
              Provider<HabitService>(
                create: (_) => HabitService(),
              ),
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
        final isDark = initialTheme == ThemeMode.dark ||
            (initialTheme == ThemeMode.system &&
                systemBrightness == Brightness.dark);
        // Match native splash colors exactly: #FFFFFF (light) / #121212 (dark)
        final bgColor =
            isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
        final fgColor = isDark ? Colors.white70 : Colors.black87;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
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
              final message = AppLocalizations.of(context)?.loadingProfile ??
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

final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.dark,
  ),
);

// top-level app widget, feeds theme, locale and accent colour into materialapp and routes
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupMetrics.markFirstFrame();
      _syncActiveSessions();
      context.read<AppState>().loadThemeMode();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncActiveSessions();
    }
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

  Future<void> setTheme(ThemeMode mode) async {
    if (!mounted) return;
    await context.read<AppState>().setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, (ThemeMode, Locale?, Color)>(
      selector: (_, state) => (
        state.effectiveThemeMode,
        state.locale,
        state.accentColor,
      ),
      builder: (context, data, _) {
        final themeMode = data.$1;
        final locale = data.$2;
        final accentColor = data.$3;

        final lightTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: accentColor),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accentColor;
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return accentColor.withValues(alpha: 0.5);
              }
              return null;
            }),
          ),
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return accentColor;
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return accentColor.withValues(alpha: 0.5);
              }
              return null;
            }),
          ),
        );

        return MaterialApp(
          title: 'Numer',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthGate(onThemeChange: setTheme),
          routes: {
            '/shell': (_) => _Shell(onThemeChange: setTheme),
            '/timer': (_) => const TimerScreen(),
            '/alarms': (_) => const AlarmsScreen(),
          },
        );
      },
    );
  }
}

// picks which screen to show based on auth, email verification and profile state
class AuthGate extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const AuthGate({super.key, this.onThemeChange});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget _buildLoader(BuildContext context, {String? message}) {
    // Use exact native splash colors to avoid flicker: #FFFFFF (light) / #121212 (dark)
    final appState = context.read<AppState>();
    final mode = appState.effectiveThemeMode;
    final systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && systemBrightness == Brightness.dark);

    // Match native splash colors exactly
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final fgColor = isDark ? Colors.white70 : Colors.black87;

    final resolvedMessage = message ??
        AppLocalizations.of(context)?.loadingProfile ??
        'Loading your profile';
    return LoadingScreen(
      message: resolvedMessage,
      backgroundColor: bgColor,
      foregroundColor: fgColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final child = _buildForAuthState(context, auth);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: child,
        );
      },
    );
  }

  Widget _buildForAuthState(BuildContext context, AuthController auth) {
    if (!auth.isInitialized) {
      return _buildLoader(context);
    }

    if (auth.wasForcedLoggedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppMessage(
          context,
          'You were signed out because your account became active on another device.',
          isError: true,
        );
        auth.clearForcedLogoutFlag();
      });
    }

    if (auth.currentUser == null) {
      if (auth.consumeAccountDeletedMessage()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showAppMessage(
            context,
            AppLocalizations.of(context)!.accountDeleted,
          );
        });
      }
      final appState = context.read<AppState>();
      if (appState.isLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<AppState>().unload();
        });
      }
      return const AuthScreen();
    }

    if (auth.requiresEmailVerification) {
      final appState = context.read<AppState>();
      if (appState.isLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<AppState>().unload();
        });
      }
      return const EmailVerificationStatus();
    }

    if (auth.isBootstrapping || !auth.isSyncReady || !auth.isProfileReady) {
      if (auth.isSigningOut) {
        return _buildLoader(
          context,
          message: AppLocalizations.of(context)?.loggingOut ??
              'Logging out of account...',
        );
      }
      return _buildLoader(context);
    }

    if (auth.lastPreparationError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.failedToPrepareData),
              const SizedBox(height: 12),
              Text(
                auth.lastPreparationError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  auth.reloadUser();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final profileData = auth.profile;
    if (profileData == null) {
      return _buildLoader(context);
    }
    final remoteName = (profileData['profileName'] as String?)?.trim() ??
        (profileData['displayName'] as String?)?.trim() ??
        '';
    final onboardingDone = profileData['onboardingCompleted'] == true ||
        profileData['profileComplete'] == true ||
        remoteName.isNotEmpty;
    if (onboardingDone && remoteName.isEmpty) {
      return _buildLoader(context);
    }

    if (!onboardingDone) {
      return const ProfileSetupScreen();
    }

    return Consumer<AppState>(
      builder: (context, state, _) {
        if (auth.currentUser != null && !state.isLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || state.isLoaded) return;
            unawaited(state.load());
          });
        }

        if (!state.isLoaded || !state.isHydrated) {
          return _buildLoader(context);
        }

        final profile = auth.profile;
        if (profile != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(state.applyRemoteProfile(profile));
          });
        }
        return _Shell(onThemeChange: widget.onThemeChange);
      },
    );
  }
}

// main navigation shell that hosts the bottom-tab pages
class _Shell extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const _Shell({this.onThemeChange});

  @override
  State<_Shell> createState() => _ShellState();
}

// keeps a tab page's state alive when the user switches between tabs
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ShellState extends State<_Shell> {
  int _index = 0;
  late final PageController _pageController;
  AppState? _appState;
  AuthController? _authController;
  bool _profileDialogActive = false;
  bool _reflectionSheetActive = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final appState = context.read<AppState>();
      _appState = appState;
      appState.addListener(_handleAppStateChanged);
      final auth = context.read<AuthController>();
      _authController = auth;
      auth.addListener(_handleAuthChanged);
      await _maybeShowProfileDialog(appState);
      if (mounted) {
        await _maybeReopenActivePomodoro();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _appState?.removeListener(_handleAppStateChanged);
    _authController?.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _index) return;
    final previousIndex = _index;
    setState(() => _index = index);
    final distance = (index - previousIndex).abs();
    if (_pageController.hasClients) {
      if (distance <= 1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        // For non-adjacent tabs, switch directly to avoid scrolling through all pages.
        _pageController.jumpToPage(index);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(index);
    });
  }

  void _handleAppStateChanged() {
    if (!mounted) return;
    final state = _appState ?? context.read<AppState>();
    unawaited(_maybeShowProfileDialog(state));
    unawaited(_maybeShowReflectionSheet(state));
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final state = _appState ?? context.read<AppState>();
    unawaited(_maybeShowProfileDialog(state));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const HabitsScreen(),
      const StatsScreen(),
      // Connections feature is planned but intentionally hidden for now. The code in
      // lib/features/connections/ is complete and kept in sync; to enable it, uncomment
      // the line below AND add a matching entry to _buildDestinations()/_buildIosNavItems().
      // const ConnectionsScreen(),
      const GroupsScreen(),
      AccountScreen(onThemeChange: widget.onThemeChange),
    ];
    final destinations = _buildDestinations(context);
    final iosItems = _buildIosNavItems(context);
    final isIOS = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;
    final tabPages = pages
        .map((page) => _KeepAlivePage(child: page))
        .toList(growable: false);

    return Scaffold(
      extendBody: isIOS,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: !isIOS,
            child: PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (index) {
                if (_index != index) {
                  setState(() => _index = index);
                }
              },
              children: tabPages,
            ),
          ),
          if (isIOS)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildIosLiquidGlassNavigationBar(context, iosItems),
            ),
        ],
      ),
      bottomNavigationBar:
          isIOS ? null : _buildDefaultNavigationBar(context, destinations),
    );
  }

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: AppLocalizations.of(context)!.home,
      ),
      NavigationDestination(
        icon: const Icon(Icons.check_circle_outline),
        selectedIcon: const Icon(Icons.check_circle),
        label: AppLocalizations.of(context)!.habitsNavLabel,
      ),
      NavigationDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: AppLocalizations.of(context)!.statistics,
      ),
      NavigationDestination(
        icon: const Icon(Icons.group_outlined),
        selectedIcon: const Icon(Icons.group),
        label: AppLocalizations.of(context)!.groups,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.settings),
        label: AppLocalizations.of(context)!.account,
      ),
    ];
  }

  List<_IosNavItem> _buildIosNavItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return <_IosNavItem>[
      _IosNavItem(
        label: l10n.home,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _IosNavItem(
        label: l10n.habitsNavLabel,
        icon: Icons.check_circle_outline,
        selectedIcon: Icons.check_circle,
      ),
      _IosNavItem(
        label: l10n.statistics,
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
      ),
      _IosNavItem(
        label: l10n.groups,
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
      ),
      _IosNavItem(
        label: l10n.account,
        icon: Icons.person_outline,
        selectedIcon: Icons.settings,
      ),
    ];
  }

  Widget _buildDefaultNavigationBar(
    BuildContext context,
    List<NavigationDestination> destinations,
  ) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 64,
        backgroundColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.4),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final theme = Theme.of(context);
          if (states.contains(WidgetState.selected)) {
            return theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final theme = Theme.of(context);
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: theme.colorScheme.primary,
              size: 26,
            );
          }
          return IconThemeData(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            size: 24,
          );
        }),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: destinations,
        onDestinationSelected: _onTabSelected,
      ),
    );
  }

  Widget _buildIosLiquidGlassNavigationBar(
    BuildContext context,
    List<_IosNavItem> items,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const barHeight = 66.0;
    const horizontalMargin = 14.0;
    const bottomSpacing = 2.0;
    const innerPadding = 8.0;
    const highlightInset = 4.0;
    final overlayHeight = barHeight + bottomSpacing + bottomInset;
    return SizedBox(
      height: overlayHeight,
      child: Stack(
        children: [
          Positioned(
            left: horizontalMargin,
            right: horizontalMargin,
            bottom: barBottomOffset,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth =
                    (constraints.maxWidth - innerPadding * 2) / items.length;
                final activeWidth = slotWidth + 12;
                final activeLeft = innerPadding +
                    _index * slotWidth +
                    ((slotWidth - activeWidth) / 2);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: SizedBox(
                    height: barHeight,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          left: activeLeft,
                          top: highlightInset,
                          width: activeWidth,
                          height: barHeight - (highlightInset * 2),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.09 : 0.24,
                                    ),
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.05 : 0.16,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.transparent),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: innerPadding,
                          ),
                          child: Row(
                            children: List.generate(items.length, (i) {
                              final selected = _index == i;
                              final item = items[i];
                              return Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => _onTabSelected(i),
                                  child: SizedBox(
                                    height: barHeight,
                                    child: AnimatedScale(
                                      scale: selected ? 1.08 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 180),
                                      curve: Curves.easeOutCubic,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            selected
                                                ? item.selectedIcon
                                                : item.icon,
                                            size: selected ? 24 : 20,
                                            color: selected
                                                ? scheme.primary
                                                : scheme.onSurface
                                                    .withValues(alpha: 0.72),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              fontSize: selected ? 12.0 : 11.0,
                                              color: selected
                                                  ? scheme.primary
                                                  : scheme.onSurface
                                                      .withValues(alpha: 0.74),
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeShowProfileDialog(AppState appState) async {
    if (_profileDialogActive || !mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.isProfileReady) return;
    final profileData = auth.profile;
    if (profileData == null) return;
    final remoteComplete = profileData['profileComplete'] == true;
    final remoteName = (profileData['profileName'] as String?)?.trim() ?? '';
    final remoteMajor = (profileData['major'] as String?)?.trim() ?? '';
    final remoteContact =
        (profileData['profileContact'] as String?)?.trim() ?? '';
    final remoteHasRequired = remoteName.isNotEmpty;
    final remoteIncomplete = !remoteComplete && !remoteHasRequired;
    final localName = appState.profileName?.trim() ?? '';
    final localHasRequired = localName.isNotEmpty;
    if (appState.profileComplete || localHasRequired) return;
    if (!remoteIncomplete) return;
    _profileDialogActive = true;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rootContext = context;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Profile setup',
        barrierColor: colorScheme.scrim.withAlpha((0.7 * 255).round()),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (dialogContext, _, __) {
          return PopScope(
            canPop: false,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Material(
                  color: colorScheme.surfaceContainerHigh,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome!\nLet\'s create your profile.',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ProfileForm(
                            initialName:
                                appState.profileName?.isNotEmpty == true
                                    ? appState.profileName!
                                    : remoteName,
                            initialMajor: appState.major?.isNotEmpty == true
                                ? appState.major
                                : remoteMajor,
                            initialContact:
                                appState.profileContact?.isNotEmpty == true
                                    ? appState.profileContact
                                    : remoteContact,
                            initialGoal: appState.profileGoal,
                            initialAvatarIndex: appState.profileAvatarIndex,
                            primaryButtonLabel: 'Save profile',
                            autofocusName: true,
                            onSubmit: (data) async {
                              final state = rootContext.read<AppState>();
                              final authController =
                                  rootContext.read<AuthController>();
                              final uid = authController.currentUser?.uid;

                              await state.saveProfile(
                                name: data.name,
                                goal: data.goal,
                                majorText: data.major,
                                contact: data.contact,
                                avatarIndex: data.avatarIndex,
                                avatarColorValue: data.avatarColorValue,
                                uid: uid,
                              );

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      _profileDialogActive = false;
    }

    if (!mounted) return;
    final latestState = _appState ?? context.read<AppState>();
    if (!latestState.shouldShowProfilePrompt) {
      unawaited(_maybeReopenActivePomodoro());
    }
  }

  Future<void> _maybeReopenActivePomodoro() async {
    if (!mounted) return;
    final appState = context.read<AppState>();

    if (appState.activeSessionKind != 'pomodoro') return;
    final courseId = appState.activeSessionCourseId;
    if (courseId == null) return;
    final course = appState.courses.firstWhere(
      (Course c) => c.id == courseId,
      orElse: () => Course(
        id: courseId,
        name: 'Unknown',
        day: '',
        start: '',
        end: '',
        colorValue: 0xFF94A3B8,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showCourseTimeSheet(context, course);
    });
  }

  Future<void> _maybeShowReflectionSheet(AppState state) async {
    if (_reflectionSheetActive || !mounted) return;
    if (state.pendingReflections.isEmpty) return;

    // Gate by Quick Notes setting: if disabled, we clear and skip
    if (!state.quickNotesEnabled) {
      while (state.pendingReflections.isNotEmpty) {
        state.popPendingReflection();
      }
      return;
    }

    // We only show if there is no other modal (profile dialog)
    if (_profileDialogActive) return;

    if (state.courseSheetOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_maybeShowReflectionSheet(state));
      });
      return;
    }

    _reflectionSheetActive = true;
    final item = state.pendingReflections.first;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ReflectionBottomSheet(
          sessionId: item.sessionId,
          durationSeconds: item.duration,
        ),
      );
    } finally {
      // Remove the processed item and reset flag.
      // We check if it's still the same item to be safe, but popPendingReflection blindly removes first.
      // This is consistent with how we consumed it.
      if (state.pendingReflections.isNotEmpty &&
          state.pendingReflections.first == item) {
        state.popPendingReflection();
      } else {
        // It might have been cleared elsewhere? Unlikely if single thread.
        // But let's just pop.
        state.popPendingReflection();
      }

      _reflectionSheetActive = false;
    }
  }
}
