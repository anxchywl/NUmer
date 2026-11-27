import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/core/upcoming/upcoming_item.dart';
import 'package:numer_app/core/upcoming/upcoming_store.dart';
import 'package:numer_app/l10n/app_localizations.dart';

const _shownItems = 3;

// the hook of a build where no module opens items, so rows do not look tappable
bool openNoUpcomingItem(BuildContext _, UpcomingItem _) => false;

class UpcomingSection extends StatelessWidget {
  const UpcomingSection({
    super.key,
    required this.uid,
    required this.openInModule,
  });

  final String uid;
  final bool Function(BuildContext, UpcomingItem) openInModule;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<UpcomingStore>().upcoming(uid);
    if (items.isEmpty) return const SizedBox.shrink();
    return NumerSection(
      title: AppLocalizations.of(context)!.upcomingTitle,
      child: NumerBlock(
        children: [
          for (final item in items.take(_shownItems)) _row(context, item),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, UpcomingItem item) {
    final canOpen = openInModule != openNoUpcomingItem;
    return NumerRow(
      leading: Icon(
        _icon(item.kind),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: item.title,
      subtitle: upcomingWhen(
        AppLocalizations.of(context)!,
        item.startsAt,
        DateTime.now(),
      ),
      showChevron: canOpen,
      onTap: canOpen ? () => openInModule(context, item) : null,
    );
  }

  IconData _icon(UpcomingKind kind) => switch (kind) {
    UpcomingKind.pianoBooking => Icons.piano_outlined,
    UpcomingKind.eventReminder => Icons.event_outlined,
  };
}

String upcomingWhen(AppLocalizations l10n, DateTime startsAt, DateTime now) {
  final start = startsAt.toLocal();
  final current = now.toLocal();
  final startDay = DateUtils.dateOnly(start);
  final tomorrow = DateTime(current.year, current.month, current.day + 1);
  final day = switch (startDay) {
    _ when startDay == DateUtils.dateOnly(current) => l10n.today,
    _ when startDay == tomorrow => l10n.tomorrow,
    _ => DateFormat.MMMd(l10n.localeName).format(start),
  };
  return '$day, ${DateFormat.Hm(l10n.localeName).format(start)}';
}
