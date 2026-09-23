// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/academic_schedule.dart';
import '../../data/repositories/academic_schedule_repository.dart';
import '../../data/services/academic_schedule_display_settings_service.dart';
import '../../shared/shuyo_text_styles.dart';
import '../../shared/theme/shuyo_theme.dart';
import '../../shared/widgets/empty_state.dart';
import 'academic_schedule_editor_page.dart';
import 'schedule_more_sheet.dart';
import 'schedule_gesture_pager.dart';
import 'week_selector.dart';
import 'comparison_week_grid.dart';
import '../schedule_comparison_page.dart';
import 'schedule_display_settings_sheet.dart';
import 'adaptive_course_text.dart';
import '../../data/schedule_week_index.dart';
import '../../data/schedule_calendar.dart';
import '../../data/schedule_store.dart';
import '../calendar_records_page.dart';

const _scheduleCellInset = 2.5;
const _scheduleCourseInset = 2.5;
const _scheduleCellRadius = 4.0;
const _scheduleCourseRadius = 5.0;

class AcademicSchedulePage extends StatefulWidget {
  const AcademicSchedulePage({
    super.key,
    required this.repository,
    required this.onImport,
    required this.onShare,
    required this.onManage,
    required this.onTimes,
    this.initialState,
    this.initialDisplayState,
    this.initialLoadError,
  });

  final AcademicScheduleRepository repository;
  final Future<void> Function() onImport;
  final Future<void> Function() onShare;
  final Future<void> Function() onManage;
  final Future<void> Function() onTimes;
  final AcademicScheduleCacheState? initialState;
  final AcademicScheduleDisplayState? initialDisplayState;
  final String? initialLoadError;

  @override
  State<AcademicSchedulePage> createState() => _AcademicSchedulePageState();
}

class _AcademicSchedulePageState extends State<AcademicSchedulePage> {
  late Future<void> _loadFuture;
  AcademicSchedule? _schedule;
  ScheduleWeekState? _weekState;
  _ScheduleSlot? _selectedManualSlot;
  int _displayedWeek = 1;
  TimetableComparisonSelection? _comparison;
  bool _followsCurrentWeek = true;
  Timer? _weekTimer;
  AcademicScheduleDisplaySettingsService get _displaySettingsService =>
      AcademicScheduleDisplaySettingsService(
        store: widget.repository.store,
        documentId: widget.repository.documentId,
      );
  AcademicScheduleDisplaySettings _displaySettings =
      const AcademicScheduleDisplaySettings(
        colorful: false,
        showTeacher: false,
      );
  Map<String, int> _courseColorValues = const {};
  late bool _usingInitialState;
  String? _initialLoadError;

  @override
  void initState() {
    super.initState();
    final initialState = widget.initialState;
    _usingInitialState =
        initialState != null || widget.initialLoadError != null;
    _initialLoadError = widget.initialLoadError;
    if (initialState != null) {
      _applyCachedState(initialState.schedule, initialState.weekState);
    }
    final initialDisplayState = widget.initialDisplayState;
    if (initialDisplayState != null) {
      _applyDisplayState(initialDisplayState);
    }
    _loadFuture = _usingInitialState ? Future<void>.value() : _loadCached();
    _weekTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDisplayedWeekIfNeeded(),
    );
  }

  @override
  void didUpdateWidget(covariant AcademicSchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.documentId != widget.repository.documentId) {
      _selectedManualSlot = null;
      _usingInitialState = true;
      _initialLoadError = null;
      _applyCachedState(
        widget.repository.store.byId(widget.repository.documentId).schedule,
        ScheduleWeekState(
          currentWeek: 1,
          anchorMonday: widget.repository.store
              .byId(widget.repository.documentId)
              .firstWeekStart,
        ),
      );
      _applyDisplayState(_displaySettingsService.currentState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            52 +
            (MediaQuery.textScalerOf(context).scale(28) - 28).clamp(0.0, 56.0) *
                1.25,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeekSelector(
              week: _displayedWeek,
              currentWeek: _actualWeek,
              onReturnToCurrent: _returnToCurrent,
              onSelected: _selectWeek,
            ),
            Text(
              _displayedDateRange,
              key: const ValueKey('displayed-week-dates'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: context.shuyoColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '导入课表',
            onPressed: _refreshSchedule,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: '分享课表',
            onPressed: widget.onShare,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: '更多',
            onPressed: _openMoreMenu,
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: _usingInitialState
          ? _buildLoadedBody(_initialLoadError)
          : FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  );
                }
                if (snapshot.hasError) {
                  return _buildLoadedBody(snapshot.error.toString());
                }
                return _buildLoadedBody(null);
              },
            ),
    );
  }

  Widget _buildLoadedBody(String? error) {
    if (error != null) {
      return _ScheduleErrorState(message: error, onRetry: _retryLoadCached);
    }
    final schedule = _schedule;
    final weekState = _weekState;
    if (schedule == null || weekState == null) {
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        title: '还没有课表',
        message: '导入学校或朋友的课表，也可以点空白格添加课程。',
        action: FilledButton.icon(
          onPressed: _refreshSchedule,
          icon: const Icon(Icons.refresh),
          label: const Text('导入课表'),
        ),
      );
    }
    final comparison = _comparison;
    if (comparison != null) {
      final documents = widget.repository.store.documents
          .where((d) => comparison.ids.contains(d.id))
          .toList();
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<TimetableComparisonMode>(
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
                  selected: {comparison.mode},
                  onSelectionChanged: (m) => setState(
                    () => _comparison = TimetableComparisonSelection(
                      comparison.ids,
                      m.single,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '退出对比',
                onPressed: () => setState(() => _comparison = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            comparison.mode == TimetableComparisonMode.commonFree
                ? '空白区域为共同空闲'
                : '共同课程高亮，其他课程变暗',
          ),
          Text(
            documents.map((d) => d.name).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Expanded(
            child: _ComparisonBody(
              documents: documents,
              selection: comparison,
              week: _displayedWeek,
              minWeek: _comparisonWeeks(documents).$1,
              maxWeek: _comparisonWeeks(documents).$2,
              firstWeek: weekState.firstWeekStart,
              settings: _displaySettings,
              onWeek: _selectWeek,
              onDays: (days) => _saveDisplaySettings(
                _displaySettings.copyWith(visibleDays: days),
              ),
            ),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: _ScheduleBody(
        key: ValueKey(widget.repository.documentId),
        document: widget.repository.store.byId(widget.repository.documentId),
        onVisibleDaysChanged: (days) =>
            _saveDisplaySettings(_displaySettings.copyWith(visibleDays: days)),
        schedule: schedule,
        maxDisplayWeek: _maxDisplayWeek,
        minDisplayWeek: _minDisplayWeek,
        weekState: weekState,
        displayedWeek: _displayedWeek,
        displaySettings: _displaySettings,
        courseColorValues: _courseColorValues,
        onQuickWeekSelected: _selectWeek,
        selectedManualSlot: _selectedManualSlot,
        canAddCourse: true,
        onEmptySlotTap: _handleEmptySlotTap,
        onCourseTap: _handleCourseTap,
      ),
    );
  }

  (int, int) _comparisonWeeks(List<ScheduleDocument> documents) {
    var first = _minDisplayWeek;
    var last = _maxDisplayWeek;
    final axis = widget.repository.store.byId(widget.repository.documentId);
    for (final doc in documents) {
      final dates = [
        doc.firstWeekStart,
        DateTime(
          doc.firstWeekStart.year,
          doc.firstWeekStart.month,
          doc.firstWeekStart.day + doc.schedule.maxWeek * 7 - 1,
        ),
        ...doc.adjustments.map((r) => r.date),
      ];
      for (final date in dates) {
        final week = ScheduleCalendar.teachingWeek(axis, date);
        if (week < first) first = week;
        if (week > last) last = week;
      }
    }
    return (first, last);
  }

  int get _actualWeek {
    if (_weekState == null) return 1;
    final first = _weekState!.firstWeekStart;
    final now = DateTime.now();
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    return (days / 7).floor() + 1;
  }

  int get _maxDisplayWeek {
    final doc = widget.repository.store.byId(widget.repository.documentId);
    return [
      doc.schedule.maxWeek,
      _actualWeek,
      _displayedWeek,
      ...doc.adjustments.map((r) => ScheduleCalendar.teachingWeek(doc, r.date)),
    ].reduce((a, b) => a > b ? a : b);
  }

  int get _minDisplayWeek {
    final doc = widget.repository.store.byId(widget.repository.documentId);
    return [
      1,
      _displayedWeek,
      ...doc.adjustments.map((r) => ScheduleCalendar.teachingWeek(doc, r.date)),
    ].reduce((a, b) => a < b ? a : b);
  }

  String get _displayedDateRange {
    final first = _weekState?.firstWeekStart;
    if (first == null) return '';
    final monday = DateTime(
      first.year,
      first.month,
      first.day + (_displayedWeek - 1) * 7,
    );
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    return '${monday.year}/${monday.month}/${monday.day} – ${sunday.month}/${sunday.day}';
  }

  void _returnToCurrent() {
    if (_actualWeek < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('尚未开学，当前没有对应的教学周')));
      return;
    }
    setState(() {
      _displayedWeek = _actualWeek;
      _followsCurrentWeek = true;
      _selectedManualSlot = null;
    });
  }

  void _selectWeek(int week) {
    if (week == _displayedWeek) return;
    setState(() {
      _displayedWeek = week;
      _followsCurrentWeek = false;
      _selectedManualSlot = null;
    });
  }

  void _retryLoadCached() {
    setState(() {
      _usingInitialState = false;
      _initialLoadError = null;
      _loadFuture = _loadCached();
    });
  }

  Future<void> _loadCached() async {
    final cachedStateFuture = widget.repository.loadCachedState();
    final displayStateFuture = _displaySettingsService.loadState();
    final cachedState = await cachedStateFuture;
    final displayState = await displayStateFuture;
    if (!mounted) {
      return;
    }
    setState(() {
      _applyCachedState(cachedState.schedule, cachedState.weekState);
      _applyDisplayState(displayState);
    });
  }

  void _applyDisplayState(AcademicScheduleDisplayState state) {
    _displaySettings = state.settings;
    _courseColorValues = state.courseColorValues;
  }

  void _applyCachedState(
    AcademicSchedule? schedule,
    ScheduleWeekState weekState,
  ) {
    _schedule = schedule;
    _weekState = weekState;
    _displayedWeek = schedule == null
        ? 1
        : _displayableWeek(
            widget.repository.activeWeekFromState(schedule, weekState),
            schedule,
          );
    _followsCurrentWeek = true;
  }

  Future<void> _refreshSchedule() async {
    await widget.onImport();
    if (mounted) await _loadCached();
  }

  Future<void> _setFirstWeekStartDate() async {
    final schedule = _schedule;
    final currentState = _weekState;
    if (schedule == null || currentState == null) return;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) =>
          _FirstWeekDatePickerDialog(initialDate: currentState.firstWeekStart),
    );
    if (picked == null || !mounted) return;
    await widget.repository.setFirstWeekStart(picked);
    final weekState = await widget.repository.loadWeekState();
    if (!mounted) {
      return;
    }
    setState(() {
      _weekState = weekState;
      _displayedWeek = _displayableWeek(
        widget.repository.activeWeekFromState(schedule, weekState),
        schedule,
      );
      _followsCurrentWeek = true;
      _selectedManualSlot = null;
    });
    _showSnack('已将 ${picked.month}月${picked.day}日设为第一周首日');
  }

  Future<void> _handleEmptySlotTap(_ScheduleSlot slot) async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }
    final selected = _selectedManualSlot;
    if (selected != null && selected == slot) {
      await _openManualCourseSheet(slot);
      return;
    }
    setState(() => _selectedManualSlot = slot);
  }

  Future<void> _openManualCourseSheet(_ScheduleSlot slot) async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }
    final doc = widget.repository.store.byId(widget.repository.documentId);
    final first = doc.firstWeekStart;
    final date = DateTime(
      first.year,
      first.month,
      first.day + (_displayedWeek - 1) * 7 + slot.weekday - 1,
    );
    final (sourceWeek, sourceDay) = ScheduleCalendar.source(doc, date);
    if (sourceWeek < 1 || sourceWeek > 32) {
      _showSnack('该日期不在可编辑的教学周内；请先设置手动调休，指定有效教学周。');
      return;
    }
    final adjusted = doc.adjustments.any((r) => r.date == date);
    final result = await Navigator.of(context).push<ScheduleCourseEditorResult>(
      MaterialPageRoute(
        builder: (context) => AcademicScheduleEditorPage(
          initialWeek: sourceWeek,
          maxWeek: sourceWeek > schedule.maxWeek
              ? sourceWeek
              : schedule.maxWeek,
          contextNote: adjusted
              ? '调休日：新增课程将写入第 $sourceWeek 周周${'一二三四五六日'[sourceDay - 1]}的源安排。'
              : null,
          initialWeekday: sourceDay,
          initialStartSection: slot.section,
          colorful: _displaySettings.colorful,
          palette: context.shuyoColors.schedulePalette,
          conflictValidator: (result) => _findEditorConflicts(schedule, result),
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final sessions = [
      for (final time in result.times)
        _courseSessionFromDraft(
          time,
          weekday: time.weekday,
          courseName: result.courseName,
          courseCode: result.courseCode,
          credit: result.credit,
        ),
    ];
    final next = schedule.copyWith(
      sessions: [...schedule.sessions, ...sessions],
    );
    await widget.repository.saveCachedSchedule(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _schedule = next;
      _selectedManualSlot = null;
    });
    if (result.colorValue != null) {
      final colorKey = _courseColorSeed(sessions.first);
      await _displaySettingsService.saveCourseColor(
        colorKey,
        result.colorValue!,
      );
      if (mounted) {
        setState(
          () => _courseColorValues = {
            ..._courseColorValues,
            colorKey: result.colorValue!,
          },
        );
      }
    }
  }

  Future<void> _handleCourseTap(CourseSession session) async {
    final document = widget.repository.store.byId(widget.repository.documentId);
    final visible = ScheduleWeekIndex.forDocument(
      document,
    ).week(_displayedWeek, _displaySettings.showOtherWeeks).sessions;
    final overlaps = visible
        .where(
          (other) =>
              other.weekday == session.weekday &&
              other.startSection <= session.endSection &&
              session.startSection <= other.endSection,
        )
        .toList();
    CourseSession original(CourseSession visible) => document.schedule.sessions
        .firstWhere((s) => s.id == visible.id, orElse: () => visible);
    final first = document.firstWeekStart;
    final date = DateTime(
      first.year,
      first.month,
      first.day + (_displayedWeek - 1) * 7 + session.weekday - 1,
    );
    final sourceWeek = ScheduleCalendar.source(document, date).$1;
    final adjusted = document.adjustments.any((r) => r.date == date);
    if (overlaps.length > 1) {
      final selected = await showModalBottomSheet<CourseSession>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('同一时段的课程')),
              for (final course in overlaps)
                ListTile(
                  title: Text(course.courseName),
                  subtitle: Text(
                    '${course.occursInWeek(sourceWeek) ? '' : '非本周 · '}${course.sectionText} · ${course.location} ${course.teacherName}',
                  ),
                  onTap: () => Navigator.pop(context, course),
                ),
            ],
          ),
        ),
      );
      if (selected != null && mounted) {
        await _showCourseDetail(
          original(selected),
          sourceWeek: sourceWeek,
          adjusted: adjusted,
        );
      }
    } else {
      await _showCourseDetail(
        original(session),
        sourceWeek: sourceWeek,
        adjusted: adjusted,
      );
    }
  }

  Future<void> _showCourseDetail(
    CourseSession session, {
    required int sourceWeek,
    bool adjusted = false,
  }) async {
    final action = await showModalBottomSheet<_ManualCourseAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = context.shuyoColors;
        final colorValue = _courseColorValues[_courseColorSeed(session)];
        final color = colorValue == null
            ? _courseColorForSession(context, session)
            : Color(colorValue);
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        session.courseName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailLine(
                  Icons.schedule,
                  '${_weekdayName(session.weekday)} ${session.sectionText} ${session.weekText}',
                ),
                if (session.placeText.isNotEmpty)
                  _DetailLine(Icons.place_outlined, session.placeText),
                if (session.displayCourseCode.isNotEmpty)
                  _DetailLine(Icons.tag, session.displayCourseCode),
                if (adjusted)
                  _DetailLine(
                    Icons.event_repeat,
                    '调休：按第 $sourceWeek 周执行；编辑或删除会修改源课程',
                  ),
                if (!session.occursInWeek(sourceWeek))
                  const _DetailLine(Icons.event_busy_outlined, '非本周课程'),
                if (session.teacherName.isNotEmpty)
                  _DetailLine(Icons.person_outline, session.teacherName),
                if (session.credit.isNotEmpty)
                  _DetailLine(Icons.school_outlined, '${session.credit} 学分'),
                if (session.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      border: Border(left: BorderSide(color: color, width: 3)),
                    ),
                    child: Text(
                      session.note.trim(),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pop(_ManualCourseAction.edit),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_ManualCourseAction.delete),
                        icon: Icon(Icons.delete_outline, color: colors.danger),
                        label: Text(
                          '删除',
                          style: TextStyle(color: colors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ManualCourseAction.edit:
        await _openCourseEditSheet(session, sourceWeek);
      case _ManualCourseAction.delete:
        final scope = await _openDeleteScopeMenu(session, sourceWeek);
        if (scope == null || !mounted) {
          return;
        }
        final confirmed = await _confirmDeleteCourse(
          session,
          scope,
          sourceWeek,
        );
        if (confirmed) {
          await _deleteCourse(session, scope, sourceWeek);
        }
    }
  }

  Future<void> _openCourseEditSheet(
    CourseSession session,
    int sourceWeek,
  ) async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }
    final relatedSessions = schedule.sessions
        .where((item) => _sameCourse(item, session))
        .toList();
    final colorKey = _courseColorSeed(session);
    final result = await Navigator.of(context).push<ScheduleCourseEditorResult>(
      MaterialPageRoute(
        builder: (context) => AcademicScheduleEditorPage(
          initialWeek: sourceWeek,
          maxWeek: schedule.maxWeek,
          initialWeekday: session.weekday,
          initialStartSection: session.startSection,
          initialSessions: relatedSessions,
          colorful: _displaySettings.colorful,
          palette: context.shuyoColors.schedulePalette,
          initialColorValue: _courseColorValues[colorKey],
          conflictValidator: (result) =>
              _findEditorConflicts(schedule, result, excludingCourse: session),
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final nextSessions = schedule.sessions
        .where((item) => !_sameCourse(item, session))
        .toList();
    for (var index = 0; index < result.times.length; index++) {
      final time = result.times[index];
      nextSessions.add(
        _courseSessionFromDraft(
          time,
          weekday: time.weekday,
          base: index < relatedSessions.length
              ? relatedSessions[index]
              : session,
          courseName: result.courseName,
          courseCode: result.courseCode,
          credit: result.credit,
          forceNewId: index >= relatedSessions.length,
        ),
      );
    }
    final next = schedule.copyWith(sessions: nextSessions);
    await widget.repository.saveCachedSchedule(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _schedule = next;
      _selectedManualSlot = null;
    });
    if (result.colorValue != null) {
      final nextColorKey = _courseColorSeed(nextSessions.last);
      await _displaySettingsService.saveCourseColor(
        nextColorKey,
        result.colorValue!,
      );
      if (mounted) {
        setState(
          () => _courseColorValues = {
            ..._courseColorValues,
            nextColorKey: result.colorValue!,
          },
        );
      }
    }
  }

  Future<void> _deleteCourse(
    CourseSession target,
    _CourseDeleteScope scope,
    int sourceWeek,
  ) async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }
    final nextSessions = <CourseSession>[];
    var changed = false;
    for (final session in schedule.sessions) {
      final sameCourse = _sameCourse(session, target);
      final sameSlot = _sameCourseSlot(session, target);
      if (scope == _CourseDeleteScope.allCourseSlots && sameCourse) {
        changed = true;
        continue;
      }
      if (scope == _CourseDeleteScope.allWeeksInSlot &&
          sameCourse &&
          sameSlot) {
        changed = true;
        continue;
      }
      if (scope == _CourseDeleteScope.singleOccurrence &&
          _sameCourseIdentity(session, target)) {
        final weeks = session.weeks.isEmpty
            ? [
                for (var week = 1; week <= schedule.maxWeek; week++)
                  if (week != sourceWeek) week,
              ]
            : session.weeks.where((week) => week != sourceWeek).toList();
        if (weeks.isEmpty) {
          changed = true;
          continue;
        }
        changed = true;
        nextSessions.add(_copySessionWithWeeks(session, weeks));
        continue;
      }
      nextSessions.add(session);
    }
    if (!changed) {
      return;
    }
    final next = schedule.copyWith(sessions: nextSessions);
    await widget.repository.saveCachedSchedule(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _schedule = next;
      _selectedManualSlot = null;
    });
  }

  Future<_CourseDeleteScope?> _openDeleteScopeMenu(
    CourseSession session,
    int sourceWeek,
  ) {
    return showModalBottomSheet<_CourseDeleteScope>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colors = context.shuyoColors;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        final week = sourceWeek;
        final weekday = _weekdayName(session.weekday);
        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).dialogTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.event_busy_outlined),
                    title: Text('仅第$week周$weekday的这节课'),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_CourseDeleteScope.singleOccurrence),
                  ),
                  ListTile(
                    leading: const Icon(Icons.view_week_outlined),
                    title: Text('全部$weekday的这节课'),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_CourseDeleteScope.allWeeksInSlot),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: colors.danger,
                    ),
                    title: Text(
                      '这门课程的全部时间段',
                      style: TextStyle(color: colors.danger),
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_CourseDeleteScope.allCourseSlots),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteCourse(
    CourseSession session,
    _CourseDeleteScope scope,
    int sourceWeek,
  ) async {
    final description = switch (scope) {
      _CourseDeleteScope.singleOccurrence =>
        '仅删除第$sourceWeek周${_weekdayName(session.weekday)}的这节课。',
      _CourseDeleteScope.allWeeksInSlot =>
        '删除${_weekdayName(session.weekday)}该时间段的全部周次。',
      _CourseDeleteScope.allCourseSlots => '删除这门课程的全部时间段。',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.shuyoColors;
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('${session.courseName}\n$description'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  // ignore: unused_element
  bool _hasScheduleConflict(
    AcademicSchedule schedule,
    ScheduleCourseTimeDraft draft,
    int weekday, {
    CourseSession? excluding,
  }) {
    final draftWeeks = draft.weeks.toSet();
    return schedule.sessions.any((session) {
      if (excluding != null && _sameCourseIdentity(session, excluding)) {
        return false;
      }
      if (session.weekday != weekday) {
        return false;
      }
      if (!_sectionRangesOverlap(
        session.startSection,
        session.endSection,
        draft.startSection,
        draft.endSection,
      )) {
        return false;
      }
      if (session.weeks.isEmpty) {
        return true;
      }
      return session.weeks.any(draftWeeks.contains);
    });
  }

  List<String> _findScheduleConflicts(
    AcademicSchedule schedule,
    ScheduleCourseTimeDraft draft, {
    CourseSession? excludingCourse,
  }) {
    final conflicts = <String>{};
    for (final session in schedule.sessions) {
      if (excludingCourse != null && _sameCourse(session, excludingCourse)) {
        continue;
      }
      if (session.weekday != draft.weekday ||
          !_sectionRangesOverlap(
            session.startSection,
            session.endSection,
            draft.startSection,
            draft.endSection,
          )) {
        continue;
      }
      final overlaps =
          session.weeks.isEmpty ||
          draft.weeks.isEmpty ||
          session.weeks.any(draft.weeks.toSet().contains);
      if (overlaps) {
        conflicts.add('${session.courseName} · ${_formatSessionTime(session)}');
      }
    }
    return conflicts.toList();
  }

  List<String> _findEditorConflicts(
    AcademicSchedule schedule,
    ScheduleCourseEditorResult result, {
    CourseSession? excludingCourse,
  }) {
    final conflicts = <String>[];
    for (var index = 0; index < result.times.length; index++) {
      final time = result.times[index];
      conflicts.addAll(
        _findScheduleConflicts(
          schedule,
          time,
          excludingCourse: excludingCourse,
        ),
      );
      for (var previous = 0; previous < index; previous++) {
        final other = result.times[previous];
        if (_timeDraftsOverlap(time, other)) {
          conflicts.add(_formatDraftTime(other));
        }
      }
    }
    return conflicts;
  }

  Future<void> _openMoreMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      builder: (context) => ScheduleMoreSheet(
        store: widget.repository.store,
        onChanged: () async {
          final state = await _displaySettingsService.loadState();
          if (mounted) setState(() => _applyDisplayState(state));
        },
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'manage':
        await widget.onManage();
      case 'add':
        await _openManualCourseSheet(
          _ScheduleSlot(weekday: DateTime.now().weekday, section: 1),
        );
      case 'compare':
        final comparison = await Navigator.of(context)
            .push<TimetableComparisonSelection>(
              MaterialPageRoute<TimetableComparisonSelection>(
                builder: (_) =>
                    ScheduleComparisonPage(store: widget.repository.store),
              ),
            );
        if (mounted && comparison != null) {
          setState(() => _comparison = comparison);
        }
      case 'exams':
      case 'adjustments':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CalendarRecordsPage(
              store: widget.repository.store,
              documentId: widget.repository.documentId,
              exams: action == 'exams',
            ),
          ),
        );
        if (mounted) setState(() {});
      case 'date':
        await _setFirstWeekStartDate();
      case 'times':
        await widget.onTimes();
      case 'display':
        await _openDisplaySettings();
      case 'licenses':
        showLicensePage(
          context: context,
          applicationName: '轻课表',
          applicationVersion: '1.0.0',
          applicationLegalese: '课表界面与模型改编自 ShuYo，GPL-3.0。',
        );
    }
  }

  Future<void> _openDisplaySettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (context) => ScheduleDisplaySettingsSheet(
        store: widget.repository.store,
        documentId: widget.repository.documentId,
        onChanged: () async {
          final state = await _displaySettingsService.loadState();
          if (mounted) setState(() => _applyDisplayState(state));
        },
      ),
    );
  }

  Future<void> _saveDisplaySettings(
    AcademicScheduleDisplaySettings next,
  ) async {
    final previous = _displaySettings;
    setState(() => _displaySettings = next);
    try {
      await _displaySettingsService.saveSettings(next);
    } catch (_) {
      if (mounted) {
        setState(() => _displaySettings = previous);
        _showSnack('显示设置保存失败，请重试');
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _refreshDisplayedWeekIfNeeded() {
    if (mounted) setState(() {});
    final schedule = _schedule;
    final weekState = _weekState;
    if (!mounted ||
        !_followsCurrentWeek ||
        schedule == null ||
        weekState == null) {
      return;
    }
    final displayedWeek = _actualWeek < 1 ? 1 : _actualWeek;
    if (displayedWeek == _displayedWeek) {
      return;
    }
    setState(() {
      _displayedWeek = displayedWeek;
      _selectedManualSlot = null;
    });
  }

  @override
  void dispose() {
    _weekTimer?.cancel();
    super.dispose();
  }
}

enum _ManualCourseAction { edit, delete }

enum _CourseDeleteScope { singleOccurrence, allWeeksInSlot, allCourseSlots }

int _displayableWeek(int activeWeek, AcademicSchedule schedule) =>
    activeWeek.clamp(1, schedule.maxWeek);

class _FirstWeekDatePickerDialog extends StatefulWidget {
  const _FirstWeekDatePickerDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_FirstWeekDatePickerDialog> createState() =>
      _FirstWeekDatePickerDialogState();
}

class _FirstWeekDatePickerDialogState
    extends State<_FirstWeekDatePickerDialog> {
  late DateTime _selectedDate = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  '选择开学日期',
                  style: ShuYoTextStyles.sectionTitle(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              CalendarDatePicker(
                initialDate: widget.initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100, 12, 31),
                selectableDayPredicate: (date) =>
                    date.weekday == DateTime.monday,
                onDateChanged: (date) => setState(() => _selectedDate = date),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSlot {
  const _ScheduleSlot({required this.weekday, required this.section});

  final int weekday;
  final int section;

  @override
  bool operator ==(Object other) {
    return other is _ScheduleSlot &&
        other.weekday == weekday &&
        other.section == section;
  }

  @override
  int get hashCode => Object.hash(weekday, section);
}

CourseSession _courseSessionFromDraft(
  ScheduleCourseTimeDraft draft, {
  required int weekday,
  CourseSession? base,
  required String courseName,
  required String courseCode,
  required String credit,
  bool forceNewId = false,
}) {
  final sections = [
    for (
      var section = draft.startSection;
      section <= draft.endSection;
      section++
    )
      section,
  ];
  final weeks = [...draft.weeks]..sort();
  return CourseSession(
    id: !forceNewId && base != null
        ? base.id
        : '${CourseSession.manualIdPrefix}$weekday:'
              '${draft.startSection}-${draft.endSection}:'
              '${DateTime.now().microsecondsSinceEpoch}',
    courseName: courseName,
    courseCode: courseCode,
    teacherName: draft.teacherName,
    campus: base?.campus ?? '',
    location: draft.location,
    weekday: weekday,
    startSection: draft.startSection,
    endSection: draft.endSection,
    sections: sections,
    weeks: weeks,
    weekText: _formatWeekText(weeks),
    credit: credit,
    note: draft.note,
  );
}

bool _sameCourseIdentity(CourseSession session, CourseSession target) {
  return session.id == target.id &&
      session.weekday == target.weekday &&
      session.startSection == target.startSection &&
      session.endSection == target.endSection;
}

bool _sameCourse(CourseSession session, CourseSession target) {
  final sessionCode = session.courseCode.trim();
  final targetCode = target.courseCode.trim();
  if (!session.isManual &&
      !target.isManual &&
      sessionCode.isNotEmpty &&
      targetCode.isNotEmpty) {
    return sessionCode == targetCode;
  }
  return session.courseName.trim() == target.courseName.trim();
}

bool _sameCourseSlot(CourseSession session, CourseSession target) {
  return session.weekday == target.weekday &&
      session.startSection == target.startSection &&
      session.endSection == target.endSection;
}

CourseSession _copySessionWithWeeks(CourseSession session, List<int> weeks) {
  final sorted = [...weeks]..sort();
  return CourseSession(
    id: session.id,
    courseName: session.courseName,
    courseCode: session.courseCode,
    teacherName: session.teacherName,
    campus: session.campus,
    location: session.location,
    weekday: session.weekday,
    startSection: session.startSection,
    endSection: session.endSection,
    sections: session.sections,
    weeks: sorted,
    weekText: _formatWeekText(sorted),
    credit: session.credit,
    note: session.note,
  );
}

bool _sectionRangesOverlap(int startA, int endA, int startB, int endB) {
  return startA <= endB && startB <= endA;
}

bool _timeDraftsOverlap(ScheduleCourseTimeDraft a, ScheduleCourseTimeDraft b) {
  if (a.weekday != b.weekday ||
      !_sectionRangesOverlap(
        a.startSection,
        a.endSection,
        b.startSection,
        b.endSection,
      )) {
    return false;
  }
  final weeksA = a.weeks.toSet();
  final weeksB = b.weeks.toSet();
  return weeksA.isEmpty || weeksB.isEmpty || weeksA.any(weeksB.contains);
}

String _formatDraftTime(ScheduleCourseTimeDraft draft) {
  return '${_weekdayName(draft.weekday)} 第${draft.startSection}-${draft.endSection}节 '
      '（${_formatWeekText(draft.weeks)}）';
}

String _formatSessionTime(CourseSession session) {
  return '${_weekdayName(session.weekday)} ${session.sectionText} '
      '（${session.weekText.isEmpty ? _formatWeekText(session.weeks) : session.weekText}）';
}

String _formatWeekText(List<int> weeks) {
  if (weeks.isEmpty) {
    return '';
  }
  final sorted = [...weeks]..sort();
  final ranges = <String>[];
  var start = sorted.first;
  var previous = sorted.first;
  for (final week in sorted.skip(1)) {
    if (week == previous + 1) {
      previous = week;
      continue;
    }
    ranges.add(start == previous ? '$start周' : '$start-$previous周');
    start = week;
    previous = week;
  }
  ranges.add(start == previous ? '$start周' : '$start-$previous周');
  return ranges.join(',');
}

class _ScheduleBody extends StatefulWidget {
  const _ScheduleBody({
    super.key,
    required this.document,
    required this.schedule,
    required this.maxDisplayWeek,
    required this.minDisplayWeek,
    required this.weekState,
    required this.displayedWeek,
    required this.displaySettings,
    required this.courseColorValues,
    required this.onQuickWeekSelected,
    required this.selectedManualSlot,
    required this.canAddCourse,
    required this.onEmptySlotTap,
    required this.onCourseTap,
    required this.onVisibleDaysChanged,
  });
  final AcademicSchedule schedule;
  final ScheduleDocument document;
  final int maxDisplayWeek;
  final int minDisplayWeek;
  final ScheduleWeekState weekState;
  final int displayedWeek;
  final AcademicScheduleDisplaySettings displaySettings;
  final Map<String, int> courseColorValues;
  final ValueChanged<int> onQuickWeekSelected;
  final _ScheduleSlot? selectedManualSlot;
  final bool canAddCourse;
  final ValueChanged<_ScheduleSlot> onEmptySlotTap;
  final ValueChanged<CourseSession> onCourseTap;
  final ValueChanged<int> onVisibleDaysChanged;

  @override
  State<_ScheduleBody> createState() => _ScheduleBodyState();
}

// Fractional widths exist only during pinch animation: never retain those trees.
Widget _cachedSchedulePage(
  Map<(int, double, int), Widget> pages,
  int week,
  double days,
  int firstDay,
  Widget Function() build,
) {
  if (days != 5 && days != 7) return build();
  pages.removeWhere((key, _) => key.$2 != days || key.$3 != firstDay);
  return pages.putIfAbsent((week, days, firstDay), build);
}

class _ScheduleBodyState extends State<_ScheduleBody> {
  final _pages = <(int, double, int), Widget>{};
  late ScheduleWeekIndex _index = ScheduleWeekIndex.forDocument(
    widget.document,
  );
  @override
  void didUpdateWidget(covariant _ScheduleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document ||
        oldWidget.displaySettings != widget.displaySettings ||
        oldWidget.courseColorValues != widget.courseColorValues ||
        oldWidget.weekState != widget.weekState ||
        oldWidget.selectedManualSlot != widget.selectedManualSlot ||
        oldWidget.canAddCourse != widget.canAddCourse) {
      _pages.clear();
    }
    _pages.removeWhere((key, _) => (key.$1 - widget.displayedWeek).abs() > 2);
    if (!identical(oldWidget.document, widget.document)) {
      _index = ScheduleWeekIndex.forDocument(widget.document);
    }
  }

  @override
  Widget build(BuildContext context) => ScheduleGesturePager(
    week: widget.displayedWeek,
    maxWeek: widget.maxDisplayWeek,
    minWeek: widget.minDisplayWeek,
    showControls: widget.displaySettings.showControls,
    visibleDays: widget.displaySettings.visibleDays,
    onWeekChanged: widget.onQuickWeekSelected,
    onVisibleDaysChanged: widget.onVisibleDaysChanged,
    builder: (context, week, days, firstDay) =>
        _cachedSchedulePage(_pages, week, days, firstDay, () {
          final data = _index.week(week, widget.displaySettings.showOtherWeeks);
          final sessions = data.sessions;
          final weekdays = [for (var d = firstDay; d <= 7; d++) d];
          final untimed = data.untimed;
          return RepaintBoundary(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      _ScheduleGrid.leftWidth +
                      (constraints.maxWidth - _ScheduleGrid.leftWidth) /
                          days *
                          weekdays.length;
                  return SingleChildScrollView(
                    key: PageStorageKey(
                      'academic-schedule-vertical-scroll-$week',
                    ),
                    child: Column(
                      children: [
                        ClipRect(
                          child: SizedBox(
                            height:
                                _ScheduleGrid._headerHeight +
                                _ScheduleGrid._sectionCount *
                                    _ScheduleGrid._rowHeight,
                            child: OverflowBox(
                              alignment: Alignment.topLeft,
                              minWidth: width,
                              maxWidth: width,
                              child: _ScheduleGrid(
                                adjustments: widget.document.adjustments,
                                sessions: sessions,
                                maxWeek: widget.schedule.maxWeek,
                                occupied: data.occupied,
                                weekdays: weekdays,
                                weekState: widget.weekState,
                                displayedWeek: week,
                                displaySettings: widget.displaySettings,
                                courseColorValues: widget.courseColorValues,
                                selectedManualSlot: widget.selectedManualSlot,
                                canAddCourse: widget.canAddCourse,
                                onEmptySlotTap: widget.onEmptySlotTap,
                                onCourseTap: widget.onCourseTap,
                              ),
                            ),
                          ),
                        ),
                        if (untimed.isNotEmpty)
                          _UntimedCourseList(
                            courses: untimed,
                            displayedWeek: week,
                            displaySettings: widget.displaySettings,
                            maxWeek: widget.schedule.maxWeek,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }),
  );
}

class _ComparisonBody extends StatefulWidget {
  const _ComparisonBody({
    required this.documents,
    required this.selection,
    required this.week,
    required this.minWeek,
    required this.maxWeek,
    required this.firstWeek,
    required this.settings,
    required this.onWeek,
    required this.onDays,
  });
  final List<ScheduleDocument> documents;
  final TimetableComparisonSelection selection;
  final int week, minWeek, maxWeek;
  final DateTime firstWeek;
  final AcademicScheduleDisplaySettings settings;
  final ValueChanged<int> onWeek, onDays;
  @override
  State<_ComparisonBody> createState() => _ComparisonBodyState();
}

class _ComparisonBodyState extends State<_ComparisonBody> {
  final _pages = <(int, double, int), Widget>{};
  @override
  void didUpdateWidget(covariant _ComparisonBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.firstWeek != widget.firstWeek ||
        oldWidget.documents.length != widget.documents.length ||
        List.generate(
          widget.documents.length,
          (i) => i,
        ).any((i) => oldWidget.documents[i] != widget.documents[i])) {
      _pages.clear();
    }
    _pages.removeWhere((key, _) => (key.$1 - widget.week).abs() > 2);
  }

  @override
  Widget build(BuildContext context) => ScheduleGesturePager(
    week: widget.week,
    minWeek: widget.minWeek,
    maxWeek: widget.maxWeek,
    visibleDays: widget.settings.visibleDays,
    onWeekChanged: widget.onWeek,
    onVisibleDaysChanged: widget.onDays,
    showControls: widget.settings.showControls,
    builder: (context, week, days, firstDay) => _cachedSchedulePage(
      _pages,
      week,
      days,
      firstDay,
      () => RepaintBoundary(
        child: ComparisonWeekGrid(
          documents: widget.documents,
          monday: DateTime(
            widget.firstWeek.year,
            widget.firstWeek.month,
            widget.firstWeek.day + (week - 1) * 7,
          ),
          mode: widget.selection.mode,
          days: days,
          firstDay: firstDay,
        ),
      ),
    ),
  );
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.adjustments,
    required this.sessions,
    required this.maxWeek,
    required this.occupied,
    required this.weekdays,
    required this.weekState,
    required this.displayedWeek,
    required this.displaySettings,
    required this.courseColorValues,
    required this.selectedManualSlot,
    required this.canAddCourse,
    required this.onEmptySlotTap,
    required this.onCourseTap,
  });

  final int maxWeek;
  final List<ScheduleAdjustment> adjustments;
  static const leftWidth = 38.0;
  static const _headerHeight = 54.0;
  static const _rowHeight = 72.0;
  static const _sectionCount = 12;

  final List<CourseSession> sessions;
  final Set<(int, int)> occupied;
  final List<int> weekdays;
  final ScheduleWeekState weekState;
  final int displayedWeek;
  final AcademicScheduleDisplaySettings displaySettings;
  final Map<String, int> courseColorValues;
  final _ScheduleSlot? selectedManualSlot;
  final bool canAddCourse;
  final ValueChanged<_ScheduleSlot> onEmptySlotTap;
  final ValueChanged<CourseSession> onCourseTap;

  int _sourceWeek(int day) {
    final first = weekState.firstWeekStart;
    final date = DateTime(
      first.year,
      first.month,
      first.day + (displayedWeek - 1) * 7 + day - 1,
    );
    for (final rule in adjustments) {
      if (rule.date == date) return rule.sourceWeek;
    }
    return displayedWeek;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = (constraints.maxWidth - leftWidth) / weekdays.length;
        final height = _headerHeight + _sectionCount * _rowHeight;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              _GridBackground(
                adjustments: adjustments,
                sessions: sessions,
                occupied: occupied,
                showGrid: displaySettings.showGrid,
                weekdays: weekdays,
                dayWidth: dayWidth,
                leftWidth: leftWidth,
                headerHeight: _headerHeight,
                rowHeight: _rowHeight,
                sectionCount: _sectionCount,
                weekState: weekState,
                displayedWeek: displayedWeek,
                selectedManualSlot: selectedManualSlot,
                canAddCourse: canAddCourse,
                onEmptySlotTap: onEmptySlotTap,
              ),
              for (final session in sessions)
                if (weekdays.contains(session.weekday))
                  Positioned(
                    left:
                        leftWidth +
                        weekdays.indexOf(session.weekday) * dayWidth +
                        _scheduleCourseInset,
                    top:
                        _headerHeight +
                        (session.startSection - 1) * _rowHeight +
                        _scheduleCourseInset,
                    width: dayWidth - _scheduleCourseInset * 2,
                    height:
                        (session.endSection - session.startSection + 1) *
                            _rowHeight -
                        _scheduleCourseInset * 2,
                    child: _CourseBlock(
                      session: session,
                      maxWeek: maxWeek,
                      isCurrentWeek: session.occursInWeek(
                        _sourceWeek(session.weekday),
                      ),
                      displaySettings: displaySettings,
                      courseColorValues: courseColorValues,
                      onTap: () => onCourseTap(session),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground({
    required this.adjustments,
    required this.sessions,
    required this.showGrid,
    required this.occupied,
    required this.weekdays,
    required this.dayWidth,
    required this.leftWidth,
    required this.headerHeight,
    required this.rowHeight,
    required this.sectionCount,
    required this.weekState,
    required this.displayedWeek,
    required this.selectedManualSlot,
    required this.canAddCourse,
    required this.onEmptySlotTap,
  });

  final bool showGrid;
  final List<ScheduleAdjustment> adjustments;
  final List<CourseSession> sessions;
  final Set<(int, int)> occupied;
  final List<int> weekdays;
  final double dayWidth;
  final double leftWidth;
  final double headerHeight;
  final double rowHeight;
  final int sectionCount;
  final ScheduleWeekState weekState;
  final int displayedWeek;
  final _ScheduleSlot? selectedManualSlot;
  final bool canAddCourse;
  final ValueChanged<_ScheduleSlot> onEmptySlotTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: leftWidth,
          height: headerHeight,
          child: Center(
            child: Text(
              const [
                '一月',
                '二月',
                '三月',
                '四月',
                '五月',
                '六月',
                '七月',
                '八月',
                '九月',
                '十月',
                '十一月',
                '十二月',
              ][weekState.anchorMonday
                      .add(
                        Duration(
                          days: (displayedWeek - weekState.currentWeek) * 7,
                        ),
                      )
                      .month -
                  1],
              key: const ValueKey('week-month'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.shuyoColors.textSecondary,
              ),
            ),
          ),
        ),
        for (var index = 0; index < weekdays.length; index++)
          Positioned(
            left: leftWidth + index * dayWidth,
            top: 0,
            width: dayWidth,
            height: headerHeight,
            child: _DayHeader(
              adjustments: adjustments,
              weekday: weekdays[index],
              date: weekState.anchorMonday.add(
                Duration(
                  days:
                      (displayedWeek - weekState.currentWeek) * 7 +
                      weekdays[index] -
                      1,
                ),
              ),
            ),
          ),
        for (var section = 1; section <= sectionCount; section++)
          Positioned(
            left: 0,
            right: 0,
            top: headerHeight + (section - 1) * rowHeight,
            height: rowHeight,
            child: Row(
              children: [
                SizedBox(
                  width: leftWidth,
                  child: _SectionLabel(section: section),
                ),
                for (var index = 0; index < weekdays.length; index++)
                  SizedBox(
                    width: dayWidth,
                    child: _EmptyScheduleCell(
                      showGrid: showGrid,
                      slot: _ScheduleSlot(
                        weekday: weekdays[index],
                        section: section,
                      ),
                      enabled:
                          canAddCourse &&
                          !_hasCourseAt(weekdays[index], section),
                      selected:
                          selectedManualSlot ==
                          _ScheduleSlot(
                            weekday: weekdays[index],
                            section: section,
                          ),
                      onTap: onEmptySlotTap,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _hasCourseAt(int weekday, int section) =>
      occupied.contains((weekday, section));
}

class _EmptyScheduleCell extends StatelessWidget {
  const _EmptyScheduleCell({
    required this.slot,
    required this.showGrid,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final _ScheduleSlot slot;
  final bool showGrid;
  final bool enabled;
  final bool selected;
  final ValueChanged<_ScheduleSlot> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    return Padding(
      padding: const EdgeInsets.all(_scheduleCellInset),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onTap(slot) : null,
        child: DecoratedBox(
          key: ValueKey('grid-cell-${slot.weekday}-${slot.section}'),
          decoration: BoxDecoration(
            color: showGrid ? colors.scheduleEmptyCell : Colors.transparent,
            borderRadius: BorderRadius.circular(_scheduleCellRadius),
          ),
          child: Center(
            child: AnimatedOpacity(
              opacity: selected && enabled ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Icon(Icons.add, size: 22, color: colors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTimesScope extends InheritedWidget {
  const SectionTimesScope({
    super.key,
    required this.times,
    required super.child,
  });
  final List<List<int>> times;
  @override
  bool updateShouldNotify(SectionTimesScope oldWidget) =>
      times != oldWidget.times;
  static String text(BuildContext context, int section) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SectionTimesScope>();
    if (scope == null) {
      return AcademicScheduleRepository.sectionTimeText(section);
    }
    final t = scope.times[section - 1];
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(t[0])}:${pad(t[1])}\n${pad(t[2])}:${pad(t[3])}';
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.weekday,
    required this.date,
    this.adjustments = const [],
  });
  final List<ScheduleAdjustment> adjustments;
  final int weekday;
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    final today = DateUtils.isSameDay(date, DateTime.now());
    final rules = adjustments.where((a) => DateUtils.isSameDay(a.date, date));
    final rule = rules.isEmpty ? null : rules.first;
    return Tooltip(
      message: rule?.label ?? '',
      child: Semantics(
        label: '${date.year}年${date.month}月${date.day}日${today ? '，今天' : ''}',
        child: Container(
          key: today ? const ValueKey('today-header') : null,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: today ? colors.accent.withValues(alpha: .12) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_weekdayName(weekday)}${rule == null ? '' : '·调'}',
                    maxLines: 1,
                    style: TextStyle(
                      color: today ? colors.accent : colors.textPrimary,
                      fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${date.month}/${date.day}',
                    maxLines: 1,
                    style: TextStyle(
                      color: today ? colors.accent : colors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.section});
  final int section;
  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$section',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                SectionTimesScope.text(context, section),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 9.5,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.session,
    required this.maxWeek,
    required this.isCurrentWeek,
    required this.displaySettings,
    required this.courseColorValues,
    required this.onTap,
  });

  final CourseSession session;
  final int maxWeek;
  final bool isCurrentWeek;
  final AcademicScheduleDisplaySettings displaySettings;
  final Map<String, int> courseColorValues;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    final rawFill = displaySettings.colorful
        ? (courseColorValues[_courseColorSeed(session)] == null
              ? _courseColorForSession(context, session)
              : Color(courseColorValues[_courseColorSeed(session)]!))
        : colors.scheduleCourseFill;
    final opaqueFill = Color.alphaBlend(rawFill, colors.background);
    final fillColor = isCurrentWeek
        ? opaqueFill
        : Color.lerp(colors.background, opaqueFill, .38)!;
    final courseTextColor = displaySettings.colorful
        ? const Color(0xFFFFFFFF)
        : colors.scheduleCourseText;
    final metaTextColor = displaySettings.colorful
        ? const Color(0xD9FFFFFF)
        : colors.scheduleCourseMetaText;
    return RepaintBoundary(
      key: ValueKey('course-${session.id}'),
      child: Semantics(
        button: true,
        label:
            '${isCurrentWeek ? '' : '非本周，'}${session.courseName}，${session.sectionText}，${session.location}',
        child: Material(
          key: ValueKey('course-fill-${session.id}'),
          color: fillColor,
          borderRadius: BorderRadius.circular(_scheduleCourseRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_scheduleCourseRadius),
            onTap: onTap,
            child: AdaptiveCourseText(
              title: session.courseName,
              metadata: [
                if (displaySettings.showCourseCode) session.displayCourseCode,
                if (displaySettings.showTeacher) session.teacherName,
                session.location,
                if (showCourseWeeks(
                  displaySettings.courseWeekDisplay,
                  isCurrentWeek,
                ))
                  courseWeeksLabel(session.weeks, maxWeek),
                if (displaySettings.showCredit)
                  courseCreditLabel(session.credit),
              ],
              titleColor: isCurrentWeek
                  ? courseTextColor
                  : Color.lerp(fillColor, courseTextColor, .68)!,
              metaColor: isCurrentWeek
                  ? metaTextColor
                  : Color.lerp(fillColor, metaTextColor, .68)!,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _UntimedCourseList extends StatelessWidget {
  const _UntimedCourseList({
    required this.courses,
    required this.displayedWeek,
    required this.displaySettings,
    required this.maxWeek,
  });
  final AcademicScheduleDisplaySettings displaySettings;
  final int maxWeek;
  final int displayedWeek;

  final List<UntimedCourse> courses;

  @override
  Widget build(BuildContext context) {
    final colors = context.shuyoColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in courses)
            Opacity(
              opacity: c.occursInWeek(displayedWeek) ? 1 : .38,
              child: Text(
                '其它课程：${_formatUntimedCourse(c)}${c.occursInWeek(displayedWeek) ? '' : '（非本周）'}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatUntimedCourse(UntimedCourse course) {
    return [
      course.courseName,
      if (displaySettings.showCourseCode) course.courseCode,
      if (displaySettings.showTeacher) course.teacherName,
      course.campus,
      if (showCourseWeeks(
        displaySettings.courseWeekDisplay,
        course.occursInWeek(displayedWeek),
      ))
        courseWeeksLabel(course.weeks, maxWeek),
      if (displaySettings.showCredit) courseCreditLabel(course.credit),
    ].where((v) => v.trim().isNotEmpty).join(' · ');
  }
}

class _ScheduleErrorState extends StatelessWidget {
  const _ScheduleErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: '课表加载失败',
      message: message,
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('重试'),
      ),
    );
  }
}

String _weekdayName(int weekday) {
  return switch (weekday) {
    1 => '周一',
    2 => '周二',
    3 => '周三',
    4 => '周四',
    5 => '周五',
    6 => '周六',
    7 => '周日',
    _ => '',
  };
}

Color _courseColor(BuildContext context, String seed) {
  final colors = context.shuyoColors.schedulePalette;
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash + unit) & 0x7fffffff;
  }
  return colors[hash % colors.length];
}

Color _courseColorForSession(BuildContext context, CourseSession session) {
  return _courseColor(context, _courseColorSeed(session));
}

String _courseColorSeed(CourseSession session) {
  final code = session.courseCode.trim();
  if (!session.isManual && code.isNotEmpty) {
    return code;
  }
  return session.courseName.trim();
}
