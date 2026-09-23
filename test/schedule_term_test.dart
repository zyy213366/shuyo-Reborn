import 'package:flutter_test/flutter_test.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'schedule_store_test.dart' show fixture;

void main() {
  test(
    'a course in week one must not shrink the whole semester to one week',
    () {
      final raw = fixture().sessions.first.toJson()..['weeks'] = [1];
      final schedule = fixture().copyWith(
        sessions: [CourseSession.fromJson(raw)],
        untimedCourses: [],
      );
      expect(schedule.maxWeek, greaterThanOrEqualTo(16));
    },
  );
}
