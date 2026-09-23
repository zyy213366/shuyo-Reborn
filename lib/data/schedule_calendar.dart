import 'schedule_document.dart';
import 'models/academic_schedule.dart';

/// Resolve each real date exactly once; rules never recursively follow rules.
class ScheduleCalendar {
  static int teachingWeek(ScheduleDocument doc, DateTime date) {
    final first = doc.firstWeekStart;
    return (DateTime.utc(date.year, date.month, date.day)
                    .difference(
                      DateTime.utc(first.year, first.month, first.day),
                    )
                    .inDays /
                7)
            .floor() +
        1;
  }

  static (int, int) source(ScheduleDocument doc, DateTime date) {
    for (final rule in doc.adjustments) {
      if (rule.date.year == date.year &&
          rule.date.month == date.month &&
          rule.date.day == date.day) {
        return (rule.sourceWeek, rule.sourceWeekday);
      }
    }
    return (teachingWeek(doc, date), date.weekday);
  }

  static List<CourseSession> courses(ScheduleDocument doc, DateTime date) {
    final (week, day) = source(doc, date);
    return doc.schedule
        .sessionsForWeek(week)
        .where((s) => s.weekday == day)
        .toList();
  }
}
