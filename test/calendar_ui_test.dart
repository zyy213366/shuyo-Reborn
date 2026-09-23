import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/features/home/academic_schedule_editor_page.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'storage_failure_test.dart' show FailingDisk;
import 'home_interactions_test.dart' show launch;

Future<void> openRecords(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'adding on an adjusted empty cell edits the source weekday and week',
    (tester) async {
      final store = await launch(tester);
      await store.mutate(
        store.active.id,
        (d) => d.copyWith(
          adjustments: [
            ScheduleAdjustment(
              date: d.firstWeekStart.add(const Duration(days: 6)),
              sourceWeek: 2,
              sourceWeekday: 1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('grid-cell-7-3'));
      await tester.tap(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final editor = tester.widget<AcademicScheduleEditorPage>(
        find.byType(AcademicScheduleEditorPage),
      );
      expect(editor.initialWeek, 2);
      expect(editor.initialWeekday, 1);
      expect(editor.contextNote, contains('源安排'));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('adjustment before and after teaching term remains reachable', (
    tester,
  ) async {
    final store = await launch(tester);
    final first = store.active.firstWeekStart;
    await store.mutate(
      store.active.id,
      (d) => d.copyWith(
        adjustments: [
          ScheduleAdjustment(
            date: first.subtract(const Duration(days: 1)),
            sourceWeek: 2,
            sourceWeekday: 1,
          ),
          ScheduleAdjustment(
            date: first.add(const Duration(days: 16 * 7 + 6)),
            sourceWeek: 2,
            sourceWeekday: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('上一周'));
    await tester.pumpAndSettle();
    expect(find.text('下周物理'), findsOneWidget);
    // Ordinary dates before teaching starts must not create invalid week 0.
    await tester.tap(find.byKey(const ValueKey('grid-cell-1-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grid-cell-1-3')));
    await tester.pumpAndSettle();
    expect(find.byType(AcademicScheduleEditorPage), findsNothing);
    await tester.tap(find.byKey(const ValueKey('week-selector')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('choose-week-16')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 17 周'), findsOneWidget);
    expect(find.text('下周物理'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('deleting an adjusted occurrence removes the source week only', (
    tester,
  ) async {
    final store = await launch(tester);
    await store.mutate(
      store.active.id,
      (d) => d.copyWith(
        adjustments: [
          ScheduleAdjustment(
            date: d.firstWeekStart.add(const Duration(days: 6)),
            sourceWeek: 2,
            sourceWeekday: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('下周物理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('仅第2周周一的这节课'), findsOneWidget);
    await tester.tap(find.text('仅第2周周一的这节课'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(
      store.active.schedule.sessions.any((s) => s.id == 'inactive'),
      false,
    );
    expect(store.active.schedule.sessions.any((s) => s.id == 'active'), true);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('exam UI creates edits and deletes independent exams', (
    tester,
  ) async {
    final store = await launch(tester);
    await openRecords(tester, '考试周');
    await tester.tap(find.byTooltip('添加考试'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('exam-name')), '期中数学');
    await tester.enterText(find.byKey(const ValueKey('exam-seat')), '09');
    await tester.tap(find.byKey(const ValueKey('save-record')));
    await tester.pumpAndSettle();
    expect(store.active.exams.single.courseName, '期中数学');
    expect(store.active.schedule.sessions.length, 3);
    await tester.tap(find.text('期中数学'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('exam-name')), '期末数学');
    await tester.tap(find.byKey(const ValueKey('save-record')));
    await tester.pumpAndSettle();
    expect(store.active.exams.single.courseName, '期末数学');
    await tester.longPress(find.text('期末数学'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(store.active.exams, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'adjustment editor changes source and deletion restores records',
    (tester) async {
      final store = await launch(tester);
      await openRecords(tester, '手动调休');
      await tester.tap(find.byTooltip('添加调休'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-week')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 2 周').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-record')));
      await tester.pumpAndSettle();
      expect(store.active.adjustments.single.sourceWeek, 2);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.adjustments.single.sourceWeek, 2);
      await tester.tap(find.byTooltip('删除调休'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(store.active.adjustments, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed exam save preserves form and existing data', (
    tester,
  ) async {
    final disk = FailingDisk();
    SharedPreferencesStorePlatform.instance = disk;
    final store = await launch(tester);
    await openRecords(tester, '考试周');
    await tester.tap(find.byTooltip('添加考试'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('exam-name')), '保留的输入');
    disk.reject = true;
    await tester.tap(find.byKey(const ValueKey('save-record')));
    await tester.pumpAndSettle();
    expect(store.active.exams, isEmpty);
    expect(find.text('保留的输入'), findsOneWidget);
    disk.reject = false;
    await tester.tap(find.byKey(const ValueKey('save-record')));
    await tester.pumpAndSettle();
    expect(store.active.exams.single.courseName, '保留的输入');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'adjusted home columns show replacement, then restore on deletion',
    (tester) async {
      final store = await launch(tester);
      final day = store.active.firstWeekStart.add(const Duration(days: 6));
      await store.mutate(
        store.active.id,
        (d) => d.copyWith(
          adjustments: [
            ScheduleAdjustment(date: day, sourceWeek: 2, sourceWeekday: 1),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('下周物理'), findsOneWidget);
      expect(find.text('周日课程'), findsNothing);
      expect(find.text('周日·调'), findsOneWidget);
      await store.mutate(store.active.id, (d) => d.copyWith(adjustments: []));
      await tester.pumpAndSettle();
      expect(find.text('下周物理'), findsNothing);
      expect(find.text('周日课程'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
