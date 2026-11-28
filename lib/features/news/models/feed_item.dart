import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum FeedKind { announcement, event }

@immutable
class FeedItem {
  const FeedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.publishedAt,
    this.body,
    this.startsAt,
    this.place,
    this.pinned = false,
    this.link,
  });

  factory FeedItem.fromFirestore(Map<String, dynamic> data) =>
      FeedItem._parse(data, _timestampTime);

  factory FeedItem.fromJson(Map<String, dynamic> json) =>
      FeedItem._parse(json, _epochTime);

  // throws FormatException, so a list parser can skip the one bad item
  factory FeedItem._parse(
    Map<String, dynamic> data,
    DateTime? Function(Object?) readTime,
  ) {
    final id = data['id'];
    final kind = FeedKind.values.asNameMap()[data['kind']];
    final title = _texts(data['title']);
    final publishedAt = readTime(data['publishedAt']);
    if (id is! String || kind == null || title == null || publishedAt == null) {
      throw const FormatException('invalid feed item');
    }
    final place = data['place'];
    final link = data['link'];
    return FeedItem(
      id: id,
      kind: kind,
      title: title,
      publishedAt: publishedAt,
      body: _texts(data['body']),
      startsAt: readTime(data['startsAt']),
      place: place is String ? place : null,
      pinned: data['pinned'] == true,
      link: link is String ? link : null,
    );
  }

  final String id;
  final FeedKind kind;
  final Map<String, String> title;
  final Map<String, String>? body;
  final DateTime? startsAt;
  final String? place;
  final DateTime publishedAt;
  final bool pinned;
  final String? link;

  String localized(Map<String, String> text, String languageCode) {
    final translated = text[languageCode];
    if (translated != null && translated.isNotEmpty) return translated;
    return text['en'] ?? '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': ?body,
    'startsAt': ?startsAt?.millisecondsSinceEpoch,
    'place': ?place,
    'publishedAt': publishedAt.millisecondsSinceEpoch,
    'pinned': pinned,
    'link': ?link,
  };
}

DateTime? _timestampTime(Object? value) =>
    value is Timestamp ? value.toDate() : null;

DateTime? _epochTime(Object? value) =>
    value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;

// null unless the english text, the fallback of every language, is there
Map<String, String>? _texts(Object? value) {
  if (value is! Map || value['en'] is! String) return null;
  return {
    for (final MapEntry(:key, :value) in value.entries)
      if (key is String && value is String) key: value,
  };
}
