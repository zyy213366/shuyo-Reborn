import 'package:flutter/material.dart';
import '../../data/schedule_comparison.dart';
import '../../data/schedule_document.dart';
import '../schedule_comparison_page.dart';

/// Actual clock minutes keep different schools' section times comparable.
class ComparisonWeekGrid extends StatelessWidget {
  ComparisonWeekGrid({
    super.key,
    required this.documents,
    required this.monday,
    required this.mode,
    required this.days,
    required this.firstDay,
  }) {
    entries = [
      for (final doc in documents)
        ...ScheduleComparison.occurrences(doc, monday),
    ];
    commonIds = {
      for (final course in ScheduleComparison.common(documents, monday))
        for (final e in course.occurrences) (e.document.id, e.session.id),
    };
    final ranges = entries.expand((e) => e.ranges).toList();
    start = ranges.fold(480, (v, r) => r.start < v ? r.start : v) ~/ 60 * 60;
    end =
        ((ranges.fold(1320, (v, r) => r.end > v ? r.end : v) + 59) ~/ 60) * 60;
  }
  final List<ScheduleDocument> documents;
  final DateTime monday;
  final TimetableComparisonMode mode;
  final double days;
  final int firstDay;
  late final List<CourseOccurrence> entries;
  late final Set<(String, String)> commonIds;
  late final int start, end;

  void _details(BuildContext context, List<CourseOccurrence> courses) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .5,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              for (final e in courses)
                ListTile(
                  title: Text(e.session.courseName),
                  subtitle: Text(
                    [
                      e.document.name,
                      '${e.date.month}/${e.date.day} ${e.ranges.map((r) => r.label).join('、')}',
                      e.session.location,
                      e.session.teacherName,
                      e.session.note,
                    ].where((s) => s.isNotEmpty).join('\n'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 42) / days;
        const header = 48.0;
        const scale = 1.0;
        return SingleChildScrollView(
          child: SizedBox(
            key: const ValueKey('comparison-grid'),
            height: header + (end - start) * scale,
            child: ClipRect(
              child: Stack(
                children: [
                  for (var minute = start; minute <= end; minute += 60) ...[
                    Positioned(
                      left: 0,
                      top: header + (minute - start) * scale,
                      width: 40,
                      child: Text(
                        MinuteRange.clock(minute),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Positioned(
                      left: 42,
                      right: 0,
                      top: header + (minute - start) * scale,
                      child: Divider(height: 1, color: colors.outlineVariant),
                    ),
                  ],
                  for (var day = firstDay; day <= 7; day++) ...[
                    Positioned(
                      left: 42 + (day - firstDay) * width,
                      top: 0,
                      width: width,
                      child: Text(
                        '周${['一', '二', '三', '四', '五', '六', '日'][day - 1]}\n${DateTime(monday.year, monday.month, monday.day + day - 1).month}/${DateTime(monday.year, monday.month, monday.day + day - 1).day}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (mode == TimetableComparisonMode.commonFree)
                      for (final range in ScheduleComparison.merge([
                        for (final e in entries)
                          if (e.date.weekday == day) ...e.ranges,
                      ]))
                        Positioned(
                          left: 42 + (day - firstDay) * width + 2,
                          top: header + (range.start - start) * scale,
                          width: width - 4,
                          height: (range.end - range.start) * scale,
                          child: Material(
                            key: ValueKey(
                              'comparison-busy-$day-${range.start}',
                            ),
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              onTap: () => _details(
                                context,
                                entries
                                    .where(
                                      (e) =>
                                          e.date.weekday == day &&
                                          e.ranges.any(
                                            (r) =>
                                                r.start < range.end &&
                                                r.end > range.start,
                                          ),
                                    )
                                    .toList(),
                              ),
                              child: Center(
                                child: Text(
                                  '占用',
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    if (mode == TimetableComparisonMode.commonCourses)
                      for (var owner = 0; owner < documents.length; owner++)
                        for (final e in entries.where(
                          (e) =>
                              e.date.weekday == day &&
                              e.document.id == documents[owner].id,
                        ))
                          for (final range in e.ranges)
                            Positioned(
                              left:
                                  42 +
                                  (day - firstDay) * width +
                                  owner * width / documents.length +
                                  1,
                              top: header + (range.start - start) * scale,
                              width: width / documents.length - 2,
                              height: (range.end - range.start) * scale,
                              child: Opacity(
                                key: ValueKey(
                                  'comparison-course-${e.document.id}-${e.session.id}-${range.start}',
                                ),
                                opacity:
                                    commonIds.contains((
                                      e.document.id,
                                      e.session.id,
                                    ))
                                    ? 1
                                    : .25,
                                child: Material(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                  child: InkWell(
                                    onTap: () => _details(context, [e]),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Text(
                                        e.session.courseName,
                                        overflow: TextOverflow.fade,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
