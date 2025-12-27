import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import 'email_verification_dialog.dart';
import '../../widgets/app_toast.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _showLogin = true;
  double _horizontalDragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primaryContainer.withAlpha((
                (theme.brightness == Brightness.dark ? 0.2 : 0.9) * 255
              ).round()),
              colors.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 12),
                            Text(
                              'NUmer',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _showLogin 
                            ? AppLocalizations.of(context)!.loginSubtitle 
                            : AppLocalizations.of(context)!.registerSubtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: colors.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withAlpha((
                                  (theme.brightness == Brightness.dark ? 0.5 : 0.08) * 255
                                ).round()),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (auth.isBusy)
                                  const LinearProgressIndicator(minHeight: 2),
                                if (auth.isBusy) const SizedBox(height: 16),
                                SegmentedButton<bool>(
                                  key: ValueKey(_showLogin),
                                  style: SegmentedButton.styleFrom(
                                    backgroundColor:
                                        colors.surfaceContainerHighest.withAlpha((
                                      (theme.brightness == Brightness.dark ? 0.25 : 0.5) * 255
                                    ).round()),
                                  ),
                                  segments: [
                                    ButtonSegment(
                                      value: true,
                                      icon: const Icon(Icons.login_outlined),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(AppLocalizations.of(context)!.signIn),
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: false,
                                      icon: const Icon(Icons.person_add_alt_1_outlined),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(AppLocalizations.of(context)!.register),
                                      ),
                                    ),
                                  ],
                                  selected: {_showLogin},
                                  onSelectionChanged: (selection) {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    setState(() => _showLogin = selection.first);
                                  },
                                ),
                                const SizedBox(height: 28),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final swipeThreshold = math.max(
                                      80.0,
                                      constraints.maxWidth * 0.18,
                                    );
                                    return GestureDetector(
                                      onHorizontalDragStart: (_) {
                                        _horizontalDragDistance = 0;
                                      },
                                      onHorizontalDragUpdate: (details) {
                                        _horizontalDragDistance += details.delta.dx;
                                      },
                                      onHorizontalDragEnd: (details) {
                                        final velocity = details.velocity.pixelsPerSecond.dx;
                                        final isSwipe =
                                            _horizontalDragDistance.abs() >= swipeThreshold ||
                                            velocity.abs() > 800;
                                        if (!isSwipe) return;

                                        final shouldShowLogin = velocity > 0 ||
                                            _horizontalDragDistance > 0;
                                        if (shouldShowLogin == _showLogin) return;

                                        FocusManager.instance.primaryFocus?.unfocus();
                                        setState(() => _showLogin = shouldShowLogin);
                                      },
                                      onHorizontalDragCancel: () {
                                        _horizontalDragDistance = 0;
                                      },
                                      child: AnimatedSize(
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeOutCubic,
                                        alignment: Alignment.topCenter,
                                        clipBehavior: Clip.none,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 220),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder: (child, animation) {
                                            final slideTween = Tween<Offset>(
                                              begin: Offset(0, _showLogin ? 0.06 : -0.06),
                                              end: Offset.zero,
                                            ).chain(CurveTween(curve: Curves.easeOutCubic));
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: animation.drive(slideTween),
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: _showLogin
                                              ? _LoginForm(
                                                  key: const ValueKey('login'),
                                                  isBusy: auth.isBusy,
                                                )
                                              : _RegisterForm(
                                                  key: const ValueKey('register'),
                                                  isBusy: auth.isBusy,
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!_showLogin) Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.afterCreatingAccount,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: const SafeArea(
                child: _ThemeToggle(),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: const SafeArea(
                child: _LanguageToggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({
    super.key,
    required this.isBusy,
  });

  final bool isBusy;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _autoValidate = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: _autoValidate
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _loginController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              textAlignVertical: TextAlignVertical.center,
              autofillHints: const [
                AutofillHints.email,
              ],
              decoration: _filledFieldDecoration(
                context,
                label: AppLocalizations.of(context)!.emailAddress,
                icon: Icons.alternate_email_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!.enterEmail;
                }
                if (!value.contains('@')) {
                  return AppLocalizations.of(context)!.invalidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              textAlignVertical: TextAlignVertical.center,
              decoration: _filledFieldDecoration(
                context,
                label: AppLocalizations.of(context)!.password,
                icon: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.enterPassword;
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: widget.isBusy ? null : _submit,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(AppLocalizations.of(context)!.signIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidate = true);
      return;
    }

    final auth = context.read<AuthController>();
    final error = await auth.signIn(
      email: _loginController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (error == null) {
      showAppMessage(context, AppLocalizations.of(context)!.signedInSuccessfully);
      return;
    }
    
    if (error.contains('verify your email')) {
      showAppMessage(
        context,
        error,
        isError: true,
        actionLabel: AppLocalizations.of(context)!.resendEmail,
        onAction: () async {
          final result = await auth.sendEmailVerification();
          if (!mounted) return;
          
          if (result == null) {
            showAppMessage(context, AppLocalizations.of(context)!.verificationEmailSent);
          } else {
            showAppMessage(context, result, isError: true);
          }
        },
      );
      return;
    }

    showAppMessage(context, error, isError: true);
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({
    super.key,
    required this.isBusy,
  });

  final bool isBusy;

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _autoValidate = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: _autoValidate
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              textAlignVertical: TextAlignVertical.center,
              autofillHints: const [AutofillHints.name],
              decoration: _filledFieldDecoration(
                context,
                label: AppLocalizations.of(context)!.displayName,
                icon: Icons.person_outline,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return AppLocalizations.of(context)!.displayNameLength;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              textAlignVertical: TextAlignVertical.center,
              autofillHints: const [
                AutofillHints.email,
              ],
              decoration: _filledFieldDecoration(
                context,
                label: AppLocalizations.of(context)!.emailAddress,
                icon: Icons.alternate_email_outlined,
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return AppLocalizations.of(context)!.enterEmail;
                }
                if (!trimmed.contains('@')) {
                  return AppLocalizations.of(context)!.invalidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscurePassword,
              textAlignVertical: TextAlignVertical.center,
              decoration: _filledFieldDecoration(
                context,
                label: AppLocalizations.of(context)!.password,
                icon: Icons.lock_outline,
                helperText: AppLocalizations.of(context)!.min8Chars,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return AppLocalizations.of(context)!.passwordLength;
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: widget.isBusy ? null : _submit,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(AppLocalizations.of(context)!.createAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidate = true);
      return;
    }

    final auth = context.read<AuthController>();
    final error = await auth.register(
      email: _loginController.text,
      displayName: _displayNameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    
    if (error != null) {
      showAppMessage(context, error, isError: true);
      return;
    }

    
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const EmailVerificationDialog(),
    );
    
    if (!mounted) return;

    if (verified == true) {
      
      final loginError = await auth.signIn(
        email: _loginController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (loginError != null) {
        showAppMessage(context, loginError, isError: true);
      }
      
      
      setState(() {
        _autoValidate = false;
        _loginController.clear();
        _displayNameController.clear();
        _passwordController.clear();
      });
    } else {
      
      await auth.signOut();
      
      if (!mounted) return;
      
      
      final parent = context.findAncestorStateOfType<_AuthScreenState>();
      parent?.setState(() {
        parent._showLogin = true;
      });

      setState(() {
        _autoValidate = false;
        _loginController.clear();
        _displayNameController.clear();
        _passwordController.clear();
      });
    }
  }
}

InputDecoration _filledFieldDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
  Widget? suffix,
  String? helperText,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: colors.outlineVariant),
  );

  return InputDecoration(
    labelText: label,
    helperText: helperText,
    prefixIcon: icon != null ? Icon(icon) : null,
    suffixIcon: suffix,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
    filled: true,
    fillColor: colors.surfaceContainerHighest.withAlpha((
      (theme.brightness == Brightness.dark ? 0.35 : 0.55) * 255
    ).round()),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: baseBorder.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 2),
    ),
  );
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final languageCode = locale.languageCode;
    final label = languageCode == 'ru'
        ? 'РУ'
        : languageCode == 'kk'
            ? 'ҚАЗ'
            : 'EN';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        FocusManager.instance.primaryFocus?.unfocus();
        const languages = ['en', 'ru', 'kk'];
        final currentIndex = languages.indexOf(languageCode);
        final nextIndex = currentIndex == -1
            ? 0
            : (currentIndex + 1) % languages.length;
        context.read<AppState>().setLocale(Locale(languages[nextIndex]));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha((0.6 * 255).round()),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language, 
              size: 16, 
              color: Theme.of(context).colorScheme.primary.withAlpha(180)
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mode = state.themeMode;

    IconData icon;
    switch (mode) {
      case ThemeMode.system:
        icon = Icons.settings_suggest_outlined;
        break;
      case ThemeMode.light:
        icon = Icons.light_mode_outlined;
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode_outlined;
        break;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        FocusManager.instance.primaryFocus?.unfocus();
        ThemeMode next;
        if (mode == ThemeMode.system) {
          next = ThemeMode.light;
        } else if (mode == ThemeMode.light) {
          next = ThemeMode.dark;
        } else {
          next = ThemeMode.system;
        }
        context.read<AppState>().setThemeMode(next);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha((0.6 * 255).round()),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary.withAlpha(180),
        ),
      ),
    );
  }
}
