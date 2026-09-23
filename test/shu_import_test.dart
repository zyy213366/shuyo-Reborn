import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_schedule/services/shu_import_script.dart';

void main() {
  test('only exact official timetable origins can extract', () {
    expect(
      ShuImport.isTimetableUrl('https://jwxt.shu.edu.cn/jwglxt/test'),
      isTrue,
    );
    expect(
      ShuImport.isTimetableUrl(
        'https://https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn/jwglxt/',
      ),
      isTrue,
    );
    expect(
      ShuImport.isTimetableUrl('https://jwxt.shu.edu.cn.evil.test/'),
      isFalse,
    );
    expect(ShuImport.isTimetableUrl('http://jwxt.shu.edu.cn/'), isFalse);
    expect(ShuImport.isTimetableUrl('https://newsso.shu.edu.cn/'), isFalse);
  });
  test('real upstream anonymized response parses and strips identity', () {
    final raw = File('test/fixtures/shu_schedule.json').readAsStringSync();
    final schedule = ShuImport.parse(raw);
    expect(schedule.sessions, isNotEmpty);
    expect(schedule.term.studentId, isEmpty);
    expect(schedule.term.studentName, isEmpty);
    expect(
      schedule.sessions.every((s) => s.weekday >= 1 && s.weekday <= 7),
      isTrue,
    );
  });
  test(
    'login HTML and incomplete responses cannot become an empty timetable',
    () {
      expect(() => ShuImport.parse('<html>登录</html>'), throwsFormatException);
      expect(() => ShuImport.parse('{}'), throwsFormatException);
      expect(
        () => ShuImport.parse(jsonEncode({'error': '请先登录'})),
        throwsFormatException,
      );
    },
  );
}
