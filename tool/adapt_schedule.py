from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
path = root / 'lib/features/home/academic_schedule_page.dart'
s = path.read_text(encoding='utf-8')
for service in ['academic_schedule_api_client', 'academic_schedule_notification_service', 'academic_schedule_widget_service']:
    s = re.sub(r"import '../../data/services/" + service + r"\.dart';\n", '', s)
s = s.replace("import 'package:flutter/foundation.dart';\n", '')
s = s.replace('    required this.notificationService,\n    required this.widgetService,\n    required this.onLoginRequired,', '    required this.onImport,\n    required this.onShare,\n    required this.onManage,\n    required this.onTimes,')
s = s.replace('  final AcademicScheduleNotificationService notificationService;\n  final AcademicScheduleWidgetService widgetService;\n  final Future<void> Function() onLoginRequired;', '  final Future<void> Function() onImport;\n  final Future<void> Function() onShare;\n  final Future<void> Function() onManage;\n  final Future<void> Function() onTimes;')
s = s.replace('  bool _refreshing = false;\n', '')
s = s.replace('  final _displaySettingsService = AcademicScheduleDisplaySettingsService();', '  late final _displaySettingsService = AcademicScheduleDisplaySettingsService(store: widget.repository.store, documentId: widget.repository.documentId);')
s = re.sub(r'\s*unawaited\(\s*widget\.widgetService\.syncSchedule\([\s\S]*?\n\s*\);', '', s)
s = re.sub(r'\s*unawaited\(widget\.notificationService\.syncScheduleReminders\(\)\);', '', s)
s = re.sub(r'\s*await widget\.notificationService\.syncScheduleReminders\([\s\S]*?\n\s*\);', '', s)
a = s.index('  Future<void> _refreshSchedule()')
b = s.index('  Future<void> _setFirstWeekStartDate()', a)
s = s[:a] + '''  Future<void> _refreshSchedule() async {
    await widget.onImport();
    if (mounted) await _loadCached();
  }

''' + s[b:]
s = s.replace("message: '登录教务后刷新一次，就可以在本地显示课表。',", "message: '导入学校或朋友的课表，也可以点空白格添加课程。',")
s = s.replace("label: const Text('同步课表'),", "label: const Text('导入课表'),")
a = s.index('        title: Text(_schedule?.term.displayName')
b = s.index('      body:', a)
s = s[:a] + '''        title: Tooltip(
          message: '管理课表',
          child: InkWell(
            onTap: widget.onManage,
            child: Row(children: [
              Flexible(child: Text(widget.repository.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.expand_more, size: 20),
            ]),
          ),
        ),
        actions: [
          IconButton(tooltip: '导入课表', onPressed: _refreshSchedule, icon: const Icon(Icons.file_download_outlined)),
          IconButton(tooltip: '分享课表', onPressed: widget.onShare, icon: const Icon(Icons.ios_share_outlined)),
          IconButton(tooltip: '更多', onPressed: _openMoreMenu, icon: const Icon(Icons.more_horiz)),
        ],
      ),
''' + s[b:]
a = s.index('  Future<void> _openMoreMenu()')
b = s.index('  Future<void> _openDisplaySettings()', a)
s = s[:a] + '''  Future<void> _openMoreMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in <(String, String, IconData)>[
            ('add', '添加课程', Icons.add),
            ('date', '开学日期', Icons.edit_calendar_outlined),
            ('times', '作息时间', Icons.schedule),
            ('display', '显示设置', Icons.palette_outlined),
            ('licenses', '开源许可', Icons.info_outline),
          ]) ListTile(leading: Icon(item.$3), title: Text(item.$2),
            onTap: () => Navigator.pop(context, item.$1)),
        ],
      ))),
    );
    if (!mounted) return;
    switch (action) {
      case 'add': await _openManualCourseSheet(_ScheduleSlot(weekday: DateTime.now().weekday, section: 1));
      case 'date': await _setFirstWeekStartDate();
      case 'times': await widget.onTimes();
      case 'display': await _openDisplaySettings();
      case 'licenses': showLicensePage(context: context, applicationName: '轻课表', applicationVersion: '1.0.0', applicationLegalese: '课表界面与模型改编自 ShuYo，GPL-3.0。');
    }
  }

''' + s[b:]
a = s.index('  Future<void> _openNotificationSettings()')
b = s.index('  void _showSnack(', a)
s = s[:a] + s[b:]
a = s.index('  void _showScheduleReminderSnack(')
b = s.index('  void _refreshDisplayedWeekIfNeeded()', a)
s = s[:a] + s[b:]
a = s.index('enum _ScheduleMenuAction')
b = s.index('enum _ManualCourseAction', a)
s = s[:a] + s[b:]
a = s.index('// Kept until the legacy bottom-sheet editor')
b = s.index('class _DisplaySettingsSheet', a)
s = s[:a] + s[b:]
a = s.index('class _NotificationSettingsSheet')
b = s.index('class _ScheduleBody', a)
s = s[:a] + s[b:]
path.write_text(s, encoding='utf-8')

path = root / 'lib/data/repositories/academic_schedule_repository.dart'
old = path.read_text(encoding='utf-8')
prefix = old[old.index('class ScheduleWeekState'):old.index('class AcademicScheduleRepository')]
tail = old[old.index('  static DateTime startOfWeek'):]
path.write_text('''import '../models/academic_schedule.dart';
import '../schedule_store.dart';

''' + prefix + '''class AcademicScheduleRepository {
  AcademicScheduleRepository({required this.store, required this.documentId});
  final ScheduleStore store;
  final String documentId;
  String get name => store.byId(documentId).name;
  Future<AcademicSchedule?> loadCachedSchedule() async => store.byId(documentId).schedule;
  Future<AcademicScheduleCacheState> loadCachedState({DateTime? now}) async => AcademicScheduleCacheState(
    schedule: await loadCachedSchedule(), weekState: await loadWeekState(now: now));
  Future<void> saveCachedSchedule(AcademicSchedule schedule) => store.mutate(documentId, (d) => d.copyWith(schedule: schedule));
  Future<ScheduleWeekState> loadWeekState({DateTime? now}) async => ScheduleWeekState(
    currentWeek: 1, anchorMonday: store.byId(documentId).firstWeekStart);
  Future<void> setFirstWeekStart(DateTime date) => store.mutate(documentId, (d) => d.copyWith(firstWeekStart: date));
  int activeWeekFromState(AcademicSchedule schedule, ScheduleWeekState state, {DateTime? now}) {
    final today = startOfWeek(now ?? DateTime.now());
    // UTC dates avoid 23/25-hour days around daylight-saving transitions.
    final delta = DateTime.utc(today.year, today.month, today.day).difference(
      DateTime.utc(state.anchorMonday.year, state.anchorMonday.month, state.anchorMonday.day)).inDays ~/ 7;
    return (state.currentWeek + delta).clamp(0, schedule.vacationWeek);
  }
''' + tail, encoding='utf-8')

path = root / 'lib/data/services/academic_schedule_display_settings_service.dart'
old = path.read_text(encoding='utf-8')
prefix = old[old.index('class AcademicScheduleDisplaySettings'):old.index('class AcademicScheduleDisplaySettingsService')]
path.write_text("import '../schedule_store.dart';\n\n" + prefix + '''class AcademicScheduleDisplaySettingsService {
  AcademicScheduleDisplaySettingsService({required this.store, required this.documentId});
  final ScheduleStore store;
  final String documentId;
  Future<AcademicScheduleDisplayState> loadState() async {
    final d = store.byId(documentId);
    return AcademicScheduleDisplayState(settings: AcademicScheduleDisplaySettings(
      colorful: d.colorful, showTeacher: d.showTeacher), courseColorValues: d.colors);
  }
  Future<AcademicScheduleDisplaySettings> saveSettings(AcademicScheduleDisplaySettings settings) async {
    await store.mutate(documentId, (d) => d.copyWith(colorful: settings.colorful, showTeacher: settings.showTeacher));
    return settings;
  }
  Future<void> saveCourseColor(String key, int value) => store.mutate(documentId, (d) => d.copyWith(colors: {...d.colors, key: value}));
}
''', encoding='utf-8')
