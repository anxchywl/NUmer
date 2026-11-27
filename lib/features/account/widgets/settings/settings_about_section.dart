import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:numer_app/core/config/about_links.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

class SettingsAboutSection extends StatefulWidget {
  const SettingsAboutSection({
    super.key,
    this.privacyUrl = privacyPolicyUrl,
    this.launch = launchUrl,
  });

  final String privacyUrl;
  final Future<bool> Function(Uri url, {LaunchMode mode}) launch;

  @override
  State<SettingsAboutSection> createState() => _SettingsAboutSectionState();
}

class _SettingsAboutSectionState extends State<SettingsAboutSection> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  Future<void> _open(Uri uri, {LaunchMode? mode}) async {
    final opened = await widget.launch(
      uri,
      mode: mode ?? LaunchMode.platformDefault,
    );
    if (opened || !mounted) return;
    showAppMessage(
      context,
      AppLocalizations.of(context)!.linkOpenFailed,
      isError: true,
    );
  }

  List<Widget> _rows(AppLocalizations l10n) {
    return [
      if (widget.privacyUrl.isNotEmpty)
        NumerRow(
          title: l10n.privacyPolicy,
          showChevron: true,
          onTap: () => _open(
            Uri.parse(widget.privacyUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      NumerRow(
        title: l10n.contactSupport,
        showChevron: true,
        onTap: () => _open(Uri(scheme: 'mailto', path: supportEmail)),
      ),
      NumerRow(title: l10n.appVersion, value: _version),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: NumerSpace.lg,
      color: scheme.outlineVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.aboutTitle, style: context.text.sectionTitle),
        const SizedBox(height: NumerSpace.sm),
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(NumerRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, row) in _rows(l10n).indexed) ...[
                if (index > 0) divider,
                row,
              ],
            ],
          ),
        ),
        const SizedBox(height: NumerSpace.xl),
      ],
    );
  }
}
