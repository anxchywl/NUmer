import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../data/auth_code_api.dart';
import '../data/auth_service.dart';
import '../widgets/code_entry_body.dart';

class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({super.key});

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  CodeResult? _firstSend;

  @override
  void initState() {
    super.initState();
    // the locale cannot be read from the context before the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendFirstCode());
  }

  // a new code would replace the one the user may be about to type
  Future<void> _sendFirstCode() async {
    if (!mounted) return;
    final pending = await context
        .read<AuthController>()
        .pendingVerificationCode();
    if (!mounted) return;
    final result = pending ?? await _send();
    if (!mounted) return;
    setState(() => _firstSend = result);
    if (pending != null) await _advanceIfVerified();
  }

  // without a send nothing else reports a link used while the app was closed
  Future<void> _advanceIfVerified() async {
    final failure = await context.read<AuthController>().refreshVerifiedEmail();
    if (failure == null && mounted) _announceVerified();
  }

  // the address may already be verified, for example through an emailed link
  Future<CodeResult> _send() async {
    final auth = context.read<AuthController>();
    final locale = Localizations.localeOf(context).languageCode;
    final result = await auth.sendVerificationCode(locale);
    if (result is! CodeOk || result.data['status'] != 'already-verified') {
      return result;
    }
    final failure = await auth.refreshVerifiedEmail();
    if (failure != null) return failure;
    if (mounted) _announceVerified();
    return result;
  }

  void _announceVerified() {
    showAppMessage(context, AppLocalizations.of(context)!.emailVerifiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.codeScreenTitle, style: context.text.screenTitle),
        actions: [
          TextButton(onPressed: auth.signOut, child: Text(l10n.signOut)),
        ],
      ),
      body: SafeArea(
        child: CodeEntryBody(
          subtitle: l10n.codeScreenSubtitle(auth.currentUser?.email ?? ''),
          initialResult: _firstSend,
          onSubmit: auth.verifyEmailCode,
          onResend: _send,
          onVerified: (_) => _announceVerified(),
        ),
      ),
    );
  }
}
