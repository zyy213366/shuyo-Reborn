import 'package:flutter/material.dart';
import '../data/schedule_store.dart';

enum TimetableComparisonMode { commonCourses, commonFree }

class TimetableComparisonSelection {
  TimetableComparisonSelection(Iterable<String> ids, this.mode)
    : ids = Set.unmodifiable(ids);
  final Set<String> ids;
  final TimetableComparisonMode mode;
}

class ScheduleComparisonPage extends StatefulWidget {
  const ScheduleComparisonPage({super.key, required this.store});
  final ScheduleStore store;
  @override
  State<ScheduleComparisonPage> createState() => _ScheduleComparisonPageState();
}

class _ScheduleComparisonPageState extends State<ScheduleComparisonPage> {
  late final Set<String> _selected = {widget.store.active.id};
  TimetableComparisonMode _mode = TimetableComparisonMode.commonCourses;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('课表对比')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('选择课表（已选 ${_selected.length} 张）')),
            TextButton(
              onPressed: () => setState(
                () => _selected.addAll(widget.store.documents.map((d) => d.id)),
              ),
              child: const Text('全选'),
            ),
          ],
        ),
        for (final doc in widget.store.documents)
          CheckboxListTile(
            key: ValueKey('compare-select-${doc.id}'),
            title: Text(doc.name),
            value: _selected.contains(doc.id),
            onChanged: (value) => setState(() {
              if (value == true) {
                _selected.add(doc.id);
              } else {
                _selected.remove(doc.id);
              }
            }),
          ),
        const SizedBox(height: 16),
        SegmentedButton<TimetableComparisonMode>(
          segments: const [
            ButtonSegment(
              value: TimetableComparisonMode.commonCourses,
              label: Text('共同课程'),
            ),
            ButtonSegment(
              value: TimetableComparisonMode.commonFree,
              label: Text('共同空闲'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.single),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('对比结果在首页课表中显示，可左右翻周。共同课程高亮，其他课程变暗；共同空闲模式下，有人上课的区域显示为占用。'),
        ),
        if (_selected.length < 2) const Text('请至少选择两张课表进行对比'),
        FilledButton(
          onPressed: _selected.length < 2
              ? null
              : () => Navigator.pop(
                  context,
                  TimetableComparisonSelection(_selected, _mode),
                ),
          child: const Text('开始对比'),
        ),
      ],
    ),
  );
}
