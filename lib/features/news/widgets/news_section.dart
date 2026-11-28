import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../data/feed_repository.dart';
import '../models/feed_item.dart';
import '../news_meta.dart';
import '../screens/announcement_screen.dart';
import '../screens/event_detail_screen.dart';
import 'news_list.dart';

void openNewsItem(
  BuildContext context,
  FeedItem item,
  bool Function(BuildContext, FeedItem) openInModule,
) {
  final Widget screen;
  switch (item.kind) {
    case FeedKind.announcement:
      screen = AnnouncementScreen(item);
    case FeedKind.event:
      if (openInModule(context, item)) return;
      screen = EventDetailScreen(item);
  }
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
}

class NewsStates extends StatelessWidget {
  const NewsStates({super.key, required this.limit, required this.onOpen});

  final int limit;
  final void Function(FeedItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedRepository>();
    final l10n = AppLocalizations.of(context)!;
    final fetchedAt = feed.fetchedAt;
    if (feed.items.isNotEmpty) {
      return NewsList(
        items: feed.items,
        limit: limit,
        onOpen: onOpen,
        staleLine: feed.lastRefreshFailed && fetchedAt != null
            ? newsUpdatedLine(l10n, DateTime.now().difference(fetchedAt))
            : null,
      );
    }
    if (fetchedAt != null) {
      return NumerEmptyState(
        message: l10n.newsEmpty,
        actionLabel: l10n.newsRefresh,
        onAction: () => feed.refresh(force: true),
      );
    }
    // never an empty state before the first refresh has answered
    if (!feed.lastRefreshFailed) return const NumerSkeleton(rows: 3);
    return NumerErrorState(
      message: l10n.newsLoadError,
      retryLabel: l10n.retry,
      onRetry: () => feed.refresh(force: true),
    );
  }
}
