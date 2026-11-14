import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../data/auth_code_api.dart';
import '../data/auth_service.dart';
import 'auth_validators.dart';
import 'reset_step_parts.dart';

class NewPasswordStep extends StatefulWidget {
  const NewPasswordStep({
    super.key,
    required this.email,
    required this.ticket,
    required this.onSaved,
    required this.onExpired,
    required this.onStartOver,
  });

  final String email;
  final String ticket;
  final VoidCallback onSaved;
  final VoidCallback onExpired;
  final VoidCallback onStartOver;

  @override
  State<NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<NewPasswordStep> with ResetSubmit {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
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
        widget.onSaved();
      case CodeFailure():
        _showFailure(result);
    }
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
      case CodeFailureReason.invalidOrExpiredTicket:
      case CodeFailureReason.malformedInput:
        widget.onExpired();
      case CodeFailureReason.weakPassword:
        showProblem((l10n) => l10n.passwordLength, field: _password);
      case CodeFailureReason.rateLimited:
        startRetryCountdown(failure);
      case CodeFailureReason.offline:
        showProblem((l10n) => l10n.codeOffline);
      default:
        showProblem((l10n) => l10n.passwordSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(NumerSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.newPasswordTitle, style: context.text.sectionTitle),
          const SizedBox(height: NumerSpace.lg),
          _buildField(_password, l10n.newPasswordLabel, TextInputAction.next),
          const SizedBox(height: NumerSpace.md),
          _buildField(
            _confirmation,
            l10n.confirmPasswordLabel,
            TextInputAction.done,
          ),
          const SizedBox(height: NumerSpace.sm),
          ResetStateLine(message?.call(l10n) ?? ''),
          const SizedBox(height: NumerSpace.xl),
          ResetSubmitButton(
            label: l10n.savePasswordButton,
            loading: loading,
            onPressed: canSubmit ? _submit : null,
          ),
          const SizedBox(height: NumerSpace.sm),
          ResetStartOverButton(onPressed: loading ? null : widget.onStartOver),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    TextInputAction action,
  ) {
    return TextField(
      controller: controller,
      obscureText: true,
      textInputAction: action,
      autofillHints: const [AutofillHints.newPassword],
      inputFormatters: passwordInputFormatters,
      decoration: resetFieldDecoration(
        context,
        label: label,
        hasError: invalidField == controller,
      ),
      onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
    );
  }
}
