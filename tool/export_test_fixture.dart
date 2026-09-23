import 'dart:convert';
import 'dart:io';
import 'package:qing_schedule/data/models/academic_schedule.dart';
import 'package:qing_schedule/data/schedule_document.dart';
import 'package:qing_schedule/services/shu_import_script.dart';

void main() {
  final raw = File('test/fixtures/shu_schedule.json').readAsStringSync();
  final schedule = AcademicScheduleParser.parse(
    jsonDecode(raw) as Map<String, dynamic>,
  );
  final doc = ScheduleDocument(
    id: 'fixture',
    name: '2026 秋季 · 示例课表',
    schedule: schedule,
    colorful: true,
    firstWeekStart: DateTime(2026, 9, 14),
  );
  File(
    '.tools/demo.shuyoschedule.json',
  ).writeAsStringSync(ScheduleCodec.encode(doc));
  File(
    '.tools/shu_extract.js',
  ).writeAsStringSync(ShuImport.extractionScript('test_result'));
}
