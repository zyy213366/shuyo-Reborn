// Optional visual check: flutter test tool/capture_home_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/main.dart';
import 'package:qing_schedule/data/appearance_settings.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import '../test/home_interactions_test.dart' show course;
import '../test/schedule_store_test.dart' show fixture;

void main() {
  testWidgets('render refinements with the bundled Chinese font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 850);
    tester.view.devicePixelRatio = 1;
    await (FontLoader(
      'QingSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    // This optional test harness lives outside test/ so it runs only on demand.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final store = ScheduleStore();
    await store.load();
    await store.create('春季课表');
    await store.create('朋友的课表');
    final doc = await store.create(
      '2026 秋季 · 上海大学',
      firstWeekStart: DateTime.now(),
      schedule: fixture().copyWith(
        sessions: [
          CourseSession.fromJson({
            ...course('math', '高等数学', [1, 2], code: 'MATH-2026-101').toJson(),
            'teacherName': '张老师李老师',
            'location': '宝山校区A101',
          }),
          course('english', '大学英语', [1, 2], code: 'ENG102', day: 2),
          course('physics', '大学物理', [2], code: 'PHY201', day: 3),
          course('programming', '程序设计', [1, 2], code: 'CS103', day: 4),
          course('art', '艺术欣赏', [1], day: 6),
          course('lab', '物理实验', [2], code: 'LAB201', day: 7),
        ],
        untimedCourses: [],
      ),
    );
    await store.update(
      doc.copyWith(
        showOtherWeeks: true,
        showCourseCode: true,
        showTeacher: true,
        colorful: true,
        showCredit: true,
        courseWeekDisplay: CourseWeekDisplay.all,
      ),
    );
    await store.setAppearance(
      const AppearanceSettings(
        themeMode: ThemeMode.light,
        useSystemFont: false,
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: QingScheduleApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final output = Directory('build/previews')..createSync(recursive: true);
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${output.path}/$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await capture('light-seven');
    await store.mutate(
      doc.id,
      (d) => d.copyWith(
        exams: [
          ExamRecord(
            id: 'preview-exam',
            courseName: '高等数学期中考试',
            date: DateTime(2026, 10, 10),
            startMinute: 540,
            endMinute: 660,
            location: '宝山校区 A101',
            seat: '08',
            note: '携带学生证及计算器',
          ),
        ],
        adjustments: [
          ScheduleAdjustment(
            date: d.firstWeekStart.add(const Duration(days: 5)),
            sourceWeek: 2,
            sourceWeekday: 3,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await capture('adjusted-home');
    for (final label in ['考试周', '手动调休']) {
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await capture(label == '考试周' ? 'exam-calendar' : 'adjustment-calendar');
      await tester.tap(find.byTooltip(label == '考试周' ? '添加考试' : '添加调休'));
      await tester.pumpAndSettle();
      await capture(label == '考试周' ? 'exam-editor' : 'adjustment-editor');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('7天'));
    await tester.pumpAndSettle();
    await capture('light-five');
    await tester.tap(find.byKey(const ValueKey('week-selector')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await capture('week-calendar');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await capture('more');
    await tester.tap(find.text('显示设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示背景格子'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示课表控制栏'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('深色'));
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    await capture('dark-settings');
    await tester.ensureVisible(find.text('完成'));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await capture('dark-gridless');
    tester.view.physicalSize = const Size(320, 750);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await capture('small-large-text');
    tester.view.physicalSize = const Size(412, 850);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    final friend = store.documents.firstWhere((d) => d.name == '朋友的课表');
    await store.update(friend.copyWith(schedule: doc.schedule));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课表对比'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('compare-select-${friend.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始对比'));
    await tester.pumpAndSettle();
    await capture('comparison-courses');
    await tester.tap(find.text('共同空闲'));
    await tester.pumpAndSettle();
    await capture('comparison-free');
    await tester.tap(find.text('共同课程'));
    await tester.pumpAndSettle();
    await capture('comparison-courses');
    await tester.pumpWidget(const SizedBox());
  });
}

