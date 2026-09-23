import 'course_labels.dart';
import 'calendar_records.dart';
export 'calendar_records.dart';
export 'course_labels.dart';

import 'dart:convert';

import 'models/academic_schedule.dart';

const shuSectionTimes = <List<int>>[
  [8, 0, 8, 45],
  [8, 55, 9, 40],
  [10, 0, 10, 45],
  [10, 55, 11, 40],
  [13, 0, 13, 45],
  [13, 55, 14, 40],
  [15, 0, 15, 45],
  [15, 55, 16, 40],
  [18, 0, 18, 45],
  [18, 55, 19, 40],
  [20, 0, 20, 45],
  [20, 55, 21, 40],
];

DateTime mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

AcademicSchedule anonymousSchedule(AcademicSchedule schedule) {
  final data = schedule.toJson();
  final term = data['term'] as Map<String, dynamic>;
  term['studentName'] = '';
  term['studentId'] = '';
  term['className'] = '';
  final copied = AcademicSchedule.fromJson(
    jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
  );
  return copied.copyWith(
    sessions: List.unmodifiable(
      copied.sessions.map(
        (s) => CourseSession(
          id: s.id,
          courseName: s.courseName,
          courseCode: s.courseCode,
          teacherName: s.teacherName,
          campus: s.campus,
          location: s.location,
          weekday: s.weekday,
          startSection: s.startSection,
          endSection: s.endSection,
          sections: List.unmodifiable(s.sections),
          weeks: List.unmodifiable(s.weeks),
          weekText: s.weekText,
          credit: s.credit,
          note: s.note,
        ),
      ),
    ),
    untimedCourses: List.unmodifiable(
      copied.untimedCourses.map(
        (s) => UntimedCourse(
          id: s.id,
          courseCode: s.courseCode,
          courseName: s.courseName,
          teacherName: s.teacherName,
          campus: s.campus,
          weeks: List.unmodifiable(s.weeks),
          weekText: s.weekText,
          summary: s.summary,
          credit: s.credit,
        ),
      ),
    ),
  );
}

AcademicSchedule emptySchedule() => AcademicSchedule(
  term: const AcademicTerm(
    yearCode: '',
    termCode: '',
    academicYearName: '',
    termName: '',
    studentName: '',
    studentId: '',
    className: '',
  ),
  sessions: const [],
  untimedCourses: const [],
  fetchedAt: DateTime.now(),
);

class ScheduleDocument {
  ScheduleDocument({
    required this.id,
    required this.name,
    required AcademicSchedule schedule,
    required DateTime firstWeekStart,
    this.colorful = false,
    this.showTeacher = false,
    this.showOtherWeeks = false,
    this.showCourseCode = false,
    this.visibleDays = 7,
    this.showGrid = true,
    this.showControls = true,
    this.showCredit = false,
    this.courseWeekDisplay = CourseWeekDisplay.none,
    Map<String, int> colors = const {},
    List<List<int>> sectionTimes = shuSectionTimes,
    List<ExamRecord> exams = const [],
    List<ScheduleAdjustment> adjustments = const [],
  }) : schedule = anonymousSchedule(schedule),
       exams = List.unmodifiable(
         [...exams]..sort((a, b) {
           final date = a.date.compareTo(b.date);
           return date != 0 ? date : a.startMinute.compareTo(b.startMinute);
         }),
       ),
       adjustments = List.unmodifiable(
         [...adjustments]..sort((a, b) => a.date.compareTo(b.date)),
       ),
       firstWeekStart = mondayOf(firstWeekStart),
       colors = Map.unmodifiable(colors),
       sectionTimes = List.unmodifiable(
         sectionTimes.map((row) => List<int>.unmodifiable(row)),
       );
  final String id;
  final String name;
  final AcademicSchedule schedule;
  final DateTime firstWeekStart;
  final bool colorful;
  final bool showTeacher;
  final bool showOtherWeeks;
  final bool showCourseCode;
  final int visibleDays;
  final bool showGrid;
  final bool showControls;
  final bool showCredit;
  final CourseWeekDisplay courseWeekDisplay;
  final Map<String, int> colors;
  final List<List<int>> sectionTimes;
  final List<ExamRecord> exams;
  final List<ScheduleAdjustment> adjustments;

  ScheduleDocument copyWith({
    String? id,
    String? name,
    AcademicSchedule? schedule,
    DateTime? firstWeekStart,
    bool? colorful,
    bool? showTeacher,
    bool? showOtherWeeks,
    bool? showCourseCode,
    int? visibleDays,
    bool? showGrid,
    bool? showControls,
    bool? showCredit,
    CourseWeekDisplay? courseWeekDisplay,
    Map<String, int>? colors,
    List<List<int>>? sectionTimes,
    List<ExamRecord>? exams,
    List<ScheduleAdjustment>? adjustments,
  }) => ScheduleDocument(
    id: id ?? this.id,
    name: name ?? this.name,
    schedule: schedule ?? this.schedule,
    firstWeekStart: firstWeekStart ?? this.firstWeekStart,
    colorful: colorful ?? this.colorful,
    showTeacher: showTeacher ?? this.showTeacher,
    showOtherWeeks: showOtherWeeks ?? this.showOtherWeeks,
    showCourseCode: showCourseCode ?? this.showCourseCode,
    visibleDays: visibleDays ?? this.visibleDays,
    showGrid: showGrid ?? this.showGrid,
    showControls: showControls ?? this.showControls,
    showCredit: showCredit ?? this.showCredit,
    courseWeekDisplay: courseWeekDisplay ?? this.courseWeekDisplay,
    colors: colors ?? this.colors,
    sectionTimes: sectionTimes ?? this.sectionTimes,
    exams: exams ?? this.exams,
    adjustments: adjustments ?? this.adjustments,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'schedule': schedule.toJson(),
    'firstWeekStart': firstWeekStart.toIso8601String(),
    'colorful': colorful,
    'showTeacher': showTeacher,
    'showOtherWeeks': showOtherWeeks,
    'showCourseCode': showCourseCode,
    'visibleDays': visibleDays,
    'showGrid': showGrid,
    'showControls': showControls,
    'showCredit': showCredit,
    'courseWeekDisplay': courseWeekDisplay.name,
    'colors': colors,
    'sectionTimes': sectionTimes,
    'exams': exams.map((e) => e.toJson()).toList(),
    'adjustments': adjustments.map((a) => a.toJson()).toList(),
  };

  static ScheduleDocument fromJson(Map<String, dynamic> json) {
    ScheduleCodec.validateDocument(json);
    return ScheduleDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      exams: readCalendarRecords(json['exams'], ExamRecord.fromJson),
      adjustments: readCalendarRecords(
        json['adjustments'],
        ScheduleAdjustment.fromJson,
      ),
      schedule: AcademicSchedule.fromJson(
        json['schedule'] as Map<String, dynamic>,
      ),
      firstWeekStart: DateTime.parse(json['firstWeekStart'] as String),
      colorful: json['colorful'] as bool,
      showTeacher: json['showTeacher'] as bool,
      showOtherWeeks: json['showOtherWeeks'] as bool? ?? false,
      showCourseCode: json['showCourseCode'] as bool? ?? false,
      visibleDays: json['visibleDays'] as int? ?? 7,
      showGrid: json['showGrid'] as bool? ?? true,
      showControls: json['showControls'] as bool? ?? true,
      showCredit: json['showCredit'] as bool? ?? false,
      courseWeekDisplay: CourseWeekDisplay.values.firstWhere(
        (v) => v.name == json['courseWeekDisplay'],
        orElse: () => CourseWeekDisplay.none,
      ),
      colors: Map<String, int>.from(json['colors'] as Map),
      sectionTimes: (json['sectionTimes'] as List)
          .map((r) => List<int>.from(r as List))
          .toList(),
    );
  }
}

class ScheduleCodec {
  static const maxBytes = 2 * 1024 * 1024;
  static String encode(ScheduleDocument doc) {
    final payload = doc.toJson()..['id'] = 'shared';
    validateDocument(payload);
    final raw = jsonEncode({
      'format': 'qing-schedule',
      'version': 1,
      'document': payload,
    });
    if (utf8.encode(raw).length > maxBytes) {
      throw const FormatException('课表文件超过 2 MB');
    }
    return raw;
  }

  static ScheduleDocument decode(String raw) {
    if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
      throw const FormatException('课表文件超过 2 MB');
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['format'] != 'qing-schedule' || data['version'] != 1) {
        throw const FormatException('请选择轻课表分享的文件（版本 1）');
      }
      return ScheduleDocument.fromJson(
        data['document'] as Map<String, dynamic>,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('课表文件结构不完整或格式不正确');
    }
  }

  static void validateDocument(Map<String, dynamic> doc) {
    void check(bool valid) {
      if (!valid) throw const FormatException('课表字段缺失或超出允许范围');
    }

    final exams = readCalendarRecords(doc['exams'], ExamRecord.fromJson);
    final rules = readCalendarRecords(
      doc['adjustments'],
      ScheduleAdjustment.fromJson,
    );
    check(exams.map((e) => e.id).toSet().length == exams.length);
    check(rules.map((a) => a.date).toSet().length == rules.length);

    bool text(Object? s, int max, {bool required = false}) =>
        s is String && s.length <= max && (!required || s.trim().isNotEmpty);
    check(
      text(doc['id'], 160, required: true) &&
          text(doc['name'], 80, required: true),
    );
    final date = doc['firstWeekStart'] is String
        ? DateTime.tryParse(doc['firstWeekStart'] as String)
        : null;
    check(date != null && date.year >= 2000 && date.year <= 2100);
    final datePrefix = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:T00:00:00(?:\.000)?)?$',
    ).firstMatch(doc['firstWeekStart'] as String);
    check(
      datePrefix != null &&
          date!.year == int.parse(datePrefix.group(1)!) &&
          date.month == int.parse(datePrefix.group(2)!) &&
          date.day == int.parse(datePrefix.group(3)!),
    );
    check(doc['colorful'] is bool && doc['showTeacher'] is bool);
    for (final key in [
      'showOtherWeeks',
      'showCourseCode',
      'showGrid',
      'showControls',
      'showCredit',
    ]) {
      check(doc[key] == null || doc[key] is bool);
    }
    check(
      doc['visibleDays'] == null ||
          doc['visibleDays'] == 5 ||
          doc['visibleDays'] == 7,
    );
    check(
      doc['courseWeekDisplay'] == null ||
          CourseWeekDisplay.values.any(
            (v) => v.name == doc['courseWeekDisplay'],
          ),
    );
    check(doc['colors'] is Map && (doc['colors'] as Map).length <= 1000);
    for (final e in (doc['colors'] as Map).entries) {
      check(
        text(e.key, 300) &&
            e.value is int &&
            (e.value as int) >= 0 &&
            (e.value as int) <= 0xffffffff,
      );
    }
    final times = doc['sectionTimes'];
    check(times is List && times.length == 12);
    var previousEnd = -1;
    for (final row in times as List) {
      check(row is List && row.length == 4);
      for (var i = 0; i < 4; i++) {
        check(row[i] is int && row[i] >= 0 && row[i] < (i.isEven ? 24 : 60));
      }
      final start = (row[0] as int) * 60 + (row[1] as int);
      final end = (row[2] as int) * 60 + (row[3] as int);
      check(start < end && start >= previousEnd);
      previousEnd = end;
    }
    final schedule = doc['schedule'];
    check(schedule is Map<String, dynamic>);
    check(
      schedule['term'] is Map &&
          schedule['sessions'] is List &&
          schedule['untimedCourses'] is List,
    );
    check(
      text(schedule['fetchedAt'], 80) &&
          DateTime.tryParse(schedule['fetchedAt'] as String) != null,
    );
    final term = schedule['term'] as Map;
    for (final field in [
      'yearCode',
      'termCode',
      'academicYearName',
      'termName',
      'studentName',
      'studentId',
      'className',
    ]) {
      check(text(term[field], 300));
    }
    final sessions = schedule['sessions'] as List;
    final untimed = schedule['untimedCourses'] as List;
    check(sessions.length <= 1000 && untimed.length <= 500);
    final courseIds = <String>{};
    for (final s in [...sessions, ...untimed]) {
      check(s is Map<String, dynamic>);
      check(
        text(s['id'], 300, required: true) &&
            courseIds.add(s['id'] as String) &&
            text(s['courseName'], 200, required: true),
      );
      for (final key in ['teacherName', 'campus', 'weekText', 'credit']) {
        check(text(s[key], 500));
      }
      check(s['weeks'] is List && (s['weeks'] as List).length <= 32);
      for (final w in s['weeks'] as List) {
        check(w is int && w >= 1 && w <= 32);
      }
    }
    for (final s in untimed) {
      check(s['courseCode'] == null || text(s['courseCode'], 300));
      check(text(s['summary'], 2000));
    }
    for (final s in sessions) {
      check(
        (s['courseCode'] == null || text(s['courseCode'], 300)) &&
            text(s['location'], 500) &&
            text(s['note'], 2000),
      );
      check(s['weekday'] is int && s['weekday'] >= 1 && s['weekday'] <= 7);
      check(
        s['startSection'] is int &&
            s['endSection'] is int &&
            s['startSection'] >= 1 &&
            s['endSection'] <= 12 &&
            s['startSection'] <= s['endSection'],
      );
      check(
        s['sections'] is List &&
            (s['sections'] as List).isNotEmpty &&
            (s['sections'] as List).length <= 12,
      );
      for (final n in s['sections'] as List) {
        check(n is int && n >= s['startSection'] && n <= s['endSection']);
      }
    }
  }
}
