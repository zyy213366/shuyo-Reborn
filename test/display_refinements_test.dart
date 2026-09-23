import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:qing_schedule/main.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/data/appearance_settings.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/data/schedule_week_index.dart';
import 'package:qing_schedule/features/home/schedule_gesture_pager.dart';
import 'package:qing_schedule/features/home/academic_schedule_editor_page.dart';
import 'home_interactions_test.dart' show launch, course, pinch;
import 'storage_failure_test.dart' show FailingDisk;

Future<void> displaySettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('显示设置'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tap opens centered 16-week calendar and marks actual week', (
    tester,
  ) async {
    await launch(tester);
    final label = find.byKey(const ValueKey('week-selector'));
    await tester.drag(label, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('week-selection-dialog')), findsNothing);
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    expect(tester.getCenter(dialog).dx, closeTo(206, 1));
    expect(tester.getCenter(dialog).dy, closeTo(425, 1));
    for (var week = 1; week <= 16; week++) {
      expect(find.byKey(ValueKey('choose-week-$week')), findsOneWidget);
    }
    final first = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('choose-week-1')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((first.decoration as BoxDecoration).border, isNotNull);
    await tester.tap(find.byKey(const ValueKey('choose-week-9')));
    await tester.pumpAndSettle();
    expect(find.text('第 9 周'), findsOneWidget);
    expect(find.text('（非本周）'), findsOneWidget);
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final stillCurrent = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('choose-week-1')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((stillCurrent.decoration as BoxDecoration).border, isNotNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('第 9 周'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'calendar selection keeps double-tap return to real current week',
    (tester) async {
      await launch(tester);
      final label = find.byKey(const ValueKey('week-selector'));
      await tester.tap(label);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-week-16')));
      await tester.pumpAndSettle();
      expect(find.text('第 16 周'), findsOneWidget);
      await tester.tap(label);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text('第 1 周'), findsOneWidget);
      expect(find.text('（本周）'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'grid and controls hide without losing course positions or gestures',
    (tester) async {
      final store = await launch(tester);
      final before = tester.getRect(
        find.byKey(const ValueKey('course-active')),
      );
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('显示背景格子'), findsNothing);
      await tester.tap(find.text('显示设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示背景格子'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(store.active.showGrid, isFalse);
      expect(
        tester.getRect(find.byKey(const ValueKey('course-active'))),
        before,
      );
      final cell = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('grid-cell-2-3')),
      );
      expect((cell.decoration as BoxDecoration).color, Colors.transparent);
      await displaySettings(tester);
      await tester.tap(find.text('显示课表控制栏'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-controls')), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('course-active'))).top,
        before.top - 36,
      );
      await pinch(tester, expand: true);
      expect(store.active.visibleDays, 5);
      await tester.drag(
        find.byKey(const ValueKey('schedule-gestures')),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('第 2 周'), findsOneWidget);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.showGrid, isFalse);
      expect(restarted.active.showControls, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'five day metadata wraps completely without growing course slots',
    (tester) async {
      final store = await launch(tester);
      final sample = CourseSession.fromJson({
        ...course('long', '高等数学', [1], code: 'MATH-2026-101').toJson(),
        'teacherName': '张老师李老师',
        'location': '宝山校区教学楼A101',
        'endSection': 3,
        'sections': [1, 2, 3],
      });
      await store.update(
        store.active.copyWith(
          showCourseCode: true,
          showTeacher: true,
          schedule: store.active.schedule.copyWith(sessions: [sample]),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(QingScheduleApp(store: store));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byKey(const ValueKey('course-long')));
      await pinch(tester, expand: true);
      final after = tester.getRect(find.byKey(const ValueKey('course-long')));
      expect(after.top, before.top);
      expect(after.height, before.height);
      expect(after.width, greaterThan(before.width));
      for (final text in ['MATH-2026-101', '张老师李老师', '宝山校区教学楼A101']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(
          tester.getRect(find.text(text)).bottom,
          lessThanOrEqualTo(after.bottom),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('continuous active and faded cards have opaque unbroken fills', (
    tester,
  ) async {
    await launch(tester, settings: true);
    for (final id in ['active', 'inactive']) {
      final material = tester.widget<Material>(
        find.byKey(ValueKey('course-fill-$id')),
      );
      expect(material.color!.a, 1);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(ValueKey('course-$id')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        List<int> pixel(int y) => data.sublist(
          (y * image.width + image.width - 2) * 4,
          (y * image.width + image.width - 2) * 4 + 4,
        );
        expect(pixel(60), pixel(70));
        expect(pixel(70), pixel(80));
        expect(pixel(70).last, 255);
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'appearance switches apply to sheet, home, editor and survive restart',
    (tester) async {
      await launch(tester);
      await displaySettings(tester);
      await tester.ensureVisible(find.text('深色'));
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('同步手机系统字体'))).brightness,
        Brightness.dark,
      );
      await tester.ensureVisible(find.text('同步手机系统字体'));
      await tester.tap(find.text('同步手机系统字体'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.text('同步手机系统字体')),
        ).textTheme.bodyMedium!.fontFamily,
        'QingSans',
      );
      await tester.ensureVisible(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('week-selector'))),
        ).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加课程'));
      await tester.pumpAndSettle();
      final editorTheme = Theme.of(
        tester.element(find.byType(AcademicScheduleEditorPage)),
      );
      expect(editorTheme.brightness, Brightness.dark);
      expect(editorTheme.textTheme.bodyMedium!.fontFamily, 'QingSans');
      final restarted = ScheduleStore();
      await restarted.load();
      expect(
        restarted.appearance,
        const AppearanceSettings(
          themeMode: ThemeMode.dark,
          useSystemFont: false,
        ),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'appearance is global, absent in exports, and atomic on failure',
    () async {
      final disk = FailingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      final store = ScheduleStore();
      await store.load();
      final first = await store.create('一');
      final second = await store.create('二');
      const appearance = AppearanceSettings(
        themeMode: ThemeMode.light,
        useSystemFont: false,
      );
      await store.setAppearance(appearance);
      await store.select(first.id);
      expect(store.appearance, appearance);
      expect(
        ScheduleCodec.encode(store.active),
        isNot(contains('useSystemFont')),
      );
      disk.reject = true;
      await expectLater(
        store.setAppearance(appearance.copyWith(themeMode: ThemeMode.dark)),
        throwsStateError,
      );
      expect(store.appearance, appearance);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.appearance, appearance);
      expect(restarted.byId(second.id).showGrid, isTrue);
    },
  );

  test('week index reuses filtering and occupancy across zoom frames', () {
    final schedule = emptySchedule().copyWith(
      sessions: [
        course('a', '甲', [1]),
        course('b', '乙', [2]),
      ],
    );
    final index = ScheduleWeekIndex(schedule);
    final first = index.week(1, true);
    for (var i = 0; i < 120; i++) {
      expect(identical(index.week(1, true), first), isTrue);
    }
    expect(first.sessions.map((s) => s.id), ['b', 'a']);
    expect(first.occupied, {(1, 1), (1, 2)});
    expect(index.week(1, false).sessions.single.id, 'a');
  });

  testWidgets('distant week selection builds adjacent destination pages only', (
    tester,
  ) async {
    var week = 1;
    final built = <int>{};
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ScheduleGesturePager(
              week: week,
              maxWeek: 32,
              visibleDays: 7,
              onWeekChanged: (_) {},
              onVisibleDaysChanged: (_) {},
              builder: (context, week, days, firstDay) {
                built.add(week);
                return Text('$week');
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    built.clear();
    update(() => week = 30);
    await tester.pumpAndSettle();
    expect(built, isNot(contains(15)));
    expect(built.length, lessThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
  });
}
