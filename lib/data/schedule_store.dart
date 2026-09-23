import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/academic_schedule.dart';
import 'schedule_document.dart';
import 'appearance_settings.dart';
export 'schedule_document.dart';

String newScheduleId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class ScheduleStore extends ChangeNotifier {
  ScheduleStore({Future<SharedPreferences> Function()? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;
  static const storageKey = 'qing_schedule.documents.v1';
  final Future<SharedPreferences> Function() _preferencesLoader;
  List<ScheduleDocument> _documents = [];
  String? _activeId;
  AppearanceSettings _appearance = const AppearanceSettings();
  double? _previewPopupOpacity;
  AppearanceSettings get appearance => _previewPopupOpacity == null
      ? _appearance
      : _appearance.copyWith(popupOpacity: _previewPopupOpacity);
  void previewPopupOpacity(double? value) {
    _previewPopupOpacity = value?.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> _pending = Future.value();
  List<ScheduleDocument> get documents => List.unmodifiable(_documents);
  ScheduleDocument get active => byId(_activeId!);
  ScheduleDocument byId(String id) => _documents.firstWhere((d) => d.id == id);

  Future<T> _serial<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> load() => _serial(() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) throw const FormatException('不支持的本地数据版本');
      final docs = (data['documents'] as List)
          .map((j) => ScheduleDocument.fromJson(j as Map<String, dynamic>))
          .toList();
      if (docs.isEmpty ||
          docs.map((d) => d.id).toSet().length != docs.length ||
          !docs.any((d) => d.id == data['activeId'])) {
        throw const FormatException('课表索引无效');
      }
      _documents = docs;
      _activeId = data['activeId'] as String;
      _appearance = AppearanceSettings.fromJson(
        data['appearance'] as Map<String, dynamic>? ?? const {},
      );
      notifyListeners();
    } catch (_) {
      throw const FormatException('本地课表读取失败。原始数据已保留，请勿清除应用数据。');
    }
  });

  Future<void> _save(
    List<ScheduleDocument> docs,
    String activeId, {
    AppearanceSettings? appearance,
  }) async {
    for (final d in docs) {
      ScheduleCodec.validateDocument(d.toJson());
    }
    final raw = jsonEncode({
      'version': 1,
      'activeId': activeId,
      'appearance': (appearance ?? _appearance).toJson(),
      'documents': docs.map((d) => d.toJson()).toList(),
    });
    final prefs = await _preferencesLoader();
    try {
      if (!await prefs.setString(storageKey, raw)) {
        throw StateError('课表保存失败，请检查手机存储空间后重试');
      }
    } catch (_) {
      // The legacy preferences plugin changes its cache before persisting.
      // Reload the disk value so a failed write cannot reappear on next load.
      await prefs.reload();
      rethrow;
    }
    _documents = docs;
    _activeId = activeId;
    if (appearance != null) _appearance = appearance;
    notifyListeners();
  }

  Future<ScheduleDocument> create(
    String name, {
    AcademicSchedule? schedule,
    DateTime? firstWeekStart,
  }) => _serial(() async {
    final doc = ScheduleDocument(
      id: newScheduleId(),
      name: name.trim(),
      schedule: schedule ?? emptySchedule(),
      firstWeekStart: firstWeekStart ?? DateTime.now(),
    );
    await _save([..._documents, doc], doc.id);
    return doc;
  });

  Future<ScheduleDocument> addImported(ScheduleDocument source) =>
      _serial(() async {
        final doc = source.copyWith(id: newScheduleId());
        await _save([..._documents, doc], doc.id);
        return doc;
      });

  Future<ScheduleDocument> duplicate(String id) => _serial(() async {
    final original = byId(id);
    final doc = original.copyWith(
      id: newScheduleId(),
      name: '${original.name.substring(0, min(70, original.name.length))} 副本',
    );
    await _save([..._documents, doc], doc.id);
    return doc;
  });

  Future<void> select(String id) => _serial(() async {
    byId(id);
    await _save(_documents, id);
  });
  Future<void> setAppearance(AppearanceSettings settings) => _serial(() async {
    await _save(_documents, _activeId!, appearance: settings);
  });
  Future<void> update(ScheduleDocument doc) => mutate(doc.id, (_) => doc);
  Future<void> mutate(
    String id,
    ScheduleDocument Function(ScheduleDocument) change, {
    bool selectAfter = false,
  }) => _serial(() async {
    final doc = change(byId(id));
    if (doc.id != id) throw ArgumentError('课表标识不可更改');
    await _save([
      for (final d in _documents)
        if (d.id == id) doc else d,
    ], selectAfter ? id : _activeId!);
  });

  Future<void> delete(String id) => _serial(() async {
    byId(id);
    final next = _documents.where((d) => d.id != id).toList();
    if (next.isEmpty) {
      next.add(
        ScheduleDocument(
          id: newScheduleId(),
          name: '我的课表',
          schedule: emptySchedule(),
          firstWeekStart: DateTime.now(),
        ),
      );
    }
    await _save(next, _activeId == id ? next.first.id : _activeId!);
  });
}

class ScheduleMerge {
  ScheduleMerge(this.document, this.added, this.duplicates, this.conflicts);
  final ScheduleDocument document;
  final int added;
  final int duplicates;
  final List<String> conflicts;

  static ScheduleMerge preview(
    ScheduleDocument target,
    ScheduleDocument source,
  ) {
    if (target.firstWeekStart != source.firstWeekStart ||
        jsonEncode(target.sectionTimes) != jsonEncode(source.sectionTimes)) {
      throw const FormatException('两张课表的开学日期或作息不同，请新建课表，或先调整为相同设置。');
    }
    String signature(Map<String, dynamic> value) {
      final result = Map<String, dynamic>.of(value)
        ..remove('id')
        ..remove('weekText');
      result['weeks'] = (List<int>.from(value['weeks'] as List)..sort());
      return jsonEncode(result);
    }

    final sessions = [...target.schedule.sessions];
    final untimed = [...target.schedule.untimedCourses];
    final known = {
      for (final s in sessions) signature(s.toJson()),
      for (final s in untimed) signature(s.toJson()),
    };
    var added = 0;
    var duplicates = 0;
    final conflicts = <String>{};
    for (final incoming in source.schedule.sessions) {
      if (!known.add(signature(incoming.toJson()))) {
        duplicates++;
        continue;
      }
      for (final existing in sessions) {
        if (existing.weekday == incoming.weekday &&
            existing.startSection <= incoming.endSection &&
            incoming.startSection <= existing.endSection &&
            (existing.weeks.isEmpty ||
                incoming.weeks.isEmpty ||
                existing.weeks.any(incoming.weeks.contains))) {
          conflicts.add(
            '${incoming.courseName} 与 ${existing.courseName}：周${incoming.weekday} ${incoming.sectionText}',
          );
        }
      }
      sessions.add(
        CourseSession.fromJson(
          incoming.toJson()..['id'] = 'import:${newScheduleId()}',
        ),
      );
      added++;
    }
    for (final s in source.schedule.untimedCourses) {
      if (!known.add(signature(s.toJson()))) {
        duplicates++;
        continue;
      }
      untimed.add(
        UntimedCourse.fromJson(
          s.toJson()..['id'] = 'import:${newScheduleId()}',
        ),
      );
      added++;
    }
    final merged = target.copyWith(
      schedule: target.schedule.copyWith(
        sessions: sessions,
        untimedCourses: untimed,
      ),
      colors: {...source.colors, ...target.colors},
    );
    ScheduleCodec.validateDocument(merged.toJson());
    return ScheduleMerge(merged, added, duplicates, conflicts.toList());
  }
}
