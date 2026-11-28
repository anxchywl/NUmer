import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../models/feed_item.dart';
import '../news_meta.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen(this.item, {super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // events are shown as written, in the one language they come in
      appBar: AppBar(title: Text(item.title['en']!)),
      body: ListView(
        padding: const EdgeInsets.all(NumerSpace.lg),
        children: [
          Text(newsMeta(l10n, l10n.localeName, item), style: context.text.body),
        ],
      ),
    );
  }
}
