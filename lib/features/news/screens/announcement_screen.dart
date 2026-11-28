import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../models/feed_item.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen(this.item, {super.key});

  final FeedItem item;

  Future<void> _openLink(BuildContext context, String link) async {
    final uri = Uri.tryParse(link);
    final opened =
        uri != null &&
        uri.scheme == 'https' &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    showAppMessage(context, AppLocalizations.of(context)!.linkOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;
    final body = item.body;
    final link = item.link;
    return Scaffold(
      appBar: AppBar(title: Text(item.localized(item.title, locale))),
      body: ListView(
        padding: const EdgeInsets.all(NumerSpace.lg),
        children: [
          Text(
            DateFormat.yMMMd(locale).format(item.publishedAt.toLocal()),
            style: context.text.meta,
          ),
          const SizedBox(height: NumerSpace.md),
          if (body != null)
            Text(item.localized(body, locale), style: context.text.body),
          if (link != null) ...[
            const SizedBox(height: NumerSpace.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => _openLink(context, link),
                child: Text(l10n.newsOpenLink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
