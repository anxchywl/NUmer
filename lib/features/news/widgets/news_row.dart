import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import '../models/feed_item.dart';
import '../news_meta.dart';

const double _minHeight = 72;

class NewsRow extends StatelessWidget {
  const NewsRow({super.key, required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NumerSpace.lg,
            vertical: NumerSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.localized(item.title, l10n.localeName),
                style: context.text.rowTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: NumerSpace.xs),
              Row(
                children: [
                  if (item.pinned) ...[
                    NumerStatusLabel(
                      l10n.newsPinned,
                      tone: NumerStatusTone.highlighted,
                    ),
                    const SizedBox(width: NumerSpace.sm),
                  ],
                  Expanded(
                    child: Text(
                      newsMeta(l10n, l10n.localeName, item),
                      style: context.text.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
