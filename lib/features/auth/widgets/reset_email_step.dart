import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../data/auth_code_api.dart';
import '../data/auth_service.dart';
import 'auth_validators.dart';
import 'reset_step_parts.dart';

class ResetEmailStep extends StatefulWidget {
  const ResetEmailStep({
    super.key,
    required this.controller,
    required this.onRequested,
    this.expired = false,
  });

  final TextEditingController controller;
  final void Function(String email, CodeOk result) onRequested;
  final bool expired;

  @override
  State<ResetEmailStep> createState() => _ResetEmailStepState();
}

class _ResetEmailStepState extends State<ResetEmailStep> with ResetSubmit {
  @override
  void initState() {
    super.initState();
    if (widget.expired) message = (l10n) => l10n.resetSessionExpired;
  }

  Future<void> _submit() async {
    if (!canSubmit) return;
    final email = widget.controller.text.trim().toLowerCase();
    if (!emailRegex.hasMatch(email)) return _showInvalidEmail();
    final auth = context.read<AuthController>();
    final locale = Localizations.localeOf(context).languageCode;
    final result = await runCall(
      () => auth.requestPasswordResetCode(email, locale),
    );
    if (result == null) return;
    switch (result) {
      case CodeOk():
        widget.onRequested(email, result);
      case CodeFailure():
        _showFailure(result);
    }
  }

  void _showInvalidEmail() {
    showProblem((l10n) => l10n.invalidEmailFormat, field: widget.controller);
  }

  void _showFailure(CodeFailure failure) {
    switch (failure.reason) {
      case CodeFailureReason.invalidEmail:
        _showInvalidEmail();
      case CodeFailureReason.rateLimited:
        startRetryCountdown(failure);
      case CodeFailureReason.offline:
        showProblem((l10n) => l10n.codeOffline);
      default:
        showProblem((l10n) => l10n.resetRequestFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(NumerSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.resetPasswordTitle, style: context.text.sectionTitle),
          const SizedBox(height: NumerSpace.sm),
          Text(
            l10n.resetPasswordSubtitle,
            style: context.text.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: NumerSpace.lg),
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            inputFormatters: emailInputFormatters,
            decoration: resetFieldDecoration(
              context,
              label: l10n.emailAddress,
              hasError: invalidField == widget.controller,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: NumerSpace.sm),
          ResetStateLine(message?.call(l10n) ?? ''),
          const SizedBox(height: NumerSpace.xl),
          ResetSubmitButton(
            label: l10n.sendResetCode,
            loading: loading,
            onPressed: canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}
