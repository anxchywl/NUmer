import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../data/feed_repository.dart';
import '../models/feed_item.dart';
import '../widgets/news_section.dart';

const _shownItems = 30;

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.openInModule});

  final bool Function(BuildContext, FeedItem) openInModule;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.newsTitle)),
      body: RefreshIndicator(
        onRefresh: () => context.read<FeedRepository>().refresh(force: true),
        child: ListView(
          key: const PageStorageKey('news'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            NewsStates(
              limit: _shownItems,
              onOpen: (item) => openNewsItem(context, item, openInModule),
            ),
          ],
        ),
      ),
    );
  }
}
