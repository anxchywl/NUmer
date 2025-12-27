import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({super.key});

  @override
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  Timer? _timer;
  bool _checking = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerification());
  }

  Future<void> _checkVerification() async {
    if (_checking || _verified) return;
    
    setState(() => _checking = true);
    try {
      final auth = context.read<AuthController>();
      final error = await auth.checkEmailVerified();
      
      if (error == null) {
        
        setState(() => _verified = true);
        _timer?.cancel();
        
        if (!mounted) return;
        
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthController>();
    
    final error = await auth.sendEmailVerification();
    
    if (!mounted) return;
    
    if (error == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Verification email sent!')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false, 
      child: Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
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
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_verified)
                  Icon(
                    Icons.verified_outlined,
                    size: 48,
                    color: colors.primary,
                  )
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: colors.primary,
                      ),
                      if (_checking)
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                              color: colors.primary.withAlpha((0.5 * 255).round()),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text(
                  _verified ? 'Email verified!' : 'Check your email',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _verified
                      ? 'Thank you! You can now start using the app.'
                      : 'A verification link has been sent to your email. Please verify your account by clicking the link.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_verified) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 40),
                    ),
                    onPressed: _checking ? null : _checkVerification,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check verification'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _checking ? null : _resendEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Resend email'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
