import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';

import '../models/feed_item.dart';
import 'news_row.dart';

class NewsList extends StatelessWidget {
  const NewsList({
    super.key,
    required this.items,
    required this.limit,
    required this.onOpen,
    this.staleLine,
  });

  final List<FeedItem> items;
  final int limit;
  final void Function(FeedItem) onOpen;
  final String? staleLine;

  @override
  Widget build(BuildContext context) {
    final line = staleLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(
              left: NumerSpace.lg,
              right: NumerSpace.lg,
              bottom: NumerSpace.sm,
            ),
            child: Text(line, style: context.text.meta),
          ),
        for (final (index, item) in items.take(limit).indexed) ...[
          if (index > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: NumerSpace.lg,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          NewsRow(item: item, onTap: () => onOpen(item)),
        ],
      ],
    );
  }
}
