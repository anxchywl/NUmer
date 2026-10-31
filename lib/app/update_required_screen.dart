import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:numer_app/l10n/app_localizations.dart';

const _appStoreUrl = 'https://apps.apple.com/kz/app/numer-app/id6759787785';
const _googlePlayUrl =
    'https://play.google.com/store/apps/details?id=app.anx.numer';

// shown instead of the app when this build is older than the supported minimum
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key, required this.onRecheck});

  // a wrong minimum must stop blocking soon after it is corrected
  final Future<void> Function() onRecheck;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen>
    with WidgetsBindingObserver {
  static const _recheckInterval = Duration(seconds: 60);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.onRecheck();
        _startTimer();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _timer?.cancel();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_recheckInterval, (_) => widget.onRecheck());
  }

  Future<void> _openStore() async {
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    await launchUrl(
      Uri.parse(isApple ? _appStoreUrl : _googlePlayUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                l10n.updateRequiredTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.updateRequiredBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _openStore,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.updateRequiredAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
