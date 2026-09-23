import 'package:flutter/material.dart';

class WeekSelector extends StatelessWidget {
  const WeekSelector({
    super.key,
    required this.week,
    required this.currentWeek,
    required this.onSelected,
    required this.onReturnToCurrent,
  });
  final int week;
  final int currentWeek;
  final ValueChanged<int> onSelected;
  final VoidCallback onReturnToCurrent;

  Future<void> _choose(BuildContext context) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) =>
          WeekSelectionDialog(week: week, currentWeek: currentWeek),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '选择教学周，双击返回本周',
    child: GestureDetector(
      key: const ValueKey('week-selector'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _choose(context),
      onDoubleTap: onReturnToCurrent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                week < 1 ? '开学前 ${1 - week} 周' : '第 $week 周',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                week == currentWeek ? '（本周）' : '（非本周）',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class WeekSelectionDialog extends StatelessWidget {
  const WeekSelectionDialog({
    super.key,
    required this.week,
    required this.currentWeek,
  });
  final int week;
  final int currentWeek;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      key: const ValueKey('week-selection-dialog'),
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择教学周', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                currentWeek >= 1 && currentWeek <= 16
                    ? '圆圈标记现实本周 · 实色标记正在查看的周'
                    : '当前日期不在第 1–16 教学周内',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
                children: [
                  for (var value = 1; value <= 16; value++)
                    Semantics(
                      selected: week == value,
                      label: '第 $value 周${value == currentWeek ? '，现实本周' : ''}',
                      child: InkWell(
                        key: ValueKey('choose-week-$value'),
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => Navigator.pop(context, value),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: week == value
                                ? colors.primary
                                : Colors.transparent,
                            border: value == currentWeek
                                ? Border.all(color: colors.primary, width: 2)
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: FittedBox(
                              child: Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: week == value
                                      ? colors.onPrimary
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
