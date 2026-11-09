import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

class HabitReportSuccessView extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final String? filePath;

  const HabitReportSuccessView({
    super.key,
    required this.l10n,
    required this.theme,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final filePath = this.filePath;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.fileSavedSuccessfully,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (filePath != null) {
                      await SharePlus.instance.share(
                        ShareParams(files: [XFile(filePath)]),
                      );
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: Text(l10n.shareFile),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
