import 'package:flutter/material.dart';
import '../data/schedule_document.dart';
import '../data/schedule_comparison.dart';
import 'home/schedule_gesture_pager.dart';

class ExamWeekView extends StatefulWidget {
  const ExamWeekView({
    super.key,
    required this.exams,
    required this.onEdit,
    required this.onDelete,
    required this.onImport,
  });
  final List<ExamRecord> exams;
  final ValueChanged<ExamRecord> onEdit, onDelete;
  final VoidCallback onImport;
  @override
  State<ExamWeekView> createState() => _ExamWeekViewState();
}

class _ExamWeekViewState extends State<ExamWeekView> {
  late final DateTime _first = mondayOf(
    widget.exams.isEmpty ? DateTime.now() : widget.exams.first.date,
  );
  late final int _count = widget.exams.isEmpty
      ? 1
      : _week(widget.exams.last.date);
  late int _current = widget.exams.isEmpty
      ? 1
      : _week(
          widget.exams
              .firstWhere(
                (e) => !e.date.isBefore(DateUtils.dateOnly(DateTime.now())),
                orElse: () => widget.exams.last,
              )
              .date,
        );
  int _days = 7;
  final _cache = <(int, int, int), Widget>{};
  int _week(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
              .difference(DateTime.utc(_first.year, _first.month, _first.day))
              .inDays ~/
          7 +
      1;
  DateTime _monday(int week) =>
      DateTime(_first.year, _first.month, _first.day + (week - 1) * 7);
  @override
  Widget build(BuildContext context) {
    if (widget.exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('还没有考试安排'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('从 WebVPN 导入考试'),
            ),
          ],
        ),
      );
    }
    final monday = _monday(_current);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    return Column(
      children: [
        TextButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: monday,
              firstDate: _first,
              lastDate: DateTime(
                _first.year,
                _first.month,
                _first.day + _count * 7 - 1,
              ),
            );
            if (date != null && mounted) setState(() => _current = _week(date));
          },
          child: Text(
            '${calendarDateText(monday)} — ${calendarDateText(sunday)}',
          ),
        ),
        const Text('点击考试查看或修改，左右滑动切换考试周'),
        Expanded(
          child: ScheduleGesturePager(
            week: _current,
            maxWeek: _count,
            visibleDays: _days,
            onWeekChanged: (v) => setState(() {
              _current = v;
              _cache.removeWhere((k, _) => (k.$1 - v).abs() > 2);
            }),
            onVisibleDaysChanged: (v) => setState(() {
              _days = v;
              _cache.clear();
            }),
            builder: (context, week, days, firstDay) {
              Widget build() => RepaintBoundary(
                child: _ExamGrid(
                  exams: widget.exams,
                  monday: _monday(week),
                  days: days,
                  firstDay: firstDay,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                ),
              );
              if (days != 5 && days != 7) return build();
              return _cache.putIfAbsent((week, days.toInt(), firstDay), build);
            },
          ),
        ),
      ],
    );
  }
}

class _ExamGrid extends StatelessWidget {
  const _ExamGrid({
    required this.exams,
    required this.monday,
    required this.days,
    required this.firstDay,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ExamRecord> exams;
  final DateTime monday;
  final double days;
  final int firstDay;
  final ValueChanged<ExamRecord> onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final endDate = DateTime(monday.year, monday.month, monday.day + 7);
    final entries = exams
        .where((e) => !e.date.isBefore(monday) && e.date.isBefore(endDate))
        .toList();
    final start =
        entries.fold(480, (v, e) => e.startMinute < v ? e.startMinute : v) ~/
        60 *
        60;
    final end =
        ((entries.fold(1320, (v, e) => e.endMinute > v ? e.endMinute : v) +
                59) ~/
            60) *
        60;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 42) / days;
        return SingleChildScrollView(
          child: SizedBox(
            key: const ValueKey('exam-week-grid'),
            height: 48.0 + end - start,
            child: ClipRect(
              child: Stack(
                children: [
                  for (var minute = start; minute <= end; minute += 60) ...[
                    Positioned(
                      left: 0,
                      top: 48.0 + minute - start,
                      width: 40,
                      child: Text(
                        MinuteRange.clock(minute),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Positioned(
                      left: 42,
                      right: 0,
                      top: 48.0 + minute - start,
                      child: Divider(height: 1, color: colors.outlineVariant),
                    ),
                  ],
                  for (var day = firstDay; day <= 7; day++) ...[
                    Positioned(
                      left: 42 + (day - firstDay) * width,
                      top: 0,
                      width: width,
                      child: Text(
                        '周${'一二三四五六日'[day - 1]}\n${DateTime(monday.year, monday.month, monday.day + day - 1).month}/${DateTime(monday.year, monday.month, monday.day + day - 1).day}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    for (final slot in _lanes(
                      entries.where((e) => e.date.weekday == day).toList(),
                    ))
                      _block(
                        context,
                        slot.$1,
                        slot.$2,
                        slot.$3,
                        42 + (day - firstDay) * width,
                        width,
                        start,
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

  List<(ExamRecord, int, int)> _lanes(List<ExamRecord> entries) {
    entries.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final result = <(ExamRecord, int, int)>[];
    final group = <(ExamRecord, int)>[];
    final ends = <int>[];
    void flush() {
      result.addAll(group.map((e) => (e.$1, e.$2, ends.length)));
      group.clear();
      ends.clear();
    }

    for (final e in entries) {
      if (ends.isNotEmpty && ends.every((end) => end <= e.startMinute)) flush();
      var lane = ends.indexWhere((end) => end <= e.startMinute);
      if (lane < 0) {
        lane = ends.length;
        ends.add(e.endMinute);
      } else {
        ends[lane] = e.endMinute;
      }
      group.add((e, lane));
    }
    flush();
    return result;
  }

  Widget _block(
    BuildContext context,
    ExamRecord e,
    int lane,
    int columns,
    double left,
    double width,
    int start,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      left: left + lane * width / columns + 1,
      top: 48.0 + e.startMinute - start,
      width: (width / columns - 2).clamp(1.0, double.infinity),
      height: (e.endMinute - e.startMinute).toDouble(),
      child: Material(
        key: ValueKey('exam-block-${e.id}'),
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: () => onEdit(e),
          onLongPress: () => onDelete(e),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    e.courseName,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                Text(
                  '${MinuteRange.clock(e.startMinute)}\n${e.location}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
