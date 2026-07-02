import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:numer_app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/services/auth_service.dart';

class EmailVerificationStatus extends StatefulWidget {
  const EmailVerificationStatus({super.key});

  @override
  State<EmailVerificationStatus> createState() => _EmailVerificationStatusState();
}

class _EmailVerificationStatusState extends State<EmailVerificationStatus> {
  static const int _resendCooldownSeconds = 60;
  bool _checking = false;
  Timer? _timer;
  int _countdown = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdown = _resendCooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _checkVerification() async {
    if (_checking) return;
    setState(() => _checking = true);
    
    try {
      final auth = context.read<AuthController>();
      final error = await auth.checkEmailVerified();
      
      if (!mounted) return;

      if (error == null) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified! Loading your account...')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_countdown > 0) return;
    
    final auth = context.read<AuthController>();
    final error = await auth.sendEmailVerification();
    
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification email sent!')),
    );
    
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              final appState = context.read<AppState>();
              final syncService = context.read<SyncService>();
              final authController = context.read<AuthController>();
              await appState.stopAndSaveAllActiveSessions();
              await appState.waitForPendingReflections();
              await syncService.syncNow();
              await authController.signOut();
            },
            child: Text(
              'Sign out',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify your email',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We sent a verification link to your inbox. Tap the link in the email, then come back here and press "Check verification".',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _checking ? null : _checkVerification,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Check verification'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _countdown > 0 ? null : _resendVerification,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(
                      _countdown > 0
                          ? 'Resend email in ${_countdown}s'
                          : 'Resend verification email',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
