import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/data/schedule_comparison.dart';
import 'package:qing_schedule/data/schedule_week_index.dart';
import 'home_interactions_test.dart' show course;

Map<String, dynamic> exam({
  String id = 'exam',
  String date = '2026-10-10',
  int start = 540,
  int end = 660,
}) => {
  'id': id,
  'courseName': '高等数学',
  'date': date,
  'startMinute': start,
  'endMinute': end,
  'location': 'A101',
  'seat': '08',
  'note': '带学生证',
};
Map<String, dynamic> adjustment({
  String date = '2026-10-10',
  int week = 6,
  int day = 1,
}) => {'date': date, 'sourceWeek': week, 'sourceWeekday': day};
ScheduleDocument calendarDoc({
  List<Map<String, dynamic>>? exams,
  List<Map<String, dynamic>>? adjustments,
}) => ScheduleDocument.fromJson({
  ...ScheduleDocument(
    id: 'calendar',
    name: '秋季',
    firstWeekStart: DateTime(2026, 9, 7),
    schedule: emptySchedule().copyWith(
      sessions: [
        course('math', '高等数学', [6]),
        course('sat', '原周六课', [5], day: 6),
      ],
    ),
  ).toJson(),
  'exams': exams ?? [exam()],
  'adjustments': adjustments ?? [adjustment()],
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'calendar records survive export, copy, edit, delete and restart without changing courses',
    () async {
      final doc = calendarDoc();
      expect(doc.toJson()['exams'], [exam()]);
      expect(doc.toJson()['adjustments'], [adjustment()]);
      final store = ScheduleStore();
      await store.load();
      final added = await store.addImported(
        ScheduleCodec.decode(ScheduleCodec.encode(doc)),
      );
      final copy = await store.duplicate(added.id);
      expect(copy.toJson()['exams'], [exam()]);
      await store.update(
        ScheduleDocument.fromJson({
          ...copy.toJson(),
          'exams': [exam(end: 720)],
          'adjustments': [adjustment(day: 2)],
        }),
      );
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.toJson()['exams'], [exam(end: 720)]);
      expect(restarted.byId(added.id).toJson()['exams'], [exam()]);
      await restarted.update(
        ScheduleDocument.fromJson({
          ...restarted.active.toJson(),
          'exams': [],
          'adjustments': [],
        }),
      );
      expect(restarted.active.toJson()['exams'], isEmpty);
      expect(
        jsonEncode(restarted.active.schedule.toJson()),
        jsonEncode(doc.schedule.toJson()),
      );
    },
  );
  test(
    'legacy documents default to empty independent calendar collections',
    () {
      final data = calendarDoc().toJson()
        ..remove('exams')
        ..remove('adjustments');
      final restored = ScheduleDocument.fromJson(data);
      expect(restored.toJson()['exams'], isEmpty);
      expect(restored.toJson()['adjustments'], isEmpty);
    },
  );
  test('invalid dates, durations and duplicate day rules are rejected', () {
    for (final entries in [
      [exam(date: '2026-02-30')],
      [exam(end: 540)],
      [exam(start: -1)],
      [exam(end: 1441)],
      [exam(), exam()],
    ]) {
      expect(() => calendarDoc(exams: entries), throwsFormatException);
    }
    for (final entries in [
      [adjustment(day: 8)],
      [adjustment(week: 0)],
      [adjustment(date: '2026-02-30')],
      [adjustment(), adjustment()],
    ]) {
      expect(() => calendarDoc(adjustments: entries), throwsFormatException);
    }
  });
  test(
    'comparison resolves actual-date replacement and deletion restores original schedule',
    () {
      final doc = calendarDoc();
      final week = DateTime(2026, 10, 5);
      final entries = ScheduleComparison.occurrences(doc, week);
      expect(entries.map((e) => e.session.courseName), ['高等数学']);
      expect(entries.single.date, DateTime(2026, 10, 10));
      final restored = ScheduleDocument.fromJson({
        ...doc.toJson(),
        'adjustments': [],
      });
      expect(
        ScheduleComparison.occurrences(
          restored,
          week,
        ).single.session.courseName,
        '原周六课',
      );
      final other = doc.copyWith(id: 'other');
      expect(
        ScheduleComparison.times(
          [doc, other],
          week,
          ComparisonMode.allBusy,
        )[5].ranges,
        isNotEmpty,
      );
      expect(
        ScheduleComparison.common(
          [doc, other],
          week,
          allWeeks: false,
        ).single.name,
        '高等数学',
      );
    },
  );
  test(
    'adjustment may bring teaching courses into a date outside the term',
    () {
      final doc = calendarDoc(adjustments: [adjustment(date: '2027-02-06')]);
      expect(
        ScheduleComparison.occurrences(
          doc,
          DateTime(2027, 2, 1),
        ).single.session.courseName,
        '高等数学',
      );
    },
  );
  test(
    'week grid projects source weekday without altering original identity and ignores ghost courses on adjusted day',
    () {
      final doc = calendarDoc();
      final data = ScheduleWeekIndex.forDocument(doc).week(5, true);
      final saturday = data.sessions.where((s) => s.weekday == 6).toList();
      expect(saturday.single.id, 'math');
      expect(saturday.single.weeks, [6]);
      expect(data.occupied.contains((6, 1)), true);
      expect(doc.schedule.sessions.first.weekday, 1);
      expect(doc.schedule.sessions.first.weeks, [6]);
    },
  );
  test(
    'exams sort by day then start time while course merging keeps target calendar',
    () {
      final doc = calendarDoc(
        exams: [
          exam(id: 'late', start: 780, end: 900),
          exam(id: 'early'),
          exam(id: 'yesterday', date: '2026-10-09'),
        ],
      );
      expect(doc.exams.map((e) => e.id), ['yesterday', 'early', 'late']);
      final source = calendarDoc(
        exams: [exam(id: 'source')],
        adjustments: [],
      );
      final merged = ScheduleMerge.preview(doc, source).document;
      expect(merged.exams.map((e) => e.id), ['yesterday', 'early', 'late']);
      expect(merged.adjustments.length, 1);
    },
  );
}
