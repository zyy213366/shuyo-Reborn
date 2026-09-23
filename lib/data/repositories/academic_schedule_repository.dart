import '../models/academic_schedule.dart';
import '../schedule_store.dart';

class ScheduleWeekState {
  const ScheduleWeekState({
    required this.currentWeek,
    required this.anchorMonday,
  });

  final int currentWeek;
  final DateTime anchorMonday;

  DateTime get firstWeekStart =>
      anchorMonday.subtract(Duration(days: (currentWeek - 1) * 7));
}

class ScheduleHomeSummary {
  const ScheduleHomeSummary(this.text);

  final String text;
}

class AcademicScheduleCacheState {
  const AcademicScheduleCacheState({
    required this.schedule,
    required this.weekState,
  });

  final AcademicSchedule? schedule;
  final ScheduleWeekState weekState;
}

class AcademicScheduleRepository {
  AcademicScheduleRepository({required this.store, required this.documentId});
  final ScheduleStore store;
  final String documentId;
  String get name => store.byId(documentId).name;
  Future<AcademicSchedule?> loadCachedSchedule() async =>
      store.byId(documentId).schedule;
  Future<AcademicScheduleCacheState> loadCachedState({DateTime? now}) async =>
      AcademicScheduleCacheState(
        schedule: await loadCachedSchedule(),
        weekState: await loadWeekState(now: now),
      );
  Future<void> saveCachedSchedule(AcademicSchedule schedule) =>
      store.mutate(documentId, (d) => d.copyWith(schedule: schedule));
  Future<ScheduleWeekState> loadWeekState({DateTime? now}) async =>
      ScheduleWeekState(
        currentWeek: 1,
        anchorMonday: store.byId(documentId).firstWeekStart,
      );
  Future<void> setFirstWeekStart(DateTime date) =>
      store.mutate(documentId, (d) => d.copyWith(firstWeekStart: date));
  int activeWeekFromState(
    AcademicSchedule schedule,
    ScheduleWeekState state, {
    DateTime? now,
  }) {
    final today = startOfWeek(now ?? DateTime.now());
    // UTC dates avoid 23/25-hour days around daylight-saving transitions.
    final delta =
        DateTime.utc(today.year, today.month, today.day)
            .difference(
              DateTime.utc(
                state.anchorMonday.year,
                state.anchorMonday.month,
                state.anchorMonday.day,
              ),
            )
            .inDays ~/
        7;
    return (state.currentWeek + delta).clamp(0, schedule.vacationWeek);
  }

  static DateTime startOfWeek(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  static String summaryFor(
    AcademicSchedule schedule, {
    required int week,
    required DateTime now,
  }) {
    if (schedule.isVacationWeek(week)) {
      return '假期中';
    }
    final todayCourses =
        schedule.sessions
            .where(
              (course) =>
                  course.weekday == now.weekday && course.occursInWeek(week),
            )
            .toList()
          ..sort((a, b) => a.startSection.compareTo(b.startSection));
    if (todayCourses.isEmpty) {
      return '今日暂无课程';
    }

    for (final course in todayCourses) {
      final end = sectionEndTime(course.endSection, now);
      if (end == null || now.isAfter(end)) {
        continue;
      }
      final start = sectionStartTime(course.startSection, now);
      final prefix = start != null && !now.isBefore(start)
          ? '正在上课'
          : _timeText(start);
      final location = course.location.isEmpty ? '' : ' ${course.location}';
      return '$prefix · ${course.courseName}$location';
    }
    return '今日的课程已全部结束';
  }

  static DateTime? sectionStartTime(int section, DateTime day) {
    final range = sectionTimes[section];
    if (range == null) {
      return null;
    }
    return DateTime(day.year, day.month, day.day, range.$1, range.$2);
  }

  static DateTime? sectionEndTime(int section, DateTime day) {
    final range = sectionTimes[section];
    if (range == null) {
      return null;
    }
    return DateTime(day.year, day.month, day.day, range.$3, range.$4);
  }

  static String sectionTimeText(int section) {
    final range = sectionTimes[section];
    if (range == null) {
      return '';
    }
    return '${_pad(range.$1)}:${_pad(range.$2)}\n${_pad(range.$3)}:${_pad(range.$4)}';
  }

  static String _timeText(DateTime? value) {
    if (value == null) {
      return '下一节';
    }
    return '${_pad(value.hour)}:${_pad(value.minute)}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static const sectionTimes = <int, (int, int, int, int)>{
    1: (8, 0, 8, 45),
    2: (8, 55, 9, 40),
    3: (10, 0, 10, 45),
    4: (10, 55, 11, 40),
    5: (13, 0, 13, 45),
    6: (13, 55, 14, 40),
    7: (15, 0, 15, 45),
    8: (15, 55, 16, 40),
    9: (18, 0, 18, 45),
    10: (18, 55, 19, 40),
    11: (20, 0, 20, 45),
    12: (20, 55, 21, 40),
  };
}
