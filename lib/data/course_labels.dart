enum CourseWeekDisplay { all, otherWeeks, none }

bool showCourseWeeks(CourseWeekDisplay mode, bool occurs) =>
    mode == CourseWeekDisplay.all ||
    (mode == CourseWeekDisplay.otherWeeks && !occurs);

String courseWeeksLabel(List<int> weeks, int maxWeek) {
  final sorted = weeks.toSet().toList()..sort();
  if (sorted.isEmpty) return '每周';
  for (final parity in [1, 0]) {
    final expected = [
      for (var w = 1; w <= maxWeek; w++)
        if (w % 2 == parity) w,
    ];
    if (expected.length > 1 &&
        expected.length == sorted.length &&
        List.generate(
          sorted.length,
          (i) => sorted[i] == expected[i],
        ).every((v) => v)) {
      return parity == 1 ? '单周' : '双周';
    }
  }
  final parts = <String>[];
  for (var i = 0; i < sorted.length; i++) {
    final start = sorted[i];
    var end = start;
    while (i + 1 < sorted.length && sorted[i + 1] == end + 1) {
      end = sorted[++i];
    }
    parts.add(start == end ? '$start' : '$start–$end');
  }
  return '第 ${parts.join('、')} 周';
}

String courseCreditLabel(String credit) {
  final value = double.tryParse(credit.trim());
  if (value == null || !value.isFinite || value < 0) return '';
  return value == value.truncateToDouble()
      ? value.toStringAsFixed(1)
      : '$value';
}
