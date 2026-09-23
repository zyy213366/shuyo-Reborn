import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qing_schedule/services/shu_exam_import.dart';
import 'package:qing_schedule/data/calendar_records.dart';

void main() {
  final raw = File('test/fixtures/shu_exams.json').readAsStringSync();
  test(
    'actual exam response maps exam time not teaching time; metadata survives JSON',
    () {
      final exams = ShuExamImport.parse(raw);
      expect(exams.length, 10);
      final e = exams.firstWhere((e) => e.courseName == '计算机组成原理A(2)');
      expect(e.date, DateTime(2026, 7, 3));
      expect(e.startMinute, 780);
      expect(e.endMinute, 900);
      expect(e.location, '宝山主区 AJ304');
      expect(e.seat, '');
      expect(e.details['考试名称'], '2025-2026春季期末考试');
      expect(ExamRecord.fromJson(e.toJson()).details, e.details);
      expect(e.toJson().toString(), isNot(contains('xh_id')));
    },
  );
  test(
    'reimport updates source identity without duplicating or removing manual entries',
    () {
      final exams = ShuExamImport.parse(raw);
      final manual = ExamRecord(
        id: 'manual',
        courseName: '自定义',
        date: DateTime(2026, 1, 1),
        startMinute: 480,
        endMinute: 540,
      );
      final changed = jsonDecode(raw) as Map<String, dynamic>;
      changed['items'][0]['kssj'] = '2026-07-04(09:00-11:00)';
      final merged = ShuExamImport.merge([
        manual,
        ...exams,
      ], ShuExamImport.parse(jsonEncode(changed)));
      expect(merged.length, 11);
      expect(
        merged.firstWhere((e) => e.id == exams.first.id).date,
        DateTime(2026, 7, 4),
      );
      expect(merged.any((e) => e.id == 'manual'), isTrue);
    },
  );
  test(
    'incomplete pages, malformed time and login HTML cannot overwrite exams',
    () {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      value['totalResult'] = 11;
      expect(
        () => ShuExamImport.parse(jsonEncode(value)),
        throwsFormatException,
      );
      value['totalResult'] = 10;
      value['items'][0]['kssj'] = '2026-07-03(25:00-26:00)';
      expect(
        () => ShuExamImport.parse(jsonEncode(value)),
        throwsFormatException,
      );
      expect(
        () => ShuExamImport.parse('<html>登录</html>'),
        throwsFormatException,
      );
    },
  );
}
