import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/app/shell/app_shell.dart';
import 'package:numer_app/app/update_required_screen.dart';
import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/loading_screen.dart';

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
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system && systemBrightness == Brightness.dark);

    // Match native splash colors exactly
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final fgColor = isDark ? Colors.white70 : Colors.black87;

    final resolvedMessage =
        message ??
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
    return Consumer2<AppConfigService, AuthController>(
      builder: (context, config, auth, _) {
        final child = config.updateRequired
            ? UpdateRequiredScreen(onRecheck: () => config.refresh(force: true))
            : _buildForAuthState(context, auth);
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
          showAppMessage(context, AppLocalizations.of(context)!.accountDeleted);
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
          message:
              AppLocalizations.of(context)?.loggingOut ??
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
              Text(auth.lastPreparationError!, textAlign: TextAlign.center),
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
    final remoteName =
        (profileData['profileName'] as String?)?.trim() ??
        (profileData['displayName'] as String?)?.trim() ??
        '';
    final onboardingDone =
        profileData['onboardingCompleted'] == true ||
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
        return AppShell(onThemeChange: widget.onThemeChange);
      },
    );
  }
}
