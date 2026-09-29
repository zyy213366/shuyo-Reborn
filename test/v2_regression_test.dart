import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/data/schedule_comparison.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/features/home/comparison_week_grid.dart';
import 'package:qing_schedule/features/schedule_comparison_page.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'home_interactions_test.dart' show course, launch;
import 'schedule_comparison_test.dart' show sample;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('fresh install defaults and saved preferences survive reload', () async {
    final store = ScheduleStore();
    await store.load();
    await store.create('新课表');
    final d = store.active;
    expect([
      d.colorful,
      d.showTeacher,
      d.showOtherWeeks,
      d.showCourseCode,
      d.showGrid,
      d.showCredit,
      store.appearance.useSystemFont,
    ], everyElement(isTrue));
    expect(d.showControls, isFalse);
    expect(d.courseWeekDisplay, CourseWeekDisplay.all);
    expect(store.appearance.themeMode, ThemeMode.light);
    await store.update(d.copyWith(showTeacher: false, showControls: true));
    await store.setAppearance(
      store.appearance.copyWith(themeMode: ThemeMode.dark),
    );
    final restored = ScheduleStore();
    await restored.load();
    expect(restored.active.showTeacher, isFalse);
    expect(restored.active.showControls, isTrue);
    expect(restored.appearance.themeMode, ThemeMode.dark);
  });
  test('same catalog code does not mean the same class', () {
    final a = course('a', '形势与政策', [3, 7, 11, 15], code: '16583109', day: 3);
    final b = CourseSession.fromJson({
      ...a.toJson(),
      'id': 'b',
      'teacherName': '另一位教师',
      'location': '另一间教室',
      'weekday': 1,
      'sections': [9, 10],
      'startSection': 9,
      'endSection': 10,
      'weeks': [1, 5, 9, 13],
    });
    expect(
      ScheduleComparison.common([
        sample('a', [a]),
        sample('b', [b]),
      ], DateTime(2026, 9, 21)),
      isEmpty,
    );
  });
  test('one shared lesson does not brighten its unshared makeup date', () {
    final a =
        sample('A', [
          course('a', '数学', [1], code: 'M'),
        ]).copyWith(
          adjustments: [
            ScheduleAdjustment(
              date: DateTime(2026, 9, 12),
              sourceWeek: 1,
              sourceWeekday: 1,
            ),
          ],
        );
    final b = sample('B', [
      course('b', '数学', [1], code: 'M'),
    ]);
    final grid = ComparisonWeekGrid(
      documents: [a, b],
      monday: DateTime(2026, 9, 7),
      mode: TimetableComparisonMode.commonCourses,
      days: 7,
      firstDay: 1,
    );
    expect(grid.commonIds.contains(('A', 'a', DateTime(2026, 9, 7))), isTrue);
    expect(grid.commonIds.contains(('A', 'a', DateTime(2026, 9, 12))), isFalse);
    final shifted = sample('C', [
      course('c', '数学', [2], code: 'M'),
    ], first: DateTime(2026, 8, 31));
    expect(
      ScheduleComparison.common([a, shifted], DateTime(2026, 9, 7)),
      hasLength(1),
    );
  });
  test('anonymous export IDs cannot stand in for another participant', () {
    final a = sample('shared', [course('a', '数学', [1], code: 'M')]);
    final b = sample('shared', [course('b', '数学', [2], code: 'M')]);
    expect(ScheduleComparison.common([a, b], DateTime(2026, 9, 7)), isEmpty);
  });
  test('only identical occurrences shared by every participant qualify', () {
    final a = course('a', '数学', [1], code: 'M');
    for (final changed in <Map<String, dynamic>>[
      {'teacherName': '另一个教师'},
      {'location': '另一个教室'},
      {'weekday': 2},
      {
        'weeks': [2],
      },
      {
        'sections': [3, 4],
      },
    ]) {
      final b = CourseSession.fromJson({...a.toJson(), 'id': 'b', ...changed});
      expect(
        ScheduleComparison.common([
          sample('a', [a]),
          sample('b', [b]),
        ], DateTime(2026, 9, 7)),
        isEmpty,
        reason: '$changed',
      );
    }
    final b = CourseSession.fromJson({...a.toJson(), 'id': 'b'});
    expect(
      ScheduleComparison.common([
        sample('a', [a]),
        sample('b', [b]),
      ], DateTime(2026, 9, 7)).single.occurrences,
      hasLength(2),
    );
    expect(
      ScheduleComparison.common([
        sample('a', [a]),
        sample('b', [b]),
        sample('c', []),
      ], DateTime(2026, 9, 7)),
      isEmpty,
    );
  });
  testWidgets(
    'every week visit starts at the top including returning beyond cache',
    (tester) async {
      await launch(tester);
      Finder scroll(int week) =>
          find.byKey(PageStorageKey('academic-schedule-vertical-scroll-$week'));
      double offset(int week) => tester
          .state<ScrollableState>(
            find.descendant(
              of: scroll(week),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      await tester.drag(scroll(1), const Offset(0, -250));
      await tester.pumpAndSettle();
      final saved = offset(1);
      expect(saved, greaterThan(50));
      for (var i = 0; i < 4; i++) {
        await tester.fling(
          find.byKey(const ValueKey('schedule-gestures')),
          const Offset(-240, 0),
          800,
        );
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 4; i++) {
        await tester.fling(
          find.byKey(const ValueKey('schedule-gestures')),
          const Offset(240, 0),
          800,
        );
        await tester.pumpAndSettle();
      }
      expect(offset(1), 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
