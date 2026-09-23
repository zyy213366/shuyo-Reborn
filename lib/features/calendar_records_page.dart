import 'package:flutter/material.dart';
import '../data/schedule_store.dart';
import '../data/schedule_comparison.dart';
import '../services/shu_exam_import.dart';
import 'school_import.dart';
import 'exam_week_view.dart';

class CalendarRecordsPage extends StatelessWidget {
  const CalendarRecordsPage({
    super.key,
    required this.store,
    required this.documentId,
    required this.exams,
  });
  final ScheduleStore store;
  final String documentId;
  final bool exams;

  Future<void> _edit(
    BuildContext context, {
    ExamRecord? exam,
    ScheduleAdjustment? rule,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _RecordEditor(
        store: store,
        documentId: documentId,
        exams: exams,
        exam: exam,
        rule: rule,
      ),
    ),
  );

  Future<void> _import(BuildContext context) async {
    final incoming = await Navigator.of(context).push<List<ExamRecord>>(
      MaterialPageRoute(builder: (_) => const SchoolImportPage(exams: true)),
    );
    if (incoming == null || incoming.isEmpty) return;
    try {
      await store.mutate(
        documentId,
        (doc) => doc.copyWith(exams: ShuExamImport.merge(doc.exams, incoming)),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入或更新 ${incoming.length} 场考试')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('考试保存失败，原安排已保留，请重试')));
      }
    }
  }

  Future<void> _delete(
    BuildContext context, {
    ExamRecord? exam,
    ScheduleAdjustment? rule,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(exams ? '删除这场考试？' : '删除这条调休？'),
        content: Text(
          exams
              ? exam!.courseName
              : '${calendarDateText(rule!.date)} 将恢复原本的课程安排。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.mutate(
        documentId,
        (doc) => exams
            ? doc.copyWith(
                exams: doc.exams.where((e) => e.id != exam!.id).toList(),
              )
            : doc.copyWith(
                adjustments: doc.adjustments
                    .where((r) => r.date != rule!.date)
                    .toList(),
              ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除未保存，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final doc = store.byId(documentId);
      return Scaffold(
        appBar: AppBar(
          title: Text(exams ? '考试周' : '手动调休'),
          actions: [
            if (exams)
              IconButton(
                tooltip: '导入考试安排',
                onPressed: () => _import(context),
                icon: const Icon(Icons.file_download_outlined),
              ),
            IconButton(
              tooltip: exams ? '添加考试' : '添加调休',
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: exams
            ? ExamWeekView(
                key: ValueKey(Object.hashAll(doc.exams)),
                exams: doc.exams,
                onImport: () => _import(context),
                onEdit: (e) => _edit(context, exam: e),
                onDelete: (e) => _delete(context, exam: e),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    doc.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    exams
                        ? '考试按日期和开始时间排列，独立于普通课程。'
                        : '仅对这张课表的指定日期生效；课程对比也会使用调休后的安排。',
                  ),
                  const SizedBox(height: 16),
                  if (exams && doc.exams.isEmpty ||
                      !exams && doc.adjustments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        exams ? '还没有考试安排，点击右上角添加。' : '还没有调休记录，点击右上角添加。',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (exams)
                    for (final exam in doc.exams)
                      Card(
                        child: ListTile(
                          isThreeLine: true,
                          title: Text(exam.courseName),
                          subtitle: Text(
                            '${calendarDateText(exam.date)}  ${MinuteRange(exam.startMinute, exam.endMinute).label}\n'
                            '${exam.location.isEmpty ? '未填写考场' : exam.location}${exam.seat.isEmpty ? '' : ' · 座位 ${exam.seat}'}${exam.note.isEmpty ? '' : '\n${exam.note}'}',
                          ),
                          onTap: () => _edit(context, exam: exam),
                          trailing: IconButton(
                            tooltip: '删除考试',
                            onPressed: () => _delete(context, exam: exam),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      )
                  else
                    for (final rule in doc.adjustments)
                      Card(
                        child: ListTile(
                          title: Text(calendarDateText(rule.date)),
                          subtitle: Text(rule.label),
                          onTap: () => _edit(context, rule: rule),
                          trailing: IconButton(
                            tooltip: '删除调休',
                            onPressed: () => _delete(context, rule: rule),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                ],
              ),
      );
    },
  );
}

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({
    required this.store,
    required this.documentId,
    required this.exams,
    this.exam,
    this.rule,
  });
  final ScheduleStore store;
  final String documentId;
  final bool exams;
  final ExamRecord? exam;
  final ScheduleAdjustment? rule;
  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.exam?.courseName ?? '');
  late final _location = TextEditingController(
    text: widget.exam?.location ?? '',
  );
  late final _seat = TextEditingController(text: widget.exam?.seat ?? '');
  late final _note = TextEditingController(text: widget.exam?.note ?? '');
  late final String _examId = widget.exam?.id ?? newScheduleId();
  late DateTime _date =
      widget.exam?.date ??
      widget.rule?.date ??
      DateUtils.dateOnly(DateTime.now());
  late int _start = widget.exam?.startMinute ?? 9 * 60;
  late int _end = widget.exam?.endMinute ?? 11 * 60;
  late int _week = widget.rule?.sourceWeek ?? 1;
  late int _weekday = widget.rule?.sourceWeekday ?? 1;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _seat.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.exams) {
        final record = ExamRecord(
          id: _examId,
          courseName: _name.text.trim(),
          date: _date,
          startMinute: _start,
          endMinute: _end,
          location: _location.text.trim(),
          seat: _seat.text.trim(),
          note: _note.text.trim(),
          details: widget.exam?.details ?? const {},
        );
        await widget.store.mutate(
          widget.documentId,
          (doc) => doc.copyWith(
            exams: [...doc.exams.where((e) => e.id != record.id), record],
          ),
        );
      } else {
        final record = ScheduleAdjustment(
          date: _date,
          sourceWeek: _week,
          sourceWeekday: _weekday,
        );
        await widget.store.mutate(widget.documentId, (doc) {
          final others = doc.adjustments
              .where((r) => r.date != widget.rule?.date)
              .toList();
          if (others.any((r) => r.date == record.date)) {
            throw const FormatException('该日期已有调休，请返回列表修改原记录');
          }
          return doc.copyWith(adjustments: [...others, record]);
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is FormatException
              ? error.message
              : '保存失败，请重试；填写内容已保留';
        });
      }
    }
  }

  Future<void> _pickTime(bool start) async {
    final minutes = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null && mounted) {
      setState(() {
        if (start) {
          _start = picked.hour * 60 + picked.minute;
        } else {
          _end = picked.hour * 60 + picked.minute;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWeek = widget.store.byId(widget.documentId).schedule.maxWeek;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.exams
                ? (widget.exam == null ? '添加考试' : '修改考试')
                : (widget.rule == null ? '添加调休' : '修改调休'),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const ValueKey('save-record'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '正在保存…' : '保存'),
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.exams && widget.exam != null) ...[
                  for (final entry in widget.exam!.details.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      subtitle: Text(entry.value),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      await CalendarRecordsPage(
                        store: widget.store,
                        documentId: widget.documentId,
                        exams: true,
                      )._delete(context, exam: widget.exam);
                      if (context.mounted &&
                          !widget.store
                              .byId(widget.documentId)
                              .exams
                              .any((e) => e.id == widget.exam!.id)) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除考试'),
                  ),
                ],
                if (widget.exams)
                  TextFormField(
                    key: const ValueKey('exam-name'),
                    controller: _name,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: '考试课程名称'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入课程名称' : null,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text(widget.exams ? '考试日期' : '实际调休日期'),
                  subtitle: Text(calendarDateText(_date)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100, 12, 31),
                    );
                    if (date != null && mounted) setState(() => _date = date);
                  },
                ),
                if (widget.exams) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开始时间'),
                    trailing: Text(MinuteRange.clock(_start)),
                    onTap: () => _pickTime(true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('结束时间'),
                    trailing: Text(MinuteRange.clock(_end)),
                    onTap: () => _pickTime(false),
                  ),
                  TextFormField(
                    key: const ValueKey('exam-location'),
                    controller: _location,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: '考试地点 / 考场'),
                  ),
                  TextFormField(
                    key: const ValueKey('exam-seat'),
                    controller: _seat,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: '座位号'),
                  ),
                  TextFormField(
                    key: const ValueKey('exam-note'),
                    controller: _note,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: '考试备注'),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('source-week'),
                    initialValue: _week,
                    decoration: const InputDecoration(labelText: '执行哪一教学周'),
                    items: [
                      for (
                        var week = 1;
                        week <= (maxWeek > _week ? maxWeek : _week);
                        week++
                      )
                        DropdownMenuItem(value: week, child: Text('第 $week 周')),
                    ],
                    onChanged: (v) => setState(() => _week = v!),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('source-weekday'),
                    initialValue: _weekday,
                    decoration: const InputDecoration(labelText: '执行星期几'),
                    items: [
                      for (var day = 1; day <= 7; day++)
                        DropdownMenuItem(
                          value: day,
                          child: Text('周${'一二三四五六日'[day - 1]}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _weekday = v!),
                  ),
                  const SizedBox(height: 20),
                  const Text('仅替换所选日期的课程显示，不移动或删除原始课程。'),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
