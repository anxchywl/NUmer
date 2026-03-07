import 'habit.dart';

class HabitRule {
  final DateTime endDate; // The date this rule STOPPED applying (exclusive)
  final double targetValue;
  final HabitComparator comparator;

  HabitRule({
    required this.endDate,
    required this.targetValue,
    required this.comparator,
  });

  Map<String, dynamic> toJson() => {
        'endDate': endDate.millisecondsSinceEpoch,
        'targetValue': targetValue,
        'comparator': comparator.index,
      };

  factory HabitRule.fromJson(Map<String, dynamic> json) {
    return HabitRule(
      endDate: DateTime.fromMillisecondsSinceEpoch(json['endDate'] as int),
      targetValue: (json['targetValue'] as num).toDouble(),
      comparator: HabitComparator.values[json['comparator'] as int],
    );
  }
}
