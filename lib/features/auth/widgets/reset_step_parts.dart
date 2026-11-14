import 'dart:async';

import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../data/auth_code_api.dart';

const double _borderWidth = 2;
const int _defaultRetrySeconds = 60;

typedef StateMessage = String Function(AppLocalizations l10n);

// the state line, loading flag and retry countdown shared by the reset forms
mixin ResetSubmit<T extends StatefulWidget> on State<T> {
  Timer? _countdown;
  int _retrySeconds = 0;
  bool loading = false;
  StateMessage? message;
  TextEditingController? invalidField;

  bool get canSubmit => !loading && _retrySeconds == 0;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void showProblem(StateMessage problem, {TextEditingController? field}) {
    setState(() {
      message = problem;
      invalidField = field;
    });
  }

  // null when the widget was removed while the call ran
  Future<CodeResult?> runCall(Future<CodeResult> Function() call) async {
    setState(() {
      loading = true;
      message = null;
      invalidField = null;
    });
    try {
      final result = await call();
      return mounted ? result : null;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void startRetryCountdown(CodeFailure failure) {
    _retrySeconds = failure.retryAfterSeconds ?? _defaultRetrySeconds;
    showProblem((l10n) => l10n.codeRateLimited(_retrySeconds));
    _scheduleTick();
  }

  void _scheduleTick() {
    _countdown?.cancel();
    if (_retrySeconds <= 0) return;
    _countdown = Timer(const Duration(seconds: 1), () {
      setState(() {
        _retrySeconds--;
        if (_retrySeconds == 0) message = null;
      });
      _scheduleTick();
    });
  }
}

InputDecoration resetFieldDecoration(
  BuildContext context, {
  required String label,
  bool hasError = false,
}) {
  final colors = Theme.of(context).colorScheme;
  OutlineInputBorder border([Color? color]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(NumerRadius.md),
    borderSide: color == null
        ? BorderSide.none
        : BorderSide(color: color, width: _borderWidth),
  );
  final resting = border(hasError ? colors.error : null);

  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: colors.surfaceContainerHighest,
    border: resting,
    enabledBorder: resting,
    focusedBorder: border(hasError ? colors.error : colors.primary),
  );
}

class ResetStateLine extends StatelessWidget {
  const ResetStateLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: NumerSpace.lg),
      child: Text(
        text,
        style: context.text.meta.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class ResetSubmitButton extends StatelessWidget {
  const ResetSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(NumerSpace.xxxl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NumerRadius.md),
        ),
      ),
      onPressed: onPressed,
      child: NumerButtonChild(label: label, loading: loading),
    );
  }
}

class ResetStartOverButton extends StatelessWidget {
  const ResetStartOverButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(NumerSpace.xxxl, NumerSpace.xxxl),
        ),
        onPressed: onPressed,
        child: Text(AppLocalizations.of(context)!.resetStartOver),
      ),
    );
  }
}
