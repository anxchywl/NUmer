import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';

import '../data/auth_code_api.dart';
import '../data/auth_service.dart';
import 'auth_validators.dart';
import 'reset_step_parts.dart';

class NewPasswordStep extends StatefulWidget {
  const NewPasswordStep({
    super.key,
    required this.focus,
    required this.email,
    required this.ticket,
    required this.onSaved,
    required this.onExpired,
    required this.onStartOver,
  });

  final NumerSheetFocusMode focus;
  final String email;
  final String ticket;
  final void Function({required bool confirmed}) onSaved;
  final VoidCallback onExpired;
  final VoidCallback onStartOver;

  @override
  State<NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<NewPasswordStep> with ResetSubmit {
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _replyLost = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!canSubmit || !_validate()) return;
    final auth = context.read<AuthController>();
    final result = await runCall(
      () => auth.confirmPasswordReset(
        widget.email,
        widget.ticket,
        _password.text,
      ),
    );
    if (result == null) return;
    switch (result) {
      case CodeOk():
        _finish(confirmed: true);
      case CodeFailure():
        _showFailure(result);
    }
  }

  void _finish({required bool confirmed}) {
    // asks the password manager to keep the new password
    TextInput.finishAutofillContext();
    widget.onSaved(confirmed: confirmed);
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context)!;
    final problem = newPasswordError(l10n, _password.text);
    if (problem != null) {
      showProblem((_) => problem, field: _password);
      return false;
    }
    if (_password.text != _confirmation.text) {
      showProblem((l10n) => l10n.passwordsDontMatch, field: _confirmation);
      return false;
    }
    return true;
  }

  void _showFailure(CodeFailure failure) {
    switch (failure.reason) {
      // the unanswered call most likely changed the password and used up the ticket
      case CodeFailureReason.invalidOrExpiredTicket when _replyLost:
        _finish(confirmed: false);
      case CodeFailureReason.invalidOrExpiredTicket:
      case CodeFailureReason.malformedInput:
        widget.onExpired();
      case CodeFailureReason.weakPassword:
        showProblem((l10n) => l10n.passwordLength, field: _password);
      case CodeFailureReason.rateLimited:
        startRetryCountdown(failure);
      case CodeFailureReason.offline:
        _replyLost = true;
        showProblem((l10n) => l10n.codeOffline);
      default:
        showProblem((l10n) => l10n.passwordSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chrome = widget.focus.hidesChrome;

    return Padding(
      padding: const EdgeInsets.all(NumerSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NumerFocusFold(hidden: chrome, child: _buildTitle(l10n)),
          _buildPasswordFields(l10n),
          const SizedBox(height: NumerSpace.sm),
          ResetStateLine(message?.call(l10n) ?? ''),
          NumerFocusGap(hidden: chrome, height: NumerSpace.xl),
          SheetDoneActions(
            focus: widget.focus,
            actions: ResetSubmitButton(
              label: l10n.savePasswordButton,
              loading: loading,
              onPressed: canSubmit ? _submit : null,
            ),
          ),
          NumerFocusFold(hidden: chrome, child: _buildStartOver()),
        ],
      ),
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NumerSpace.lg),
      child: Text(l10n.newPasswordTitle, style: context.text.sectionTitle),
    );
  }

  Widget _buildStartOver() {
    return Padding(
      padding: const EdgeInsets.only(top: NumerSpace.sm),
      child: ResetStartOverButton(
        onPressed: loading ? null : widget.onStartOver,
      ),
    );
  }

  // leaving the step any other way must not offer to save an unused password
  Widget _buildPasswordFields(AppLocalizations l10n) {
    return AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAccountField(),
          _keptWhileFolded(
            'password',
            _buildField('password', _password, l10n.newPasswordLabel),
          ),
          NumerFocusGap(
            hidden: widget.focus.hidesChrome,
            height: NumerSpace.md,
          ),
          _keptWhileFolded(
            'confirmation',
            _buildField(
              'confirmation',
              _confirmation,
              l10n.confirmPasswordLabel,
            ),
          ),
        ],
      ),
    );
  }

  // offstage rather than removed, so the password manager still fills both fields
  Widget _keptWhileFolded(String id, Widget field) {
    return NumerFocusFold(
      hidden: false,
      child: Offstage(offstage: widget.focus.hides(id), child: field),
    );
  }

  // tells the password manager which account the new password belongs to
  Widget _buildAccountField() {
    return Offstage(
      child: ExcludeFocus(
        child: TextField(
          controller: _email,
          readOnly: true,
          autofillHints: const [AutofillHints.email],
        ),
      ),
    );
  }

  Widget _buildField(
    String id,
    TextEditingController controller,
    String label,
  ) {
    final isLast = controller == _confirmation;
    return TextField(
      controller: controller,
      focusNode: widget.focus.nodeFor(id),
      obscureText: true,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      inputFormatters: passwordInputFormatters,
      decoration: resetFieldDecoration(
        context,
        label: label,
        hasError: invalidField == controller,
      ),
      onSubmitted: isLast
          ? (_) => _submit()
          : (_) => widget.focus.moveTo('confirmation'),
    );
  }
}
