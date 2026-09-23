import 'models/academic_schedule.dart';
import 'schedule_document.dart';
import 'schedule_calendar.dart';

class ScheduleWeekData {
  ScheduleWeekData(this.sessions, this.untimed)
    : occupied = {
        for (final s in sessions)
          for (var section = s.startSection; section <= s.endSection; section++)
            (s.weekday, section),
      };
  final List<CourseSession> sessions;
  final List<UntimedCourse> untimed;
  final Set<(int, int)> occupied;
}

/// One immutable schedule gets a lazy index, reused during every zoom frame.
class ScheduleWeekIndex {
  ScheduleWeekIndex(this.schedule) : document = null;
  ScheduleWeekIndex.forDocument(ScheduleDocument doc)
    : document = doc,
      schedule = doc.schedule;
  final ScheduleDocument? document;
  final AcademicSchedule schedule;
  final _weeks = <(int, bool), ScheduleWeekData>{};
  ScheduleWeekData week(int week, bool showOtherWeeks) =>
      _weeks.putIfAbsent((week, showOtherWeeks), () {
        final doc = document;
        if (doc != null && doc.adjustments.isNotEmpty) {
          final sessions = <CourseSession>[];
          for (var day = 1; day <= 7; day++) {
            final date = DateTime(
              doc.firstWeekStart.year,
              doc.firstWeekStart.month,
              doc.firstWeekStart.day + (week - 1) * 7 + day - 1,
            );
            final (sourceWeek, sourceDay) = ScheduleCalendar.source(doc, date);
            final adjusted = doc.adjustments.any((r) => r.date == date);
            if (showOtherWeeks && !adjusted) {
              sessions.addAll(
                schedule.sessions.where(
                  (s) => s.weekday == day && !s.occursInWeek(week),
                ),
              );
            }
            for (final s
                in schedule
                    .sessionsForWeek(sourceWeek)
                    .where((s) => s.weekday == sourceDay)) {
              sessions.add(
                adjusted
                    ? CourseSession.fromJson({
                        ...s.toJson(),
                        'weekday': day,
                      })
                    : s,
              );
            }
          }
          return ScheduleWeekData(
            List.unmodifiable(sessions),
            List.unmodifiable(
              showOtherWeeks
                  ? schedule.untimedCourses
                  : schedule.untimedForWeek(week),
            ),
          );
        }
        final active = schedule.sessionsForWeek(week);
        return ScheduleWeekData(
          List.unmodifiable([
            if (showOtherWeeks)
              ...schedule.sessions.where((s) => !s.occursInWeek(week)),
            ...active,
          ]),
          List.unmodifiable(
            showOtherWeeks
                ? schedule.untimedCourses
                : schedule.untimedForWeek(week),
          ),
        );
      });
}
