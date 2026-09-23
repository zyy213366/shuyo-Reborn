import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:qing_schedule/main.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/data/services/academic_schedule_display_settings_service.dart';
import 'package:qing_schedule/services/shu_import_script.dart';
import 'schedule_store_test.dart' show fixture;
import 'storage_failure_test.dart' show FailingDisk;

CourseSession course(
  String id,
  String name,
  List<int> weeks, {
  String code = '',
  int day = 1,
}) => CourseSession.fromJson({
  ...fixture().sessions.first.toJson(),
  'id': id,
  'courseName': name,
  'courseCode': code,
  'weekday': day,
  'startSection': 1,
  'endSection': 2,
  'sections': [1, 2],
  'weeks': weeks,
});

Future<ScheduleStore> launch(
  WidgetTester tester, {
  bool settings = false,
}) async {
  tester.view.physicalSize = const Size(412, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = ScheduleStore();
  await store.load();
  final doc = await store.create(
    '秋季课表',
    firstWeekStart: DateTime.now(),
    schedule: fixture().copyWith(
      sessions: [
        course('active', '本周数学', [1], code: 'MATH-001'),
        course('inactive', '下周物理', [2], code: 'PHY-002'),
        course('sunday', '周日课程', [1, 2], day: 7),
      ],
      untimedCourses: [],
    ),
  );
  if (settings) {
    await store.update(
      doc.copyWith(showOtherWeeks: true, showCourseCode: true),
    );
  }
  await tester.pumpWidget(QingScheduleApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Future<void> pinch(WidgetTester tester, {required bool expand}) async {
  final center = tester.getCenter(
    find.byKey(const ValueKey('schedule-gestures')),
  );
  final start = expand ? 45.0 : 115.0;
  final end = expand ? 115.0 : 45.0;
  final a = await tester.startGesture(center - Offset(start, 0), pointer: 1);
  final b = await tester.startGesture(center + Offset(start, 0), pointer: 2);
  await tester.pump();
  for (var i = 1; i <= 6; i++) {
    final dx = start + (end - start) * i / 6;
    await a.moveTo(center - Offset(dx, 0));
    await b.moveTo(center + Offset(dx, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  // The remaining finger must not turn a pinch into a swipe.
  await b.moveBy(const Offset(-70, 0));
  await b.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'new display preferences survive restart, copy, export and legacy input',
    () async {
      final store = ScheduleStore();
      await store.load();
      final doc = await store.create('秋季', schedule: fixture());
      final service = AcademicScheduleDisplaySettingsService(
        store: store,
        documentId: doc.id,
      );
      await service.saveSettings(
        const AcademicScheduleDisplaySettings(
          colorful: true,
          showTeacher: true,
          showOtherWeeks: true,
          showCourseCode: true,
          visibleDays: 5,
        ),
      );
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.visibleDays, 5);
      expect(restarted.active.showOtherWeeks, isTrue);
      expect(restarted.active.showCourseCode, isTrue);
      final copy = await restarted.duplicate(doc.id);
      final roundtrip = ScheduleCodec.decode(ScheduleCodec.encode(copy));
      expect(roundtrip.visibleDays, 5);
      expect(roundtrip.showCourseCode, isTrue);
      final legacy = roundtrip.toJson()
        ..remove('visibleDays')
        ..remove('showOtherWeeks')
        ..remove('showCourseCode');
      for (final s in legacy['schedule']['sessions']) {
        s.remove('courseCode');
      }
      final decoded = ScheduleDocument.fromJson(legacy);
      expect(decoded.visibleDays, 7);
      expect(decoded.showOtherWeeks, isFalse);
      expect(decoded.schedule.sessions.first.courseCode, isEmpty);
    },
  );

  test(
    'school course codes use readable code, aliases, blanks and untimed rows',
    () {
      final row = <String, dynamic>{
        'kcmc': '数学',
        'xqj': '1',
        'jcs': '1-2',
        'zcd': '1-2周',
      };
      for (final field in [
        'kch',
        'kch_id',
        'courseCode',
        'courseId',
        'Course Code',
        'Course ID',
        '课程号',
      ]) {
        final parsed = ShuImport.parse(
          jsonEncode({
            'xsxx': {},
            'kbList': [
              {...row, field: '001-AB'},
            ],
          }),
        );
        expect(parsed.sessions.single.courseCode, '001-AB');
      }
      final parsed = ShuImport.parse(
        jsonEncode({
          'xsxx': {},
          'kbList': [
            {...row, 'kch': 'VISIBLE', 'kch_id': 'opaque-id'},
            {...row, 'kch': ' ', 'kch_id': 'FALLBACK'},
            row,
          ],
          'sjkList': [
            {'kcmc': '实践', 'kch': 'LAB-01', 'qsjsz': '1-2周'},
          ],
        }),
      );
      expect(parsed.sessions.map((s) => s.courseCode), [
        'VISIBLE',
        'FALLBACK',
        '',
      ]);
      final doc = ScheduleDocument(
        id: 'x',
        name: '导入',
        schedule: parsed,
        firstWeekStart: DateTime.now(),
      );
      final decoded = ScheduleCodec.decode(ScheduleCodec.encode(doc));
      expect(decoded.schedule.untimedCourses.single.courseCode, 'LAB-01');
      expect(decoded.schedule.sessions.first.courseCode, 'VISIBLE');
    },
  );

  testWidgets(
    'swipe follows finger, snaps, updates dates and never opens a course',
    (tester) async {
      await launch(tester);
      expect(find.byKey(const ValueKey('today-header')), findsOneWidget);
      final headerBefore = tester.getTopLeft(find.text('周一'));
      final start = tester.getCenter(find.text('本周数学'));
      final finger = await tester.startGesture(start);
      await finger.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('周一').first).dx,
        lessThan(headerBefore.dx),
      );
      await finger.up();
      await tester.pumpAndSettle();
      expect(find.text('第 2 周'), findsOneWidget);
      expect(find.text('下周物理'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-header')), findsNothing);
      expect(find.text('编辑'), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('schedule-gestures')),
        const Offset(230, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('第 1 周'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-header')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pinch animates five/seven days, persists and preserves week and weekend access',
    (tester) async {
      final store = await launch(tester);
      final before = tester
          .getSize(find.byKey(const ValueKey('course-active')))
          .width;
      await pinch(tester, expand: true);
      expect(store.active.visibleDays, 5);
      expect(find.text('第 1 周'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('course-active'))).width,
        greaterThan(before),
      );
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.visibleDays, 5);
      await tester.tap(find.byKey(const ValueKey('five-day-range')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('five-day-range')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('周日')).right, lessThanOrEqualTo(412));
      await pinch(tester, expand: false);
      expect(store.active.visibleDays, 7);
      expect(tester.getRect(find.text('周日')).right, lessThanOrEqualTo(412));
      expect(find.text('第 1 周'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'vertical scroll stays native and pinch cancels an in-progress week drag',
    (tester) async {
      await launch(tester);
      final top = tester.getTopLeft(find.text('本周数学')).dy;
      await tester.drag(
        find.byKey(const ValueKey('schedule-gestures')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('本周数学')).dy, lessThan(top));
      expect(find.text('第 1 周'), findsOneWidget);
      final center = tester.getCenter(
        find.byKey(const ValueKey('schedule-gestures')),
      );
      final a = await tester.startGesture(center, pointer: 1);
      await a.moveBy(const Offset(-100, 0));
      await tester.pump();
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(40, 0));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(find.text('第 1 周'), findsOneWidget);
      expect(find.text('编辑'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'more switches apply immediately and faded overlaps remain reachable',
    (tester) async {
      final store = await launch(tester);
      expect(find.text('MATH-001'), findsNothing);
      expect(find.text('下周物理'), findsNothing);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('显示非本周课程'), findsNothing);
      expect(find.text('显示课程号'), findsNothing);
      await tester.tap(find.text('显示设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示非本周课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示课程号'));
      await tester.pumpAndSettle();
      expect(store.active.showOtherWeeks, isTrue);
      expect(store.active.showCourseCode, isTrue);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('MATH-001'), findsOneWidget);
      final faded = tester
          .widget<Material>(find.byKey(const ValueKey('course-fill-inactive')))
          .color!;
      final active = tester
          .widget<Material>(find.byKey(const ValueKey('course-fill-active')))
          .color!;
      expect(faded.a, 1);
      expect(active.a, 1);
      expect(faded, isNot(active));
      await tester.tap(find.text('本周数学'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '下周物理'));
      await tester.pumpAndSettle();
      expect(find.text('非本周课程'), findsOneWidget);
      expect(find.text('PHY-002'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wheel switches on settle and actions still work after schedule change',
    (tester) async {
      final store = await launch(tester);
      final original = store.active.id;
      final second = await store.create('第二张课表');
      await store.select(original);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      final wheel = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      final index = store.documents.indexWhere((d) => d.id == second.id);
      wheel.scrollController!.animateToItem(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      await tester.pumpAndSettle();
      expect(store.active.id, second.id);
      await tester.tap(find.text('显示设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示课程号'));
      await tester.pumpAndSettle();
      expect(store.active.showCourseCode, isTrue);
      expect(store.byId(original).showCourseCode, isFalse);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加课程'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '课程号'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, '课程名称'),
        '手动课程',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '课程号'),
        'MAN-007',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.active.schedule.sessions.single.courseCode, 'MAN-007');
      expect(store.active.schedule.sessions.single.isManual, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancelled gestures, short drags and term boundaries do not change week',
    (tester) async {
      await launch(tester);
      final center = tester.getCenter(
        find.byKey(const ValueKey('schedule-gestures')),
      );
      var finger = await tester.startGesture(center);
      await finger.moveBy(const Offset(-12, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await finger.up();
      await tester.pumpAndSettle();
      expect(find.text('第 1 周'), findsOneWidget);
      finger = await tester.startGesture(center);
      await finger.moveBy(const Offset(-180, 0));
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(find.text('第 1 周'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('schedule-gestures')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('第 1 周'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'one-section cards fit code, teacher and room with large system text',
    (tester) async {
      final store = await launch(tester);
      tester.view.physicalSize = const Size(320, 750);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final short = CourseSession.fromJson({
        ...course('short', '短课名称', [1], code: 'SHORT-1').toJson(),
        'startSection': 1,
        'endSection': 1,
        'sections': [1],
        'teacherName': '张老师',
        'location': 'A101',
      });
      await store.update(
        store.active.copyWith(
          showCourseCode: true,
          showTeacher: true,
          schedule: store.active.schedule.copyWith(sessions: [short]),
        ),
      );
      // Reload as on restart so all persisted settings and course data are read.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(QingScheduleApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('SHORT-1'), findsOneWidget);
      expect(find.text('张老师'), findsOneWidget);
      expect(find.text('A101'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('SHORT-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, '课程号');
      expect(tester.widget<TextFormField>(field).controller!.text, 'SHORT-1');
      await tester.enterText(field, '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(store.active.schedule.sessions.single.courseCode, isEmpty);
      expect(find.text('SHORT-1'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed preference writes roll back both menu and zoom', (
    tester,
  ) async {
    final disk = FailingDisk();
    SharedPreferencesStorePlatform.instance = disk;
    final store = await launch(tester);
    disk.reject = true;
    final width = tester
        .getSize(find.byKey(const ValueKey('course-active')))
        .width;
    await pinch(tester, expand: true);
    expect(store.active.visibleDays, 7);
    expect(find.text('7天'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('course-active'))).width,
      width,
    );
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示课程号'));
    await tester.pumpAndSettle();
    expect(store.active.showCourseCode, isFalse);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
