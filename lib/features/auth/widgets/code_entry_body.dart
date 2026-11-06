import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../data/auth_code_api.dart';

const _codeLength = 6;
const _maxCooldownSeconds = 60;
const _defaultRetrySeconds = 60;

enum _Call { verify, resend }

class CodeEntryBody extends StatefulWidget {
  const CodeEntryBody({
    super.key,
    required this.subtitle,
    required this.onSubmit,
    required this.onResend,
    required this.onVerified,
    this.initialResult,
    this.initialMessage,
  });

  final String subtitle;
  final Future<CodeResult> Function(String code) onSubmit;
  final Future<CodeResult> Function() onResend;
  final ValueChanged<CodeOk> onVerified;
  final CodeResult? initialResult;
  final String? initialMessage;

  @override
  State<CodeEntryBody> createState() => _CodeEntryBodyState();
}

class _CodeEntryBodyState extends State<CodeEntryBody> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  _Call? _call;
  CodeFailure? _failure;
  String _code = '';
  bool _hasResult = false;
  bool _hasError = false;
  bool _locked = false;
  int _cooldownSeconds = 0;
  int _retrySeconds = 0;

  bool get _busy => _call != null;

  bool get _rateLimited => _retrySeconds > 0;

  bool get _canVerify =>
      !_busy && !_locked && !_rateLimited && _code.length == _codeLength;

  bool get _canResend {
    final awaitingFirstSend = widget.initialResult == null;
    return !awaitingFirstSend &&
        !_busy &&
        !_rateLimited &&
        _cooldownSeconds == 0;
  }

  @override
  void initState() {
    super.initState();
    final result = widget.initialResult;
    if (result != null) _applySend(result);
  }

  @override
  void didUpdateWidget(CodeEntryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final result = widget.initialResult;
    if (result == null || result == oldWidget.initialResult) return;
    _applySend(result);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String code) {
    setState(() {
      _code = code;
      if (code.isNotEmpty) _hasError = false;
    });
  }

  Future<void> _submit() async {
    if (!_canVerify) return;
    final result = await _run(_Call.verify, () => widget.onSubmit(_code));
    if (result == null) return;
    switch (result) {
      case CodeOk():
        unawaited(HapticFeedback.lightImpact());
        widget.onVerified(result);
      case CodeFailure():
        setState(() => _applyFailure(result));
        _refocus();
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    final result = await _run(_Call.resend, widget.onResend);
    if (result == null || !mounted) return;
    setState(() => _applySend(result));
    if (_sentNewCode(result)) {
      _controller.clear();
      showAppMessage(context, AppLocalizations.of(context)!.newCodeSent);
    }
    _refocus();
  }

  // null when the widget was removed while the call ran
  Future<CodeResult?> _run(
    _Call call,
    Future<CodeResult> Function() action,
  ) async {
    setState(() {
      _call = call;
      _hasError = false;
    });
    try {
      final result = await action();
      return mounted ? result : null;
    } finally {
      if (mounted) setState(() => _call = null);
    }
  }

  // the field is disabled until the next frame, so it cannot take focus yet
  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_locked) _focusNode.requestFocus();
    });
  }

  bool _sentNewCode(CodeResult result) {
    if (result is! CodeOk) return false;
    final status = result.data['status'];
    return status != 'cooldown' && status != 'already-verified';
  }

  void _applySend(CodeResult result) {
    switch (result) {
      case CodeOk():
        _hasResult = true;
        _failure = null;
        if (_sentNewCode(result)) _locked = false;
        _startCooldown(result.data['resendAvailableAt']);
      case CodeFailure():
        _applyFailure(result);
    }
  }

  void _applyFailure(CodeFailure reported) {
    final spent =
        reported.reason == CodeFailureReason.invalidCode &&
        reported.attemptsLeft == 0;
    final failure = spent
        ? const CodeFailure(CodeFailureReason.tooManyAttempts)
        : reported;
    _hasResult = true;
    _failure = failure;
    switch (failure.reason) {
      case CodeFailureReason.invalidCode:
      case CodeFailureReason.malformedCode:
      case CodeFailureReason.malformedInput:
      case CodeFailureReason.invalidOrExpiredCode:
        _hasError = true;
      case CodeFailureReason.tooManyAttempts:
        _locked = true;
      case CodeFailureReason.rateLimited:
        _retrySeconds = failure.retryAfterSeconds ?? _defaultRetrySeconds;
        _startTimer();
      default:
        break;
    }
  }

  void _startCooldown(Object? resendAvailableAt) {
    if (resendAvailableAt is! num) return;
    final millis =
        resendAvailableAt.toInt() - DateTime.now().millisecondsSinceEpoch;
    final seconds = (millis / Duration.millisecondsPerSecond).ceil();
    _cooldownSeconds = seconds.clamp(0, _maxCooldownSeconds);
    _startTimer();
  }

  void _startTimer() {
    if (_cooldownSeconds == 0 && _retrySeconds == 0) return;
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    setState(() {
      if (_cooldownSeconds > 0) _cooldownSeconds--;
      if (_retrySeconds > 0) {
        _retrySeconds--;
        final limitShown = _failure?.reason == CodeFailureReason.rateLimited;
        if (_retrySeconds == 0 && limitShown) _failure = null;
      }
    });
    if (_cooldownSeconds == 0 && _retrySeconds == 0) _timer?.cancel();
  }

  String _stateText(AppLocalizations l10n) {
    if (!_hasResult) return widget.initialMessage ?? '';
    final failure = _failure;
    if (failure == null) return '';
    return switch (failure.reason) {
      CodeFailureReason.invalidCode when failure.attemptsLeft != null =>
        l10n.codeInvalid(failure.attemptsLeft!),
      CodeFailureReason.invalidCode ||
      CodeFailureReason.malformedCode ||
      CodeFailureReason.malformedInput ||
      CodeFailureReason.invalidOrExpiredCode => l10n.codeInvalidOrExpired,
      CodeFailureReason.codeExpired ||
      CodeFailureReason.noActiveCode => l10n.codeExpired,
      CodeFailureReason.tooManyAttempts => l10n.codeTooManyAttempts,
      CodeFailureReason.rateLimited => l10n.codeRateLimited(_retrySeconds),
      CodeFailureReason.deliveryFailed ||
      CodeFailureReason.noEmail => l10n.codeDeliveryFailed,
      CodeFailureReason.offline => l10n.codeOffline,
      CodeFailureReason.invalidEmail ||
      CodeFailureReason.weakPassword ||
      CodeFailureReason.invalidOrExpiredTicket ||
      CodeFailureReason.unknown => l10n.codeCheckFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(NumerSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitle,
            style: context.text.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: NumerSpace.xl),
          NumerOtpField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            enabled: !_busy && !_locked,
            hasError: _hasError,
            semanticsLabel: l10n.codeFieldLabel,
            onChanged: _handleChanged,
            onCompleted: (_) => _submit(),
          ),
          const SizedBox(height: NumerSpace.sm),
          _buildStateLine(l10n, colors),
          const SizedBox(height: NumerSpace.xl),
          _buildVerifyButton(l10n),
          const SizedBox(height: NumerSpace.sm),
          _buildResendButton(l10n),
        ],
      ),
    );
  }

  Widget _buildStateLine(AppLocalizations l10n, ColorScheme colors) {
    final isFailure = _hasResult && _failure != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: NumerSpace.lg),
      child: Text(
        _stateText(l10n),
        style: context.text.meta.copyWith(
          color: isFailure ? colors.error : colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildVerifyButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(NumerSpace.xxxl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NumerRadius.md),
          ),
        ),
        onPressed: _canVerify ? _submit : null,
        child: NumerButtonChild(
          label: l10n.verifyCodeButton,
          loading: _call == _Call.verify,
        ),
      ),
    );
  }

  Widget _buildResendButton(AppLocalizations l10n) {
    return Center(
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(NumerSpace.xxxl, NumerSpace.xxxl),
        ),
        onPressed: _canResend ? _resend : null,
        child: NumerButtonChild(
          label: _cooldownSeconds > 0
              ? l10n.resendCodeIn(_cooldownSeconds)
              : l10n.resendCode,
          loading: _call == _Call.resend,
        ),
      ),
    );
  }
}
