# Exams, Adjustments and Paging Implementation Plan

**Goal:** 补齐独立考试、手动调休、连续翻页，并交付两端构建。

**Architecture:** 扩展现有 ScheduleDocument，共享日期解析服务。Flutter 页面与数据跨 Android/OHOS 复用，原生桥接保持不变。

**Tech Stack:** Flutter / Dart、SharedPreferences、Android Gradle、Flutter OHOS / ArkTS。

1. 修复迁移后的本地构建路径，重建依赖索引，执行现有 `flutter test`。工具与 SDK 使用现有缓存，保留历史安装包。
2. 在 `test/calendar_records_test.dart` 编写旧文件兼容、增删改重启、考试排序校验、调休日期覆盖及删除恢复测试。运行确认缺少行为，再新增 `lib/data/calendar_records.dart`，扩展 `schedule_document.dart`，复用串行持久化。
3. 在 `schedule_comparison_test.dart` 增加调休比较断言；新增日期解析服务，接入 `schedule_week_index.dart`、`schedule_comparison.dart` 和 `academic_schedule_page.dart`，保证同一日期使用同一来源。
4. 增加考试和调休页面入口的界面失败测试，再实现 `lib/features/calendar_records_page.dart`、更多面板路由和表单；测试编辑、删除、错误输入以及保存失败保留数据。
5. 在 `test/pager_continuity_test.dart` 复现动画中周次不同步及快速二次手势；修改 `schedule_gesture_pager.dart` 的拖动/吸附/外部选周同步，运行手势与现有显示测试。
6. 全量 Flutter 测试、静态分析、官网提取测试和真实中文字体渲染；请求独立代码审查并修复有效问题。
7. 生成 Android release APK，验证签名及文件哈希，保留安装包；定位/恢复 OHOS SDK，运行独立 Dart 验证和原生 HAP 构建；签名条件缺失时明确记录阻塞，不冒充可安装成品。
8. 更新 README、verification、harmonyos 文档，交付路径与验证结果。

主要检查命令：`./tool/flutter.ps1 test`、`./tool/flutter.ps1 analyze --no-pub`、`node --test test/shu_script_test.cjs`、`./tool/flutter.ps1 build apk --release --split-per-abi`、`./tool/build-harmony.ps1 -DevEcoHome <SDK> -Unsigned`。
