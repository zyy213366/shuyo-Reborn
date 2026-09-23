String calendarDateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime calendarDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('日期格式应为 YYYY-MM-DD');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.year < 2000 ||
      parsed.year > 2100 ||
      calendarDateText(parsed) != value) {
    throw const FormatException('日期无效');
  }
  return parsed;
}

String _text(
  Map<String, dynamic> data,
  String key,
  int max, {
  bool required = false,
}) {
  final value = data[key];
  if (value is! String ||
      value.length > max ||
      (required && value.trim().isEmpty)) {
    throw const FormatException('考试信息不完整或过长');
  }
  return value;
}

class ExamRecord {
  ExamRecord({
    required this.id,
    required this.courseName,
    required DateTime date,
    required this.startMinute,
    required this.endMinute,
    this.location = '',
    this.seat = '',
    this.note = '',
    Map<String, String> details = const {},
  }) : details = Map.unmodifiable(details),
       date = calendarDate(calendarDateText(date)) {
    _text(toJson(), 'id', 160, required: true);
    _text(toJson(), 'courseName', 200, required: true);
    _text(toJson(), 'location', 500);
    _text(toJson(), 'seat', 80);
    _text(toJson(), 'note', 2000);
    if (details.length > 20 ||
        details.entries.any(
          (e) => e.key.length > 80 || e.value.length > 1000,
        )) {
      throw const FormatException('考试附加信息过长');
    }
    if (startMinute < 0 || endMinute >= 1440 || startMinute >= endMinute) {
      throw const FormatException('考试结束时间必须晚于开始时间，且在同一天内');
    }
  }
  final String id, courseName, location, seat, note;
  final Map<String, String> details;
  final DateTime date;
  final int startMinute, endMinute;
  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'date': calendarDateText(date),
    'startMinute': startMinute,
    'endMinute': endMinute,
    'location': location,
    'seat': seat,
    'note': note,
    if (details.isNotEmpty) 'details': details,
  };
  factory ExamRecord.fromJson(Map<String, dynamic> json) {
    if (json['startMinute'] is! int || json['endMinute'] is! int) {
      throw const FormatException('考试时间无效');
    }
    return ExamRecord(
      id: _text(json, 'id', 160, required: true),
      courseName: _text(json, 'courseName', 200, required: true),
      date: calendarDate(json['date']),
      startMinute: json['startMinute'] as int,
      endMinute: json['endMinute'] as int,
      location: _text(json, 'location', 500),
      seat: _text(json, 'seat', 80),
      note: _text(json, 'note', 2000),
      details: _examDetails(json['details']),
    );
  }
}

Map<String, String> _examDetails(Object? value) {
  if (value == null) return {};
  if (value is! Map ||
      value.length > 20 ||
      value.entries.any((e) => e.key is! String || e.value is! String)) {
    throw const FormatException('考试附加信息格式无效');
  }
  return Map<String, String>.from(value);
}

class ScheduleAdjustment {
  ScheduleAdjustment({
    required DateTime date,
    required this.sourceWeek,
    required this.sourceWeekday,
  }) : date = calendarDate(calendarDateText(date)) {
    if (sourceWeek < 1 ||
        sourceWeek > 32 ||
        sourceWeekday < 1 ||
        sourceWeekday > 7) {
      throw const FormatException('请选择有效教学周和星期');
    }
  }
  final DateTime date;
  final int sourceWeek, sourceWeekday;
  String get label => '按第 $sourceWeek 周周${'一二三四五六日'[sourceWeekday - 1]}执行';
  Map<String, dynamic> toJson() => {
    'date': calendarDateText(date),
    'sourceWeek': sourceWeek,
    'sourceWeekday': sourceWeekday,
  };
  factory ScheduleAdjustment.fromJson(Map<String, dynamic> json) {
    if (json['sourceWeek'] is! int || json['sourceWeekday'] is! int) {
      throw const FormatException('调休规则无效');
    }
    return ScheduleAdjustment(
      date: calendarDate(json['date']),
      sourceWeek: json['sourceWeek'] as int,
      sourceWeekday: json['sourceWeekday'] as int,
    );
  }
}

List<T> readCalendarRecords<T>(
  Object? raw,
  T Function(Map<String, dynamic>) parse,
) {
  if (raw == null) return [];
  if (raw is! List || raw.length > 1000) {
    throw const FormatException('日程记录格式错误或超过 1000 条');
  }
  return raw.map((item) {
    if (item is! Map<String, dynamic>) throw const FormatException('日程记录格式错误');
    return parse(item);
  }).toList();
}
