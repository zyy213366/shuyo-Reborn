import 'package:flutter/material.dart';
import '../data/schedule_store.dart';

class ImportPreviewPage extends StatefulWidget {
  const ImportPreviewPage({
    super.key,
    required this.store,
    required this.source,
    this.fromSchool = false,
  });
  final ScheduleStore store;
  final ScheduleDocument source;
  final bool fromSchool;
  @override
  State<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<ImportPreviewPage> {
  late final _name = TextEditingController(text: widget.source.name);
  late DateTime _date = widget.source.firstWeekStart;
  final _form = GlobalKey<FormState>();
  String _target = 'new';
  bool _saving = false;
  bool _acceptConflicts = false;
  String? _saveError;
  ScheduleDocument get _source =>
      widget.source.copyWith(name: _name.text.trim(), firstWeekStart: _date);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (_target == 'new') {
        await widget.store.addImported(_source);
      } else {
        await widget.store.mutate(_target, (target) {
          final merge = ScheduleMerge.preview(target, _source);
          if (merge.conflicts.isNotEmpty && !_acceptConflicts) {
            throw const FormatException('请确认保留时间重叠的课程');
          }
          return merge.document;
        }, selectAfter: true);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saveError = error is FormatException
              ? error.message
              : error.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ScheduleMerge? merge;
    String? mergeError;
    if (_target != 'new') {
      try {
        merge = ScheduleMerge.preview(widget.store.byId(_target), _source);
      } on FormatException catch (error) {
        mergeError = error.message;
      }
    }
    final canSave =
        mergeError == null &&
        (merge == null || merge.conflicts.isEmpty || _acceptConflicts);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('导入预览')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.source.schedule.sessions.length} 个课程时段 · ${widget.source.schedule.untimedCourses.length} 门未排时课程',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                _target == 'new'
                    ? '${widget.source.exams.length} 场考试 · ${widget.source.adjustments.length} 条调休将随新课表导入'
                    : '合并仅添加课程，保留目标课表的考试和调休；需要完整导入请选择新建独立课表。',
              ),
              DropdownButtonFormField<String>(
                initialValue: _target,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '导入到'),
                items: [
                  const DropdownMenuItem(value: 'new', child: Text('新建独立课表')),
                  for (final doc in widget.store.documents)
                    DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        '合并到 ${doc.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _target = v!;
                        _acceptConflicts = false;
                      }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !_saving && _target == 'new',
                maxLength: 80,
                decoration: const InputDecoration(labelText: '课表名称'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? '请输入课表名称' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(
                  '第一周周一：${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
                subtitle: Text(
                  widget.fromSchool
                      ? '请核对本学期开学日期，周次将据此计算'
                      : '使用分享课表中的开学日期，可点此调整',
                ),
                onTap: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100, 12, 31),
                        );
                        if (picked != null) {
                          setState(() {
                            _date = mondayOf(picked);
                            _acceptConflicts = false;
                          });
                        }
                      },
              ),
              if (mergeError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    mergeError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (merge != null) ...[
                Text('新增 ${merge.added} 项，跳过 ${merge.duplicates} 项重复课程'),
                if (merge.conflicts.isNotEmpty) ...[
                  ExpansionTile(
                    title: Text('${merge.conflicts.length} 处时间重叠'),
                    children: [
                      for (final conflict in merge.conflicts)
                        ListTile(dense: true, title: Text(conflict)),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptConflicts,
                    title: const Text('我已核对，保留重叠课程'),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _acceptConflicts = v!),
                  ),
                ],
              ],
              const Divider(),
              for (final s in widget.source.schedule.sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.courseName),
                  subtitle: Text(
                    '周${'一二三四五六日'[s.weekday - 1]} · ${s.sectionText} · ${s.weekText}\n${s.location} ${s.teacherName}',
                  ),
                ),
              for (final s in widget.source.schedule.untimedCourses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.courseName),
                  subtitle: Text('未排时间 · ${s.summary}'),
                ),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving || !canSave ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? '正在保存' : '确认导入'),
          ),
        ),
      ),
    );
  }
}
