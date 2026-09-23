import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/main.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/features/home/adaptive_course_text.dart';
import 'package:qing_schedule/shared/device_font_service.dart';
import 'package:qing_schedule/shared/theme/shuyo_theme.dart';
import 'home_interactions_test.dart' show launch, course;
import 'display_refinements_test.dart' show displaySettings;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('actual week combinations are lossless; credit preserves fractions', () {
    expect(courseWeeksLabel([1, 3, 5, 7], 16), '第 1、3、5、7 周');
    expect(courseWeeksLabel([2, 4, 8, 9, 10, 11, 12], 16), '第 2、4、8–12 周');
    expect(courseWeeksLabel([10, 4, 5, 6, 7, 8, 9, 4], 16), '第 4–10 周');
    expect(courseWeeksLabel([1, 3, 5, 7, 9, 11, 13, 15], 16), '单周');
    expect(courseWeeksLabel([2, 4, 6, 8, 10, 12, 14, 16], 16), '双周');
    expect(courseWeeksLabel([], 16), '每周');
    expect(courseCreditLabel('3'), '3.0');
    expect(courseCreditLabel('4.0'), '4.0');
    expect(courseCreditLabel('1.25'), '1.25');
    expect(courseCreditLabel(''), '');
    expect(courseCreditLabel('NaN'), '');
  });

  test(
    'new settings survive copy, export, restart and old documents',
    () async {
      final store = ScheduleStore();
      await store.load();
      final doc = await store.create('test');
      await store.update(
        doc.copyWith(
          showCredit: true,
          courseWeekDisplay: CourseWeekDisplay.otherWeeks,
        ),
      );
      final copy = await store.duplicate(doc.id);
      expect(copy.showCredit, true);
      final imported = ScheduleCodec.decode(ScheduleCodec.encode(copy));
      expect(imported.courseWeekDisplay, CourseWeekDisplay.otherWeeks);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.showCredit, true);
      final old = copy.toJson()
        ..remove('showCredit')
        ..remove('courseWeekDisplay');
      expect(
        ScheduleDocument.fromJson(old).courseWeekDisplay,
        CourseWeekDisplay.none,
      );
      expect(ScheduleDocument.fromJson(old).showCredit, false);
      expect(
        () =>
            ScheduleDocument.fromJson({...old, 'courseWeekDisplay': 'invalid'}),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    '35px horizontal drag changes week and dates; double tap restores them',
    (tester) async {
      await launch(tester);
      final dates = find.byKey(const ValueKey('displayed-week-dates'));
      final original = tester.widget<Text>(dates).data;
      final finger = await tester.startGesture(const Offset(300, 350));
      await finger.moveBy(const Offset(-35, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await finger.up();
      await tester.pumpAndSettle();
      expect(find.text('第 2 周'), findsOneWidget);
      expect(find.text('（非本周）'), findsOneWidget);
      expect(tester.widget<Text>(dates).data, isNot(original));
      final label = find.byKey(const ValueKey('week-selector'));
      await tester.tap(label);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text('（本周）'), findsOneWidget);
      expect(tester.widget<Text>(dates).data, original);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('month follows Monday across a month boundary', (tester) async {
    final store = await launch(tester);
    await tester.pumpWidget(const SizedBox());
    await store.update(
      store.active.copyWith(firstWeekStart: DateTime(2026, 9, 28)),
    );
    await tester.pumpWidget(QingScheduleApp(store: store));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('week-month'))).data,
      '九月',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('displayed-week-dates')))
          .data,
      '2026/9/28 – 10/4',
    );
    await tester.drag(
      find.byKey(const ValueKey('schedule-gestures')),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('week-month'))).data,
      '十月',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('week modes and credit apply per course, even in short cards', (
    tester,
  ) async {
    final store = await launch(tester, settings: true);
    final sessions = [
      CourseSession.fromJson({
        ...course('active', '数学', [1]).toJson(),
        'credit': '3',
        'endSection': 1,
        'sections': [1],
      }),
      CourseSession.fromJson({
        ...course('inactive', '物理', [4, 5, 6, 7, 8, 9, 10], day: 2).toJson(),
        'credit': '4',
      }),
    ];
    Future<void> render(CourseWeekDisplay mode, bool other, bool credit) async {
      await tester.pumpWidget(const SizedBox());
      await store.update(
        store.active.copyWith(
          schedule: store.active.schedule.copyWith(sessions: sessions),
          showOtherWeeks: other,
          courseWeekDisplay: mode,
          showCredit: credit,
          showTeacher: true,
          showCourseCode: true,
        ),
      );
      await tester.pumpWidget(QingScheduleApp(store: store));
      await tester.pumpAndSettle();
    }

    List<String> metadata(String id) => tester
        .widget<AdaptiveCourseText>(
          find.descendant(
            of: find.byKey(ValueKey('course-$id')),
            matching: find.byType(AdaptiveCourseText),
          ),
        )
        .metadata;
    await render(CourseWeekDisplay.all, true, true);
    expect(metadata('active'), containsAll(['第 1 周', '3.0']));
    expect(metadata('inactive'), containsAll(['第 4–10 周', '4.0']));
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await render(CourseWeekDisplay.otherWeeks, true, false);
    expect(metadata('active'), isNot(contains('第 1 周')));
    expect(metadata('inactive'), contains('第 4–10 周'));
    expect(metadata('active'), isNot(contains('3.0')));
    await render(CourseWeekDisplay.otherWeeks, false, true);
    expect(find.byKey(const ValueKey('course-inactive')), findsNothing);
    await render(CourseWeekDisplay.none, true, false);
    expect(metadata('inactive'), isNot(contains('第 4–10 周')));
    expect(store.active.schedule.sessions.first.credit, '3');
    expect(store.active.schedule.sessions.last.weeks, [4, 5, 6, 7, 8, 9, 10]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'popup background previews live, stays opaque text and persists',
    (tester) async {
      final store = await launch(tester);
      await displaySettings(tester);
      final slider = find.byKey(const ValueKey('popup-transparency'));
      await tester.ensureVisible(slider);
      final control = tester.widget<Slider>(slider);
      control.onChanged!(.4);
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(slider));
      expect(theme.bottomSheetTheme.backgroundColor!.a, closeTo(.6, .01));
      expect(theme.dialogTheme.backgroundColor!.a, closeTo(.6, .01));
      expect(theme.textTheme.bodyMedium!.color!.a, 1);
      control.onChangeEnd!(.4);
      await tester.pumpAndSettle();
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.appearance.popupOpacity, closeTo(.6, .001));
      expect(store.appearance.popupOpacity, closeTo(.6, .001));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('font theme reaches app bars, dialogs, Cupertino and normal text', () {
    final theme = ShuYoThemes.byId(
      ShuYoThemes.defaultId,
    ).themeData(deviceFonts: ['deviceLatin', 'deviceHan']);
    for (final style in [
      theme.textTheme.bodyMedium!,
      theme.appBarTheme.titleTextStyle!,
      theme.dialogTheme.titleTextStyle!,
      theme.dialogTheme.contentTextStyle!,
      theme.cupertinoOverrideTheme!.textTheme!.textStyle,
      theme.cupertinoOverrideTheme!.textTheme!.pickerTextStyle,
    ]) {
      expect(style.fontFamily, 'deviceLatin');
      expect(style.fontFamilyFallback, contains('deviceHan'));
    }
    expect(
      ShuYoThemes.byId(ShuYoThemes.defaultId)
          .themeData(useSystemFont: false, deviceFonts: ['device'])
          .textTheme
          .bodyMedium!
          .fontFamily,
      'QingSans',
    );
  });

  testWidgets(
    'native font refresh runs on resume, disabled switch stops reading',
    (tester) async {
      var reads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceFontService.channel, (call) async {
            reads++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceFontService.channel, null),
      );
      final service = DeviceFontService()..enabled = true;
      service.start();
      await service.refresh();
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(reads, 2);
      service.enabled = false;
      await service.refresh();
      expect(reads, 2);
      service.dispose();
    },
  );

  test('TTC selected face uses corrected offsets and whole-font checksum', () {
    final bytes = Uint8List(72);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 0x74746366);
    data.setUint32(8, 2);
    data.setUint32(12, 20);
    data.setUint32(16, 32);
    data.setUint32(32, 0x00010000);
    data.setUint16(36, 1);
    data.setUint32(44, 0x68656164);
    data.setUint32(52, 60);
    data.setUint32(56, 12);
    final result = extractFontFace((bytes, 1));
    final font = ByteData.sublistView(result);
    expect(font.getUint32(0), 0x00010000);
    expect(font.getUint32(20), 28);
    var checksum = 0;
    for (var i = 0; i < result.length; i += 4) {
      checksum = (checksum + font.getUint32(i)) & 0xffffffff;
    }
    expect(checksum, 0xb1b0afba);
    expect(() => extractFontFace((bytes, 2)), throwsFormatException);
    data.setUint32(56, 1000);
    expect(() => extractFontFace((bytes, 1)), throwsFormatException);
  });
}
