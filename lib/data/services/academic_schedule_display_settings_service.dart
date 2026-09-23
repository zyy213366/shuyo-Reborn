export '../course_labels.dart';

import '../schedule_store.dart';

class AcademicScheduleDisplaySettings {
  const AcademicScheduleDisplaySettings({
    required this.colorful,
    required this.showTeacher,
    this.showOtherWeeks = false,
    this.showCourseCode = false,
    this.visibleDays = 7,
    this.showGrid = true,
    this.showControls = true,
    this.showCredit = false,
    this.courseWeekDisplay = CourseWeekDisplay.none,
  });

  final bool colorful;
  final bool showTeacher;
  final bool showOtherWeeks;
  final bool showCourseCode;
  final int visibleDays;
  final bool showGrid;
  final bool showControls;
  final bool showCredit;
  final CourseWeekDisplay courseWeekDisplay;

  AcademicScheduleDisplaySettings copyWith({
    bool? colorful,
    bool? showTeacher,
    bool? showOtherWeeks,
    bool? showCourseCode,
    int? visibleDays,
    bool? showGrid,
    bool? showControls,
    bool? showCredit,
    CourseWeekDisplay? courseWeekDisplay,
  }) {
    return AcademicScheduleDisplaySettings(
      colorful: colorful ?? this.colorful,
      showTeacher: showTeacher ?? this.showTeacher,
      showOtherWeeks: showOtherWeeks ?? this.showOtherWeeks,
      showCourseCode: showCourseCode ?? this.showCourseCode,
      visibleDays: visibleDays ?? this.visibleDays,
      showGrid: showGrid ?? this.showGrid,
      showControls: showControls ?? this.showControls,
      showCredit: showCredit ?? this.showCredit,
      courseWeekDisplay: courseWeekDisplay ?? this.courseWeekDisplay,
    );
  }
}

class AcademicScheduleDisplayState {
  const AcademicScheduleDisplayState({
    required this.settings,
    required this.courseColorValues,
  });

  final AcademicScheduleDisplaySettings settings;
  final Map<String, int> courseColorValues;
}

class AcademicScheduleDisplaySettingsService {
  AcademicScheduleDisplaySettingsService({
    required this.store,
    required this.documentId,
  });
  final ScheduleStore store;
  final String documentId;
  Future<AcademicScheduleDisplayState> loadState() async => currentState;

  AcademicScheduleDisplayState get currentState {
    final d = store.byId(documentId);
    return AcademicScheduleDisplayState(
      settings: AcademicScheduleDisplaySettings(
        colorful: d.colorful,
        showTeacher: d.showTeacher,
        showOtherWeeks: d.showOtherWeeks,
        showCourseCode: d.showCourseCode,
        visibleDays: d.visibleDays,
        showGrid: d.showGrid,
        showControls: d.showControls,
        showCredit: d.showCredit,
        courseWeekDisplay: d.courseWeekDisplay,
      ),
      courseColorValues: d.colors,
    );
  }

  Future<AcademicScheduleDisplaySettings> saveSettings(
    AcademicScheduleDisplaySettings settings,
  ) async {
    await store.mutate(
      documentId,
      (d) => d.copyWith(
        colorful: settings.colorful,
        showTeacher: settings.showTeacher,
        showOtherWeeks: settings.showOtherWeeks,
        showCourseCode: settings.showCourseCode,
        visibleDays: settings.visibleDays,
        showGrid: settings.showGrid,
        showControls: settings.showControls,
        showCredit: settings.showCredit,
        courseWeekDisplay: settings.courseWeekDisplay,
      ),
    );
    return settings;
  }

  Future<void> saveCourseColor(String key, int value) => store.mutate(
    documentId,
    (d) => d.copyWith(colors: {...d.colors, key: value}),
  );
}
