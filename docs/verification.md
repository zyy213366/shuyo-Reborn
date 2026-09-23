# 验证记录
## API 26 打包通过与签名准备（2026-09-20～2026-09-21）

- Command Line Tools 26.0.0.821 已安装至 `D:\Huawei\command-line-tools`；SDK 26.0.0.105 / API 26、Node 24.14.1、hvigor 6.26.4、ohpm 26.0.0.630，旧工具包保留在 `D:\Huawei\command-line-tools-6.0.2`。
- 2026-09-20 完整执行 `build-harmony.ps1 -DevEcoHome 'D:\Huawei\command-line-tools' -Unsigned -SkipChecks`，独立工程重建、原生插件注册、ArkTS 编译、release 打包通过，退出码 0；构建约 120 秒。Dart 未更改，本次复用此前已通过的 56 项测试与静态检查。日志见 `harmony/build-api26.log`。
- 生成 `build/harmony/entry-default-unsigned.hap`，42,468,111 字节（40.5 MiB）；2026-09-21 复核 SHA-256 为 `0ea6fd0b7ffd901dad81651465125c4f8723044a290e7a2884a45faa7cc0785a`。包内含 ArkTS 字节码、arm64 `libapp.so` / `libflutter.so` 和 Flutter 资源；清单包名 `cn.qingke.qing_schedule`、版本 1.0.0、设备类型 phone、最低 API 18、目标 API 26。
- DevEco CLI 1.3.0-stable 已安装至 D 盘，新增 `tool/deveco.ps1` 包装脚本，语法检查通过。登录状态为 `Not logged in`，`hdc list targets` 为 `[Empty]`；已启动官方账号登录，待用户登录和连接手机后继续真实签名。未签名 HAP 不能作为可安装成品，尚未验证鸿蒙真机、WebVPN 或分享流程。
- Android arm64 APK SHA-256 仍为 `34934ec950bc9208a356c37bda11b238e1e7ef96f610a4b9c29c83ec3b9ae2a3`，未被本次工具链安装或构建修改。下方 API 22 失败记录保留作为历史诊断。

## 鸿蒙 SDK 安装与原生编译（2026-09-20）

- 用户下载的 Command Line Tools 6.0.2.670 已安装到 `D:\Huawei\command-line-tools`，附带 HarmonyOS 6.0.2.130 / API 22；Flutter doctor 已识别 HarmonyOS 工具链。hvigor/npm 缓存设置在 D 盘，使用项目 JDK 21。
- 依赖下载的 IPv6 超时经 Node IPv4 优先设置解决。WebView 和 SharedPreferences 原生插件注册已生成，Flutter release AOT 与原生资源处理完成。
- ArkTS 首次检查发现应用桥接的两处隐式类型问题，改为明确类型后复编，应用代码的这两处错误消失。剩余 17 条具体诊断均来自 Flutter 引擎所用的 API 26 自动填充及手势接口，API 22 SDK 无相应声明。最新日志：`harmony/build-sdk-installed.log`；编译退出码 1，未生成 HAP。
- 工程明确配置目标 SDK 26、最低兼容 API 18；构建脚本新增 SDK 版本预检查、独立环境配置和 `-Unsigned` 构建选项。两个 PowerShell 脚本语法检查通过，实测 API 22 会在重建生成目录前被拦截并明确提示所需版本。
- 当前等待 API 26 工具包；签名未配置，`hdc list targets` 为空，尚无鸿蒙真机验证。下方记录中的“SDK 未安装”是本次安装之前的历史状态。

## 需求(5) 与鸿蒙准备（2026-09-18～2026-09-20）

- Android 功能完成：点击周数弹出居中的 1–16 周选择表，现实本周独立标识；更多新增多课表对比；学校导入入口统一 WebVPN。
- 对比按实际日期和各自作息计算：都有课采用所有课表的忙碌交集，都没课采用忙碌并集的补集，保留课间空闲。共同课程优先按课程号、无歧义时按名称匹配，分别显示每张课表的时间；支持全部教学周或当前自然周。
- Android 工具链下 56 项 Flutter 回归测试、1 项中文字体界面渲染检查通过，静态检查无问题。新增截图：`build/previews/week-calendar.png`、`comparison-busy.png`、`comparison-free.png`、`comparison-courses.png`；已查看周选择与对比结果布局。
- 2026-09-18 15:18 完成 release APK：arm64-v8a 31,202,222 字节、armeabi-v7a 28,889,464 字节、x86_64 32,767,921 字节。正式首页入口，保留在 `build/app/outputs/flutter-apk/`。
- 2026-09-20 复核 arm64 包 SHA-256 为 `34934ec950bc9208a356c37bda11b238e1e7ef96f610a4b9c29c83ec3b9ae2a3`；`apksigner verify --verbose` 通过，APK v2 签名有效。本轮未新增真机登录或设备安装测试。
- 鸿蒙工具链固定为官方稳定标签 `3.41.10-ohos-1.0.1`（Dart 3.11.5）；WebView 和 shared preferences 鸿蒙源码固定提交，见 `harmony/sources.json`。
- `tool/build-harmony.ps1 -PrepareOnly` 实测成功：独立目录依赖解析完成，静态检查无问题，56 项 Dart 回归测试通过，然后复制原生工程。Dart 注册信息包含 `SharedPreferencesOhos` 和 `OhosWebViewPlatform`。
- 已准备 ArkTS 文件选择、2 MiB UTF-8 JSON 读取、系统文件分享、Want URI 文件打开及系统字体回退。由于 SDK 未安装，原生插件注册、ArkTS 编译与真机验证尚未完成。Dart 测试在 Windows 宿主运行，不代表系统 WebView 或原生文件接口已验证。
- 实际执行 `flutter build hap --release --no-pub`，引擎组件下载后以退出码 1 结束：`No Hmos SDK found`。未生成 HAP；日志见 `harmony/build-attempt.log`，后续步骤见 `docs/harmonyos.md`。

## 第三轮需求更新（2026-09-18）

- 对照 `需求(4).txt` 完成 11 项调整；50 项自动回归测试和 1 项真实中文字体界面渲染检查通过，`flutter analyze --no-pub` 无问题。
- 周数静止时是普通文字，单击不展开，直接竖滑显示滚轮，松手立即提交并收起；双击返回现实当前教学周。增加本周状态、日期范围和周一所属中文月份。尚未开学时提示没有对应教学周，不把第一周错误标为本周。
- 短距离翻周验证：35 逻辑像素的缓慢横滑成功切周；微小移动、取消、多指手势和学期起始边界继续按预期处理。
- 背景格子入口移动到显示设置；新增学分和三种课程周数文字模式。单/双周仅在数据覆盖学期完整奇偶周时采用简写，部分奇偶周按真实集合展示。隐藏信息不修改课程数据。
- 全局弹窗背景透明度拖动实时预览、松手保存，普通文字保持不透明；设置重启后恢复。弹窗、底部面板和自定义课程详情背景统一读取该偏好。
- 所有可选信息同时开启的一节课卡片，在放大字体下仍保留原有节次高度且无布局溢出；极窄卡片仍可能省略长文本，可点开详情查看。
- Android 字体桥接使用原生 TextView + TextRunShaper 取得实际字体字节和 TTC 字面，Flutter 全局主题统一使用加载后的字体及回退链，恢复前台/配置变化时刷新，关闭同步后恢复内置字体。
- Android API 36 模拟器运行 `tool/device_font_probe.dart` 实测通过：加载 2 个字体，分别为 2,371,712 字节的普通字体与 32,355,424 字节 TTC 集合中的索引 2 字面；相同内容的签名缓存返回 unchanged=true。无 AndroidRuntime 崩溃。截图：`build/previews/device-font-probe.png`。
- 模拟器验证涵盖公开 API、TTC 提取和 Flutter 实际加载，不代表已验证厂商主题商店。Android 12 以下或厂商不公开当前主题字体时回退系统字体；私有主题和可变字体轴仍需对应真机确认。
- 交付 APK 为 `app-arm64-v8a-release.apk`（手机通常使用）、`app-armeabi-v7a-release.apk`、`app-x86_64-release.apk`，均使用正式首页入口。字体诊断包不作为交付包。
- 最终构建于 2026-09-18 完成，arm64-v8a 31,136,594 字节（29.7 MiB）；SHA-256：`0052bc4f0634aa11ab9644662b84074e4563c8c6cb6484fdc8b704f4a93b0939`。x86_64 包在 API 36 模拟器安装、启动成功，已核对正式课表首页；截图：`build/previews/final-android-home.png`。

## 第二轮显示与交互更新（2026-09-17）

- 最终检查：41 项 Flutter 回归测试，以及 1 项使用实际内置中文字体的界面渲染检查，合计 42 项通过；`flutter analyze --no-pub` 无问题。
- 左上角周次胶囊：直接上下拖动展开滚轮、惯性停止后切换、远距离选周、点击外部取消；未操作时只显示当前周次。
- 五天模式：长课程号、教师和地点按实际宽高换行，测试确认文字完整显示时课程顶部与高度不变；空间不足时保留省略和课程详情入口。
- 背景与控制栏：背景格子关闭后卡片坐标不变；控制栏隐藏后释放原有 36 像素空间，双指缩放与横向翻周继续生效，设置重启后恢复。
- 连续课程：本周及非本周卡片均使用不透明底色；像素检查确认连续节次交界处没有背景格子缝隙。非本周课程通过调浅颜色与降低文字对比度区分。
- 设置入口：非本周课程、课程号移到“更多 → 显示设置”；背景格子开关位于更多面板。修改立即生效，失败时保留原值。
- 全局外观：浅色、深色、跟随系统和字体偏好适用于首页、设置面板与编辑页，跨课表与重启保持；课表导出不携带接收者的全局外观偏好。内置 Noto Sans SC 字体及 OFL 许可证随应用打包。
- 性能改动：周课程列表与格子占用索引按需缓存并在缩放帧间复用；单指横滑使用 Flutter 原生 Drag 活动；远距离选周只绘制目标附近页面；课表切换复用已加载数据并淡入；卡片绘制边界隔离，避免整体透明合成。
- 性能相关测试确认同一周索引在 120 次访问中复用，以及从第 1 周选择第 30 周不构建中间第 15 周。尚未进行真实手机 profile 帧率测试，不将这些检查等同于设备上的稳定帧率保证。
- 可重复执行 `flutter test tool/capture_home_test.dart`；截图在 `build/previews/`，覆盖浅色七天/五天、周次滚轮、更多、深色设置、隐藏格子与控制栏，以及 320 像素大字体。小屏放大字体时顶部高度随文字调整。
- Android release 构建通过：arm64-v8a（29.6 MB）、armeabi-v7a（27.3 MB）、x86_64（31.0 MB）。已检查 arm64 APK 包含内置中文字体及 OFL 许可证。

## 首页交互更新（2026-09-17）

- Flutter 回归测试：32 项通过；另运行 1 项本地界面渲染检查，通过。
- `flutter analyze --no-pub`：无问题。
- 官网提取脚本：5 种模拟场景通过。
- 新增验证覆盖：双指放大/缩小的五天与七天切换、模式重启恢复、五天范围查看周末、翻周跟手与吸附、真实日期高亮、单指纵向滚动、横滑中加入第二指、缩放后单指离开、取消手势、短距离回弹和学期起始边界。
- 更多面板验证：滚轮停稳切换、切换后继续修改设置和添加课程、设置按课表独立保存、保存失败时回滚；非本周重叠课程可从选择面板进入详情。
- 课程号验证：学校字段及别名、空字段回退、缺失字段、实践课程、手动填写与清空、编辑回显、导出往返和旧文件兼容。
- 七天在 320 / 360 / 412 逻辑像素及 1.5 倍系统字体下保持完整显示；另验证一节课卡片同时显示课程号、教师、教室无溢出。
- 本地渲染检查：七天、五天、更多面板，确认圆角、淡化、日期高亮与布局。预览仅为字体渲染加载了本机字体，未将系统字体打包入应用。
- Android release 构建成功：`build/app/outputs/flutter-apk/` 下生成 arm64-v8a、armeabi-v7a、x86_64 三种 APK。
- 继承项目的生成缓存含旧机器 F 盘路径，已重新生成依赖索引并清理旧构建缓存，随后完整构建通过。

尚未使用真实手机执行多指操作，也未使用真实校园账号进行端到端官网导入；手势结论来自 Flutter 多指事件测试，官网结论来自匿名样例和模拟响应。

## 自动检查（2026-09-16）

- `flutter test --no-pub`：22 项通过。
- `dart analyze lib test tool/export_test_fixture.dart`：无问题。
- `node --test test/shu_script_test.cjs`：5 种官网提取脚本场景通过。
- 七天同屏在 320 / 360 / 412 逻辑像素、正常与 1.5 倍系统字体下通过；周日课程在视口范围内，无横向滚动容器。
- 验证了课表独立副本、重启保存、分享往返、身份字段清除、损坏文件拒绝、重叠课程选择、导入预览取消、持久化失败回滚和合并/切换原子保存。

## 验证范围

官网提取使用 ShuYo 的匿名样例和模拟网页响应验证，覆盖直连、WebVPN、未登录、错误响应和非教务域名。不使用真实校园账号，因此尚未验证当前上海大学账号的端到端登录和课表读取。

## 来源与仓库

本地独立仓库；未配置远程地址，也未推送到 ShuYo。参考源放在忽略目录 `reference/ShuYo`。GPL-3.0 和修改来源见根目录 LICENSE、NOTICE.md。


2026-09-20 原生 HAP 构建实测：鸿蒙引擎组件下载完成，`flutter build hap --release --no-pub` 因缺少 HarmonyOS SDK 返回退出码 1（`No Hmos SDK found`）。诊断见 `harmony/build-attempt.log`；未生成 HAP。

