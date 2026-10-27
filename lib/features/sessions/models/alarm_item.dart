class AlarmItem {
  final int id;
  final String title;
  final DateTime time;
  final bool repeatsDaily;

  AlarmItem({
    required this.id,
    required this.title,
    required this.time,
    required this.repeatsDaily,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'time': time.toIso8601String(),
    'repeatsDaily': repeatsDaily,
  };

  static AlarmItem fromJson(Map<String, dynamic> j) => AlarmItem(
    id: j['id'] as int,
    title: j['title'] as String,
    time: DateTime.parse(j['time'] as String).toLocal(),
    repeatsDaily: j['repeatsDaily'] == true,
  );
}
