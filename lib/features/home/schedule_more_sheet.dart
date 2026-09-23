import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/schedule_store.dart';

/// The wheel stays mounted while switching the page underneath this route.
class ScheduleMoreSheet extends StatefulWidget {
  const ScheduleMoreSheet({
    super.key,
    required this.store,
    required this.onChanged,
  });
  final ScheduleStore store;
  final VoidCallback onChanged;

  @override
  State<ScheduleMoreSheet> createState() => _ScheduleMoreSheetState();
}

class _ScheduleMoreSheetState extends State<ScheduleMoreSheet> {
  late final FixedExtentScrollController _wheel;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _wheel = FixedExtentScrollController(
      initialItem: widget.store.documents.indexWhere(
        (d) => d.id == widget.store.active.id,
      ),
    );
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        _error = '保存失败，请重试';
        _wheel.jumpToItem(
          widget.store.documents.indexWhere(
            (d) => d.id == widget.store.active.id,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.store.active;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '切换课表',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'manage'),
                  child: const Text('管理课表'),
                ),
              ],
            ),
            AbsorbPointer(
              absorbing: _saving,
              child: SizedBox(
                height: 144,
                child: CupertinoPicker(
                  key: const ValueKey('schedule-wheel'),
                  scrollController: _wheel,
                  itemExtent: 44,
                  magnification: 1.08,
                  useMagnifier: true,
                  changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
                  onSelectedItemChanged: (index) {
                    final id = widget.store.documents[index].id;
                    if (id != widget.store.active.id) {
                      _save(() => widget.store.select(id));
                    }
                  },
                  children: [
                    for (final d in widget.store.documents)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: d.id == doc.id
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(),
            for (final item in <(String, String, IconData)>[
              ('compare', '课表对比', Icons.compare_arrows),
              ('exams', '考试周', Icons.assignment_outlined),
              ('adjustments', '手动调休', Icons.event_repeat),
              ('add', '添加课程', Icons.add),
              ('date', '开学日期', Icons.edit_calendar_outlined),
              ('times', '作息时间', Icons.schedule),
              ('display', '显示设置', Icons.palette_outlined),
              ('licenses', '开源许可', Icons.info_outline),
            ])
              ListTile(
                leading: Icon(item.$3),
                title: Text(item.$2),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
  }
}
