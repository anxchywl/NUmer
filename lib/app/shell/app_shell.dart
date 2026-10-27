import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/shell/android_tab_bar.dart';
import 'package:numer_app/app/shell/ios_tab_bar.dart';
import 'package:numer_app/app/shell/shell_tabs.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/home/home.dart';
import 'package:numer_app/features/sessions/sessions.dart';

// main navigation shell that hosts the bottom-tab pages
class AppShell extends StatefulWidget {
  final Future<void> Function(ThemeMode)? onThemeChange;
  const AppShell({super.key, this.onThemeChange});

  @override
  State<AppShell> createState() => _ShellState();
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

class _ShellState extends State<AppShell> {
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
    final tabs = buildShellTabs(context, onThemeChange: widget.onThemeChange);
    final isIOS = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;
    final tabPages = tabs
        .map((tab) => _KeepAlivePage(child: tab.builder(context)))
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
              child: IosTabBar(
                currentIndex: _index,
                onTap: _onTabSelected,
                tabs: tabs,
              ),
            ),
        ],
      ),
      bottomNavigationBar: isIOS
          ? null
          : AndroidTabBar(
              currentIndex: _index,
              onTap: _onTabSelected,
              tabs: tabs,
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
        pageBuilder: (dialogContext, _, _) {
          return PopScope(
            canPop: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
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
                              final authController = rootContext
                                  .read<AuthController>();
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
        transitionBuilder: (_, animation, _, child) {
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
