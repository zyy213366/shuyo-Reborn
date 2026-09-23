import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/data/schedule_store.dart';

AcademicSchedule fixture() => AcademicScheduleParser.parse(
  jsonDecode(File('test/fixtures/shu_schedule.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'copies are independent and survive restart with selected schedule',
    () async {
      final store = ScheduleStore();
      await store.load();
      final original = await store.create('我的课表', schedule: fixture());
      final copy = await store.duplicate(original.id);
      await store.update(
        copy.copyWith(
          name: '朋友课表',
          schedule: copy.schedule.copyWith(sessions: []),
        ),
      );
      expect(store.byId(original.id).schedule.sessions, isNotEmpty);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.active.id, copy.id);
      expect(restarted.active.name, '朋友课表');
      expect(restarted.active.schedule.sessions, isEmpty);
      expect(restarted.byId(original.id).schedule.sessions, isNotEmpty);
    },
  );

  test(
    'share round trip preserves dates and colors but strips student identity',
    () async {
      final store = ScheduleStore();
      await store.load();
      final doc = await store.create(
        '秋季',
        schedule: fixture(),
        firstWeekStart: DateTime(2026, 9, 7),
      );
      final colored = doc.copyWith(
        colors: {'math': 0xff445566},
        colorful: true,
      );
      final encoded = ScheduleCodec.encode(colored);
      expect(encoded, isNot(contains('DEMO0001')));
      expect(encoded, isNot(contains('演示同学')));
      final decoded = ScheduleCodec.decode(encoded);
      expect(decoded.schedule.sessions.length, doc.schedule.sessions.length);
      expect(decoded.firstWeekStart, DateTime(2026, 9, 7));
      expect(decoded.colors['math'], 0xff445566);
      expect(decoded.colorful, isTrue);
      expect(decoded.schedule.term.studentId, isEmpty);
    },
  );

  test(
    'bad versions, oversized input and invalid weekday are rejected',
    () async {
      final store = ScheduleStore();
      await store.load();
      final doc = await store.create('秋季', schedule: fixture());
      final data =
          jsonDecode(ScheduleCodec.encode(doc)) as Map<String, dynamic>;
      data['version'] = 999;
      expect(
        () => ScheduleCodec.decode(jsonEncode(data)),
        throwsFormatException,
      );
      data['version'] = 1;
      data['document']['schedule']['sessions'][0]['weekday'] = 8;
      expect(
        () => ScheduleCodec.decode(jsonEncode(data)),
        throwsFormatException,
      );
      expect(
        () => ScheduleCodec.decode('x' * (ScheduleCodec.maxBytes + 1)),
        throwsFormatException,
      );
      expect(store.documents.length, 1);
    },
  );

  test('merge skips repeated courses and reports overlaps', () async {
    final store = ScheduleStore();
    await store.load();
    final a = await store.create('A', schedule: fixture());
    final same = ScheduleCodec.decode(ScheduleCodec.encode(a));
    final preview = ScheduleMerge.preview(a, same);
    expect(preview.added, 0);
    expect(
      preview.duplicates,
      a.schedule.sessions.length + a.schedule.untimedCourses.length,
    );
    final raw = a.schedule.sessions.first.toJson();
    raw['courseName'] = '重叠的另一门课程';
    raw['id'] = 'incoming';
    final incoming = a.copyWith(
      schedule: a.schedule.copyWith(
        sessions: [CourseSession.fromJson(raw)],
        untimedCourses: [],
      ),
    );
    expect(ScheduleMerge.preview(a, incoming).conflicts, isNotEmpty);
    expect(
      ScheduleMerge.preview(a, incoming).document.schedule.sessions.length,
      a.schedule.sessions.length + 1,
    );
  });

  test('different term dates cannot silently merge', () async {
    final store = ScheduleStore();
    await store.load();
    final a = await store.create(
      'A',
      schedule: fixture(),
      firstWeekStart: DateTime(2026, 9, 7),
    );
    final b = a.copyWith(firstWeekStart: DateTime(2026, 9, 14));
    expect(() => ScheduleMerge.preview(a, b), throwsFormatException);
  });

  test(
    'parallel mutations are serialized and deletion always leaves a usable table',
    () async {
      final store = ScheduleStore();
      await store.load();
      await Future.wait(List.generate(6, (i) => store.create('课表 $i')));
      expect(store.documents.length, 6);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.documents.length, 6);
      for (final doc in List.of(store.documents)) {
        await store.delete(doc.id);
      }
      expect(store.documents.length, 1);
      expect(store.active.schedule.sessions, isEmpty);
    },
  );
}
