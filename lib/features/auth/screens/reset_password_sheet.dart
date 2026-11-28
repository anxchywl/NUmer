import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

import '../data/auth_code_api.dart';
import '../data/auth_service.dart';
import '../widgets/code_entry_body.dart';
import '../widgets/new_password_step.dart';
import '../widgets/reset_email_step.dart';
import '../widgets/reset_step_parts.dart';

enum _Step { email, code, newPassword }

Future<void> showResetPasswordSheet(
  BuildContext context, {
  String? initialEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(NumerRadius.xl)),
    ),
    builder: (_) => ResetPasswordSheet(initialEmail: initialEmail),
  );
}

class ResetPasswordSheet extends StatefulWidget {
  const ResetPasswordSheet({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<ResetPasswordSheet> {
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _focus = NumerSheetFocusMode();
  _Step _step = _Step.email;
  String _email = '';
  CodeOk? _request;
  // held in memory only and gone with the sheet
  String? _ticket;
  bool _expired = false;

  @override
  void dispose() {
    _emailController.dispose();
    _focus.dispose();
    super.dispose();
  }

  // a field of the next step stays folded away while the previous one counts as typed
  void _showCodeStep(String email, CodeOk request) {
    _focus.release();
    setState(() {
      _email = email;
      _request = request;
      _expired = false;
      _step = _Step.code;
    });
  }

  void _showPasswordStep(CodeOk verified) {
    _focus.release();
    setState(() {
      _ticket = verified.data['resetTicket'] as String;
      _step = _Step.newPassword;
    });
  }

  void _startOver({bool expired = false}) {
    _focus.release();
    setState(() {
      _ticket = null;
      _expired = expired;
      _step = _Step.email;
    });
  }

  void _finish({required bool confirmed}) {
    unawaited(HapticFeedback.lightImpact());
    final l10n = AppLocalizations.of(context)!;
    showAppMessage(
      context,
      confirmed ? l10n.passwordResetSuccess : l10n.passwordResetUnconfirmed,
    );
    // a sheet that is already closing must not pop the screen under it
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) =>
      SheetFocusBuilder(focus: _focus, builder: _sheet);

  Widget _sheet(BuildContext context) {
    // ios can report an inset below zero while the keyboard springs closed
    final keyboard = math.max(0.0, MediaQuery.viewInsetsOf(context).bottom);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        // reversed so the buttons stay in view when the keyboard leaves little room
        child: SingleChildScrollView(reverse: true, child: _buildStep()),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _Step.email => ResetEmailStep(
        focus: _focus,
        controller: _emailController,
        expired: _expired,
        onRequested: _showCodeStep,
      ),
      _Step.code => _buildCodeStep(),
      _Step.newPassword => NewPasswordStep(
        focus: _focus,
        email: _email,
        ticket: _ticket!,
        onSaved: _finish,
        onExpired: () => _startOver(expired: true),
        onStartOver: _startOver,
      ),
    };
  }

  Widget _buildCodeStep() {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthController>();
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NumerFocusFold(hidden: _focus.hidesChrome, child: _codeTitle(l10n)),
        CodeEntryBody(
          focusMode: _focus,
          subtitle: l10n.resetCodeSentGeneric(_email),
          initialResult: _request,
          onSubmit: (code) => auth.verifyPasswordResetCode(_email, code),
          onResend: () => auth.requestPasswordResetCode(_email, locale),
          onVerified: _showPasswordStep,
        ),
        NumerFocusFold(
          hidden: _focus.hidesChrome,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResetStartOverButton(onPressed: _startOver),
              const SizedBox(height: NumerSpace.lg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeTitle(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NumerSpace.lg,
        NumerSpace.lg,
        NumerSpace.lg,
        NumerSpace.sm,
      ),
      child: Text(l10n.codeScreenTitle, style: context.text.sectionTitle),
    );
  }
}
