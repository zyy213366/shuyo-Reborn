# Lightweight Schedule Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver an Android-only, local-first SHU timetable with a seven-day viewport, independent schedules, school import and file sharing.

**Architecture:** Extract upstream schedule models, theme and editor into a small Flutter shell. Store versioned schedule documents independently; use a bounded, validated interchange codec and native Android document/share intents. Keep school authentication inside a WebView with same-origin timetable extraction.

**Tech Stack:** Flutter/Dart, shared_preferences, webview_flutter, Android Kotlin document provider intents.

---

### Task 1: Build environment and extracted baseline
Files: pubspec.yaml, lib/data/models/academic_schedule.dart, lib/shared/, android/, LICENSE, NOTICE.md.
1. Install project-local Flutter and Android tooling if absent.
2. Copy only required upstream schedule files and license. Scaffold Android with separate package ID.
3. Add test/widget_test.dart demonstrating seven-day visibility and no account entry on launch.
4. Run flutter test test/widget_test.dart, verify the existing five-column viewport fails.

### Task 2: Local schedule documents and interchange
Files: lib/data/schedule_store.dart, lib/data/schedule_document.dart, test/schedule_store_test.dart.
1. Test creation, rename, restart, deep copy and deletion.
2. Test versioned export/import, identity stripping, malformed input, deduplication, conflicts and different term settings.
3. Implement serial persistence with immutable snapshots and a validated codec; validate counts and bounds before saving.
4. Run flutter test test/schedule_store_test.dart until passing.

### Task 3: Seven-day timetable and management UI
Files: lib/main.dart, lib/features/home/academic_schedule_page.dart, lib/features/schedule_home.dart, test/widget_test.dart.
1. Reuse upstream theme, editor, details and grid; remove unrelated services.
2. Fit seven weekday columns into available width; adapt short course blocks and accessible headers.
3. Add sheet for schedule management and new/duplicate/rename/delete flows.
4. Validate all seven headers and Sunday course are in view at 320, 360 and 412 logical pixels; test text scaling and copies.

### Task 4: Sharing and import preview
Files: lib/services/schedule_files.dart, lib/features/import_preview.dart, android/app/src/main/kotlin/.../MainActivity.kt, AndroidManifest.xml, res/xml/file_paths.xml.
1. Test preview leaves storage unchanged until explicit import and targets chosen document.
2. Implement bounded ACTION_VIEW/ACTION_SEND content reads and ACTION_OPEN_DOCUMENT; grant URI access only to exported file.
3. Share .shuyoschedule.json through ACTION_SEND; receive both cold and warm launch with queued intent handling.
4. Exercise round-trip using Android intents and unit/widget tests.

### Task 5: Shanghai University WebView import
Files: lib/features/school_import.dart, lib/services/shu_import_script.dart, test/shu_import_test.dart.
1. Test parser against upstream anonymized academic fixture and error responses.
2. Open official school or WebVPN login page, navigate to course page and fetch timetable with page-session credentials.
3. Scope JS bridge to allowed school origins; validate resulting document and preview before persistence. Clear session when leaving import.
4. Validate error/cancel handling and Android WebView; document real-account test limitation.

### Task 6: Verification and delivery
Files: README.md, docs/verification.md, build/app/outputs/flutter-apk/.
1. Run flutter analyze and flutter test; fix actual failures.
2. Build installable Android APK; test on available Android emulator.
3. Perform code review of persistence, external inputs and share intent lifecycle.
4. Document build commands, source attribution, artifacts and measured verification limits.
