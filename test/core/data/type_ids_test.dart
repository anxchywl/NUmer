import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/entities.dart';
import 'package:numer_app/core/data/grade_entities.dart';

void main() {
  test('every hive adapter keeps its persisted type id', () {
    expect(LocalUserDocAdapter().typeId, 10);
    expect(LocalCourseAdapter().typeId, 11);
    expect(LocalSessionAdapter().typeId, 12);
    expect(LocalGoalAdapter().typeId, 13);
    expect(SyncStateEntryAdapter().typeId, 14);
    expect(LocalConflictAdapter().typeId, 15);
    expect(LocalHabitAdapter().typeId, 16);
    expect(LocalHabitHistoryAdapter().typeId, 17);
    expect(LocalCourseGradeAdapter().typeId, 18);
    expect(LocalAssignmentAdapter().typeId, 19);
    expect(LocalSemesterAdapter().typeId, 20);
  });
}
