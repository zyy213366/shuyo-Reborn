import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/data/schedule_comparison.dart';
import 'package:qing_schedule/features/home/comparison_week_grid.dart';
import 'package:qing_schedule/features/home/schedule_gesture_pager.dart';
import 'package:qing_schedule/features/schedule_comparison_page.dart';
import 'home_interactions_test.dart' show course, launch;

ScheduleDocument sample(
  String id,
  List<CourseSession> sessions, {
  DateTime? first,
  List<List<int>>? times,
}) => ScheduleDocument(
  id: id,
  name: id,
  schedule: emptySchedule().copyWith(sessions: sessions),
  firstWeekStart: first ?? DateTime(2026, 9, 7),
  sectionTimes: times ?? shuSectionTimes,
);
List<(int, int)> pairs(List<MinuteRange> ranges) =>
    ranges.map((r) => (r.start, r.end)).toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'shared identity is bright, other courses dim; occupied ranges use union',
    (tester) async {
      final docs = [
        sample('A', [
          course('a', '数学', [1], code: 'M'),
          course('x', '独有', [1], day: 2),
        ]),
        sample('B', [
          course('b', '数学', [1], code: 'M', day: 3),
        ]),
      ];
      Future<void> show(TimetableComparisonMode mode) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComparisonWeekGrid(
              documents: docs,
              monday: DateTime(2026, 9, 7),
              mode: mode,
              days: 7,
              firstDay: 1,
            ),
          ),
        ),
      );
      await show(TimetableComparisonMode.commonCourses);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('comparison-course-A-a-480')),
            )
            .opacity,
        1,
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('comparison-course-A-x-480')),
            )
            .opacity,
        .25,
      );
      await show(TimetableComparisonMode.commonFree);
      for (final day in [1, 2, 3]) {
        expect(
          find.byKey(ValueKey('comparison-busy-$day-480')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('comparison-busy-$day-535')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('comparison-busy-4-480')), findsNothing);
      expect(find.byKey(const ValueKey('comparison-busy-1-525')), findsNothing);
    },
  );
  test('all busy requires every participant; free is complement of union', () {
    final a = sample('A', [
      course('a', '数学', [1]),
    ]);
    final b = sample(
      'B',
      [
        course('b', '语文', [1]),
      ],
      times: [
        [8, 30, 9, 0],
        [9, 10, 9, 50],
        ...shuSectionTimes.skip(2),
      ],
    );
    final c = sample(
      'C',
      [
        course('c', '英语', [1]),
      ],
      times: [
        [8, 40, 8, 50],
        [9, 20, 9, 30],
        ...shuSectionTimes.skip(2),
      ],
    );
    final busy = ScheduleComparison.times(
      [a, b, c],
      DateTime(2026, 9, 7),
      ComparisonMode.allBusy,
    );
    expect(pairs(busy.first.ranges), [(520, 525), (560, 570)]);
    final free = ScheduleComparison.times(
      [a, b, c],
      DateTime(2026, 9, 7),
      ComparisonMode.allFree,
      start: 480,
      end: 600,
    );
    expect(pairs(free.first.ranges), [(590, 600)]);
    expect(pairs(free[1].ranges), [(480, 600)]);
    expect(
      ScheduleComparison.times(
        [a],
        DateTime(2026, 9, 7),
        ComparisonMode.allFree,
      ),
      isEmpty,
    );
  });
  test(
    'real dates align different semester starts, and noncontiguous sections stay separate',
    () {
      final a = sample('A', [
        CourseSession.fromJson({
          ...course('a', '数学', [2]).toJson(),
          'sections': [1, 3],
          'endSection': 3,
        }),
      ]);
      final b = sample('B', [
        CourseSession.fromJson({
          ...course('b', '数学', [1]).toJson(),
          'sections': [1, 3],
          'endSection': 3,
        }),
      ], first: DateTime(2026, 9, 14));
      final result = ScheduleComparison.times(
        [a, b],
        DateTime(2026, 9, 14),
        ComparisonMode.allBusy,
      );
      expect(pairs(result.first.ranges), [(480, 525), (600, 645)]);
      expect(
        ScheduleComparison.times(
          [a, b],
          DateTime(2026, 9, 7),
          ComparisonMode.allBusy,
        ).every((d) => d.ranges.isEmpty),
        true,
      );
    },
  );
  test('overlaps and touching intervals merge without duplicate output', () {
    expect(
      pairs(
        ScheduleComparison.merge([
          const MinuteRange(500, 550),
          const MinuteRange(520, 600),
          const MinuteRange(600, 620),
        ]),
      ),
      [(500, 620)],
    );
  });
  test('common courses match identity even at different times and weeks', () {
    final a = sample('A', [
      course('a', '数学', [1], code: 'MATH'),
      course('x', '同名', [1], code: 'X'),
    ]);
    final b = sample('B', [
      course('b', '数学', [2], code: 'MATH', day: 3),
      course('y', '同名', [1], code: 'Y'),
    ]);
    final common = ScheduleComparison.common([a, b], DateTime(2026, 9, 7));
    expect(common.single.name, '数学');
    expect(common.single.occurrences.map((e) => e.session.weekday), [1, 3]);
    expect(
      ScheduleComparison.common([a, b], DateTime(2026, 9, 7), allWeeks: false),
      isEmpty,
    );
    final missing = sample('C', [
      course('c', '数学', [1]),
    ]);
    expect(
      ScheduleComparison.common([
        a,
        b,
        missing,
      ], DateTime(2026, 9, 7)).single.occurrences.length,
      3,
    );
    final ambiguous = sample('D', [
      course('d', '同名', [1]),
    ]);
    expect(
      ScheduleComparison.common([a, b, ambiguous], DateTime(2026, 9, 7)),
      isEmpty,
    );
  });
  testWidgets(
    'more opens comparison, multiple selection and all result modes work',
    (tester) async {
      final store = await launch(tester);
      final original = store.active.id;
      await store.create('朋友课表', schedule: store.active.schedule.copyWith(sessions: [...store.active.schedule.sessions, course('late','后续课程',[20])]), firstWeekStart: store.active.firstWeekStart);
      await store.select(original);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('课表对比'));
      await tester.pumpAndSettle();
      expect(find.text('请至少选择两张课表进行对比'), findsOneWidget);
      await tester.tap(find.text('全选'));
      await tester.pumpAndSettle();
      expect(find.text('选择课表（已选 2 张）'), findsOneWidget);
      expect(find.text('都有课时间段'), findsNothing);
      await tester.tap(find.text('开始对比'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('comparison-grid')), findsWidgets);
      expect(tester.widget<ScheduleGesturePager>(find.byType(ScheduleGesturePager)).maxWeek, 20);
      expect(find.text('共同课程'), findsOneWidget);
      await tester.tap(find.text('共同空闲'));
      await tester.pumpAndSettle();
      expect(find.text('空白区域为共同空闲'), findsOneWidget);
      expect(find.byKey(const ValueKey('comparison-busy-1-480')), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('退出对比'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('comparison-grid')), findsNothing);
      expect(store.active.id, original);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
