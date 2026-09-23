import 'package:flutter/material.dart';
import '../../data/schedule_store.dart';

class ScheduleDisplaySettingsSheet extends StatefulWidget {
  const ScheduleDisplaySettingsSheet({
    super.key,
    required this.store,
    required this.documentId,
    required this.onChanged,
  });
  final ScheduleStore store;
  final String documentId;
  final VoidCallback onChanged;

  @override
  State<ScheduleDisplaySettingsSheet> createState() =>
      _ScheduleDisplaySettingsSheetState();
}

class _ScheduleDisplaySettingsSheetState
    extends State<ScheduleDisplaySettingsSheet> {
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    // Discard an unfinished slider preview if the route closes mid-gesture.
    final store = widget.store;
    Future.microtask(() => store.previewPopupOpacity(null));
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
      _error = '保存失败，请重试';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.store.byId(widget.documentId);
    final appearance = widget.store.appearance;
    Widget toggle(
      String label,
      bool value,
      ScheduleDocument Function(bool) update,
    ) => SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: _saving
          ? null
          : (v) => _save(() => widget.store.update(update(v))),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text(
                '显示设置',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              trailing: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('当前课表'),
            ),
            toggle('显示背景格子', doc.showGrid, (v) => doc.copyWith(showGrid: v)),
            toggle('显示学分', doc.showCredit, (v) => doc.copyWith(showCredit: v)),
            ListTile(
              title: const Text('课程周数显示'),
              subtitle: DropdownButton<CourseWeekDisplay>(
                isExpanded: true,
                value: doc.courseWeekDisplay,
                items: const [
                  DropdownMenuItem(
                    value: CourseWeekDisplay.all,
                    child: Text('所有课程'),
                  ),
                  DropdownMenuItem(
                    value: CourseWeekDisplay.otherWeeks,
                    child: Text('仅非本周课程'),
                  ),
                  DropdownMenuItem(
                    value: CourseWeekDisplay.none,
                    child: Text('不显示'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) {
                          _save(
                            () => widget.store.update(
                              doc.copyWith(courseWeekDisplay: v),
                            ),
                          );
                        }
                      },
              ),
            ),
            toggle('多彩显示', doc.colorful, (v) => doc.copyWith(colorful: v)),
            toggle(
              '显示教师',
              doc.showTeacher,
              (v) => doc.copyWith(showTeacher: v),
            ),
            toggle(
              '显示非本周课程',
              doc.showOtherWeeks,
              (v) => doc.copyWith(showOtherWeeks: v),
            ),
            toggle(
              '显示课程号',
              doc.showCourseCode,
              (v) => doc.copyWith(showCourseCode: v),
            ),
            toggle(
              '显示课表控制栏',
              doc.showControls,
              (v) => doc.copyWith(showControls: v),
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('整个 App'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                    ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                  ],
                  selected: {appearance.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: _saving
                      ? null
                      : (selection) => _save(
                          () => widget.store.setAppearance(
                            appearance.copyWith(themeMode: selection.single),
                          ),
                        ),
                ),
              ),
            ),
            ListTile(
              title: const Text('弹窗背景透明度'),
              subtitle: Text(
                '${((1 - appearance.popupOpacity) * 100).round()}%',
              ),
            ),
            Slider(
              key: const ValueKey('popup-transparency'),
              value: 1 - appearance.popupOpacity,
              divisions: 20,
              label: '${((1 - appearance.popupOpacity) * 100).round()}%',
              onChanged: _saving
                  ? null
                  : (v) {
                      widget.store.previewPopupOpacity(1 - v);
                      setState(() {});
                    },
              onChangeEnd: (v) => _save(() async {
                try {
                  await widget.store.setAppearance(
                    widget.store.appearance.copyWith(popupOpacity: 1 - v),
                  );
                } finally {
                  widget.store.previewPopupOpacity(null);
                }
              }),
            ),
            SwitchListTile(
              title: const Text('同步手机系统字体'),
              subtitle: const Text('关闭后使用内置 Noto Sans SC 字体'),
              value: appearance.useSystemFont,
              onChanged: _saving
                  ? null
                  : (v) => _save(
                      () => widget.store.setAppearance(
                        appearance.copyWith(useSystemFont: v),
                      ),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
