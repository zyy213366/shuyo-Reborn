import 'models/academic_schedule.dart';
import 'schedule_document.dart';
import 'schedule_calendar.dart';

enum ComparisonMode { allBusy, allFree, commonCourses }

class MinuteRange {
  const MinuteRange(this.start, this.end);
  final int start;
  final int end;
  String get label => '${clock(start)}–${clock(end)}';
  static String clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
}

class ComparisonDay {
  const ComparisonDay(this.date, this.ranges);
  final DateTime date;
  final List<MinuteRange> ranges;
}

class CourseOccurrence {
  const CourseOccurrence(this.document, this.session, this.date, this.ranges);
  final ScheduleDocument document;
  final CourseSession session;
  final DateTime date;
  final List<MinuteRange> ranges;
}

class CommonCourse {
  const CommonCourse(this.name, this.code, this.occurrences);
  final String name;
  final String code;
  final List<CourseOccurrence> occurrences;
}

class ScheduleComparison {
  static int teachingWeek(ScheduleDocument doc, DateTime date) {
    return ScheduleCalendar.teachingWeek(doc, date);
  }

  static List<MinuteRange> sessionRanges(
    ScheduleDocument doc,
    CourseSession course,
  ) => merge([
    for (final section in course.sections.toSet())
      if (section >= 1 && section <= doc.sectionTimes.length)
        MinuteRange(
          doc.sectionTimes[section - 1][0] * 60 +
              doc.sectionTimes[section - 1][1],
          doc.sectionTimes[section - 1][2] * 60 +
              doc.sectionTimes[section - 1][3],
        ),
  ]);

  static List<MinuteRange> merge(List<MinuteRange> input) {
    final sorted = input.where((r) => r.end > r.start).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final result = <MinuteRange>[];
    for (final range in sorted) {
      if (result.isEmpty || range.start > result.last.end) {
        result.add(range);
      } else if (range.end > result.last.end) {
        result[result.length - 1] = MinuteRange(result.last.start, range.end);
      }
    }
    return result;
  }

  static List<CourseOccurrence> occurrences(
    ScheduleDocument doc,
    DateTime weekStart,
  ) {
    final monday = mondayOf(weekStart);
    return [
      for (var day = 0; day < 7; day++)
        for (final session in ScheduleCalendar.courses(
          doc,
          DateTime(monday.year, monday.month, monday.day + day),
        ))
          CourseOccurrence(
            doc,
            session,
            DateTime(monday.year, monday.month, monday.day + day),
            sessionRanges(doc, session),
          ),
    ];
  }

  static List<ComparisonDay> times(
    List<ScheduleDocument> documents,
    DateTime weekStart,
    ComparisonMode mode, {
    int start = 8 * 60,
    int end = 22 * 60,
  }) {
    if (documents.length < 2) return [];
    if (start < 0 ||
        end > 24 * 60 ||
        start >= end ||
        mode == ComparisonMode.commonCourses) {
      throw ArgumentError('Invalid comparison window or mode');
    }
    final monday = mondayOf(weekStart);
    final data = [for (final doc in documents) occurrences(doc, monday)];
    return [
      for (var day = 1; day <= 7; day++)
        ComparisonDay(
          DateTime(monday.year, monday.month, monday.day + day - 1),
          _dayTimes(data, day, mode, start, end),
        ),
    ];
  }

  static List<MinuteRange> _dayTimes(
    List<List<CourseOccurrence>> all,
    int weekday,
    ComparisonMode mode,
    int start,
    int end,
  ) {
    final busy = [
      for (final entries in all)
        merge([
          for (final entry in entries)
            if (entry.date.weekday == weekday)
              for (final r in entry.ranges)
                if (r.end > start && r.start < end)
                  MinuteRange(
                    r.start.clamp(start, end),
                    r.end.clamp(start, end),
                  ),
        ]),
    ];
    final edges = <int>{
      start,
      end,
      for (final list in busy)
        for (final r in list) ...[r.start, r.end],
    }.toList()..sort();
    return merge([
      for (var i = 0; i < edges.length - 1; i++)
        if (busy.every(
          (list) =>
              list.any((r) => r.start <= edges[i] && r.end >= edges[i + 1]) ==
              (mode == ComparisonMode.allBusy),
        ))
          MinuteRange(edges[i], edges[i + 1]),
    ]);
  }

  /// Match codes when available. A missing code may match a unique name, but
  /// two distinct nonempty codes are never collapsed just because names match.
  static List<CommonCourse> common(
    List<ScheduleDocument> documents,
    DateTime weekStart, {
    bool allWeeks = true,
  }) {
    if (documents.length < 2) return [];
    final entries = <CourseOccurrence>[];
    for (final doc in documents) {
      final week = teachingWeek(doc, weekStart);
      if (!allWeeks) entries.addAll(occurrences(doc, weekStart));
      for (final session in doc.schedule.sessions) {
        if (allWeeks) {
          final monday = mondayOf(weekStart);
          entries.add(
            CourseOccurrence(
              doc,
              session,
              DateTime(
                monday.year,
                monday.month,
                monday.day + session.weekday - 1,
              ),
              sessionRanges(doc, session),
            ),
          );
        }
      }
      for (final course in doc.schedule.untimedCourses) {
        if (allWeeks ||
            (week >= 1 &&
                week <= doc.schedule.maxWeek &&
                course.occursInWeek(week))) {
          final session = CourseSession(
            id: course.id,
            courseName: course.courseName,
            courseCode: course.courseCode,
            teacherName: course.teacherName,
            campus: course.campus,
            location: '',
            weekday: 0,
            startSection: 0,
            endSection: 0,
            sections: const [],
            weeks: course.weeks,
            weekText: course.weekText,
            credit: course.credit,
            note: course.summary,
          );
          entries.add(
            CourseOccurrence(doc, session, mondayOf(weekStart), const []),
          );
        }
      }
    }
    String normalize(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final codesByName = <String, Set<String>>{};
    for (final entry in entries) {
      final code = normalize(entry.session.displayCourseCode);
      if (code.isNotEmpty) {
        (codesByName[normalize(entry.session.courseName)] ??= {}).add(code);
      }
    }
    final groups = <String, List<CourseOccurrence>>{};
    for (final entry in entries) {
      final name = normalize(entry.session.courseName);
      var code = normalize(entry.session.displayCourseCode);
      final candidates = codesByName[name] ?? {};
      if (code.isEmpty && candidates.length == 1) code = candidates.single;
      final key = code.isEmpty ? 'name:$name' : 'code:$code';
      (groups[key] ??= []).add(entry);
    }
    final result = <CommonCourse>[];
    for (final group in groups.values) {
      if (documents.every((doc) => group.any((e) => e.document.id == doc.id))) {
        group.sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0
              ? byDate
              : a.session.startSection.compareTo(b.session.startSection);
        });
        final codes = group
            .map((e) => e.session.displayCourseCode)
            .where((v) => v.isNotEmpty);
        result.add(
          CommonCourse(
            group.first.session.courseName,
            codes.isEmpty ? '' : codes.first,
            group,
          ),
        );
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
}
