import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/main.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'schedule_store_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('both overlapping courses remain reachable after merge', (
    tester,
  ) async {
    final store = ScheduleStore();
    await store.load();
    final raw = fixture().sessions.first.toJson();
    raw.addAll({
      'id': 'a',
      'weekday': 1,
      'startSection': 1,
      'endSection': 2,
      'sections': [1, 2],
      'weeks': [1],
      'courseName': '重叠甲',
    });
    final a = CourseSession.fromJson(raw);
    final b = CourseSession.fromJson({...raw, 'id': 'b', 'courseName': '重叠乙'});
    await store.create(
      '测试课表',
      schedule: fixture().copyWith(sessions: [a, b]),
      firstWeekStart: DateTime.now(),
    );
    await tester.pumpWidget(QingScheduleApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重叠乙'));
    await tester.pumpAndSettle();
    expect(find.text('同一时段的课程'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '重叠甲'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('重叠甲'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('seven weekdays fit in $width px with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = ScheduleStore();
        await store.load();
        final raw = fixture().sessions.first.toJson();
        raw.addAll({
          'weekday': 7,
          'startSection': 1,
          'endSection': 1,
          'sections': [1],
          'weeks': [1],
          'courseName': '周日的一节超长课程名称',
        });
        await store.create(
          '测试课表',
          schedule: fixture().copyWith(sessions: [CourseSession.fromJson(raw)]),
          firstWeekStart: DateTime.now(),
        );
        await tester.pumpWidget(QingScheduleApp(store: store));
        await tester.pumpAndSettle();
        for (final day in ['周一', '周二', '周三', '周四', '周五', '周六', '周日']) {
          final header = find.text(day).first;
          expect(header, findsOneWidget);
          final rect = tester.getRect(header);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        final course = find.text('周日的一节超长课程名称');
        expect(course, findsOneWidget);
        expect(tester.getRect(course).right, lessThanOrEqualTo(width));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(course);
        await tester.pumpAndSettle();
        expect(find.text('周日的一节超长课程名称'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('launch needs no account and management can duplicate', (
    tester,
  ) async {
    final store = ScheduleStore();
    await store.load();
    await tester.pumpWidget(QingScheduleApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('登录'), findsNothing);
    expect(find.byTooltip('管理课表'), findsNothing);
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理课表'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('复制课表').first);
    await tester.pumpAndSettle();
    expect(store.documents.length, 2);
    expect(store.active.name, contains('副本'));
    await tester.pumpWidget(const SizedBox());
  });
}
