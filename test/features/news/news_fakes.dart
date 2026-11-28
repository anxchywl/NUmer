import 'package:flutter/foundation.dart';
import 'package:numer_app/features/news/news.dart';

FeedItem announcement(
  String id, {
  String? title,
  bool pinned = false,
  Map<String, String>? body,
  String? link,
}) => FeedItem(
  id: id,
  kind: FeedKind.announcement,
  title: {'en': title ?? id},
  body: body,
  link: link,
  pinned: pinned,
  publishedAt: DateTime(2026, 11, 27, 9),
);

FeedItem event(String id, {String? title, String? place = 'Block C3'}) =>
    FeedItem(
      id: id,
      kind: FeedKind.event,
      title: {'en': title ?? id},
      startsAt: DateTime(2026, 12, 12, 18),
      place: place,
      publishedAt: DateTime(2026, 11, 26),
    );

class FakeFeed extends ChangeNotifier implements FeedRepository {
  FakeFeed({
    this.items = const [],
    this.fetchedAt,
    this.lastRefreshFailed = false,
  });

  @override
  List<FeedItem> items;
  @override
  DateTime? fetchedAt;
  @override
  bool lastRefreshFailed;
  @override
  bool isLoading = false;

  final forced = <bool>[];

  void answer(List<FeedItem> next, {bool failed = false}) {
    if (!failed) {
      items = next;
      fetchedAt = DateTime.now();
    }
    lastRefreshFailed = failed;
    notifyListeners();
  }

  @override
  Future<void> refresh({bool force = false}) async {
    forced.add(force);
  }
}
