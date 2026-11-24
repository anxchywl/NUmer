import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../widgets/auth_error_text.dart';
import '../widgets/auth_validators.dart';
import 'reset_password_sheet.dart';

final _displayNameInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[A-Za-z0-9 ]'),
);
bool _isValidDisplayName(String value) {
  if (value.length < 2 || value.length > 30) return false;
  // Allow letters, numbers, spaces, hyphens, and apostrophes
  return RegExp(r"^[A-Za-z0-9 '\-]+$").hasMatch(value);
}

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
              colors.primaryContainer.withAlpha(
                ((theme.brightness == Brightness.dark ? 0.2 : 0.9) * 255)
                    .round(),
              ),
              colors.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final tween = Tween<Offset>(
                              begin: const Offset(0, 0.12),
                              end: Offset.zero,
                            ).chain(CurveTween(curve: Curves.easeOutCubic));
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: animation.drive(tween),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _showLogin
                                ? AppLocalizations.of(context)!.loginSubtitle
                                : AppLocalizations.of(
                                    context,
                                  )!.registerSubtitle,
                            key: ValueKey<bool>(_showLogin),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
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
                                color: colors.shadow.withAlpha(
                                  ((theme.brightness == Brightness.dark
                                              ? 0.5
                                              : 0.08) *
                                          255)
                                      .round(),
                                ),
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
                                    backgroundColor: colors
                                        .surfaceContainerHighest
                                        .withAlpha(
                                          ((theme.brightness == Brightness.dark
                                                      ? 0.25
                                                      : 0.5) *
                                                  255)
                                              .round(),
                                        ),
                                  ),
                                  segments: [
                                    ButtonSegment(
                                      value: true,
                                      icon: const Icon(Icons.login_outlined),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          AppLocalizations.of(context)!.signIn,
                                        ),
                                      ),
                                    ),
                                    ButtonSegment(
                                      value: false,
                                      icon: const Icon(
                                        Icons.person_add_alt_1_outlined,
                                      ),
                                      label: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.register,
                                        ),
                                      ),
                                    ),
                                  ],
                                  selected: {_showLogin},
                                  onSelectionChanged: (selection) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    setState(
                                      () => _showLogin = selection.first,
                                    );
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
                                        _horizontalDragDistance +=
                                            details.delta.dx;
                                      },
                                      onHorizontalDragEnd: (details) {
                                        final velocity =
                                            details.velocity.pixelsPerSecond.dx;
                                        final isSwipe =
                                            _horizontalDragDistance.abs() >=
                                                swipeThreshold ||
                                            velocity.abs() > 800;
                                        if (!isSwipe) return;

                                        final shouldShowLogin =
                                            velocity > 0 ||
                                            _horizontalDragDistance > 0;
                                        if (shouldShowLogin == _showLogin) {
                                          return;
                                        }

                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        setState(
                                          () => _showLogin = shouldShowLogin,
                                        );
                                      },
                                      onHorizontalDragCancel: () {
                                        _horizontalDragDistance = 0;
                                      },
                                      child: AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        alignment: Alignment.topCenter,
                                        clipBehavior: Clip.none,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder:
                                              (child, animation) {
                                                final slideTween =
                                                    Tween<Offset>(
                                                      begin: Offset(
                                                        0,
                                                        _showLogin
                                                            ? 0.06
                                                            : -0.06,
                                                      ),
                                                      end: Offset.zero,
                                                    ).chain(
                                                      CurveTween(
                                                        curve:
                                                            Curves.easeOutCubic,
                                                      ),
                                                    );
                                                return FadeTransition(
                                                  opacity: animation,
                                                  child: SlideTransition(
                                                    position: animation.drive(
                                                      slideTween,
                                                    ),
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
                                                  key: const ValueKey(
                                                    'register',
                                                  ),
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
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _showLogin
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 8),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.afterCreatingAccount,
                                        key: const ValueKey(
                                          'afterCreatingAccount',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
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
              child: const SafeArea(child: _ThemeToggle()),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: const SafeArea(child: _LanguageToggle()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({super.key, required this.isBusy});

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
              autofillHints: const [AutofillHints.email],
              inputFormatters: emailInputFormatters,
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
                if (!emailRegex.hasMatch(trimmed.toLowerCase())) {
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
              inputFormatters: passwordInputFormatters,
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
                if (hasInvalidPasswordChars(value)) {
                  return AppLocalizations.of(context)!.passwordInvalidChars;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.isBusy ? null : _openResetPasswordSheet,
                child: Text(AppLocalizations.of(context)!.forgotPassword),
              ),
            ),
            const SizedBox(height: 16),
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
      email: _loginController.text.trim().toLowerCase(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (error == null) {
      showAppMessage(
        context,
        AppLocalizations.of(context)!.signedInSuccessfully,
      );
      return;
    }

    showAuthError(context, error);
  }

  void _openResetPasswordSheet() {
    showResetPasswordSheet(context, initialEmail: _loginController.text.trim());
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({super.key, required this.isBusy});

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
              inputFormatters: [
                LengthLimitingTextInputFormatter(30),
                _displayNameInputFormatter,
              ],
              decoration: _filledFieldDecoration(
                context,
                label: AppLocalizations.of(context)!.displayName,
                icon: Icons.person_outline,
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length < 2) {
                  return AppLocalizations.of(context)!.displayNameLength;
                }
                if (!_isValidDisplayName(trimmed)) {
                  return AppLocalizations.of(context)!.displayNameInvalidChars;
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
              autofillHints: const [AutofillHints.email],
              inputFormatters: emailInputFormatters,
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
                if (!emailRegex.hasMatch(trimmed.toLowerCase())) {
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
              inputFormatters: passwordInputFormatters,
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
              validator: (value) =>
                  newPasswordError(AppLocalizations.of(context)!, value),
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
      email: _loginController.text.trim().toLowerCase(),
      displayName: _displayNameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error != null) showAuthError(context, error);
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
    fillColor: colors.surfaceContainerHighest.withAlpha(
      ((theme.brightness == Brightness.dark ? 0.35 : 0.55) * 255).round(),
    ),
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
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha((0.6 * 255).round()),
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
              color: Theme.of(context).colorScheme.primary.withAlpha(180),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha((0.6 * 255).round()),
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
