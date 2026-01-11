import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';


import 'app_state.dart';
import 'data/local/local_database.dart';
import 'models.dart';
import 'screens/account.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/verification_status.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/alarms.dart';
import 'screens/home.dart';
import 'screens/stats.dart';
import 'screens/timer.dart';
import 'screens/groups/groups_screen.dart';
// import 'screens/connections/connections_screen.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'services/habit_service.dart';
import 'services/sync_service.dart';
// import 'services/connections_service.dart';
import 'screens/habits/habits_screen.dart';
import 'widgets/profile_form.dart';
import 'widgets/app_toast.dart';
import 'widgets/reflection_bottom_sheet.dart';
import 'services/notifications.dart';

Future<void> _activateAppCheck({required bool useEmulator}) async {
  if (useEmulator) return; 
  if (kIsWeb) {
    return;
  }

  final enableAppCheck =
      kReleaseMode || const bool.fromEnvironment('ENABLE_APPCHECK', defaultValue: false);
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


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useEmulator =
      bool.fromEnvironment('USE_FIRESTORE_EMULATOR', defaultValue: false);
  await Firebase.initializeApp();
  
  await _activateAppCheck(useEmulator: useEmulator);

  if (useEmulator) {
    
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }
  await LocalDatabase.instance.initCore();
  await Notifs.init();

  
  

  runApp(
    MultiProvider(
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
        /*
        ChangeNotifierProvider<ConnectionsService>(
          create: (_) => ConnectionsService(),
        ),
        */
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
    ),
  );
}

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
    if (auth.currentUser == null) return;
    final appState = context.read<AppState>();
    unawaited(appState.enforceActiveSessionBounds());
    final syncService = context.read<SyncService>();
    unawaited(syncService.syncNow(full: true));
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (!mounted) return;
    await context.read<AppState>().setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, (ThemeMode, Locale?)>(
      selector: (_, state) => (state.themeMode, state.locale),
      builder: (context, data, _) {
        final themeMode = data.$1;
        final locale = data.$2;

        return MaterialApp(
          title: 'Numer',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
          ),
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

class AuthGate extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const AuthGate({super.key, this.onThemeChange});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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

        if (!auth.isSyncReady || !auth.isProfileReady) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.loadingProfile),
                  ],
                ),
              ),
            ),
          );
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

        if (auth.profile?['profileComplete'] != true) {
          return const ProfileSetupScreen();
        }

        
        return Consumer<AppState>(
          builder: (context, state, _) {
            if (auth.currentUser != null && !state.isLoaded) {
              unawaited(state.load());
            }

            // Only show loader if we haven't loaded anything yet.
            // If we are already loaded, we stay in the shell even during background refreshes/reloads.
            if (!state.isLoaded || !state.isHydrated) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = auth.profile;
            if (profile != null) {
              unawaited(state.applyRemoteProfile(profile));
            }
            return _Shell(onThemeChange: widget.onThemeChange);
          },
        );
      },
    );
  }
}

class _Shell extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const _Shell({this.onThemeChange});

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;
  AppState? _appState;
  AuthController? _authController;
  bool _profileDialogActive = false;
  bool _reflectionSheetActive = false;

  @override
  void initState() {
    super.initState();
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
    _appState?.removeListener(_handleAppStateChanged);
    _authController?.removeListener(_handleAuthChanged);
    super.dispose();
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
      // const ConnectionsScreen(),
      const GroupsScreen(),
      AccountScreen(onThemeChange: widget.onThemeChange),
    ];

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
        bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 64,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
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
          selectedIndex: _index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
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
          ],
          onDestinationSelected: (i) {
            setState(() => _index = i);
          },
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                            initialName: appState.profileName?.isNotEmpty == true
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
                              final authController = rootContext.read<AuthController>();
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
      if (state.pendingReflections.isNotEmpty && state.pendingReflections.first == item) {
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
