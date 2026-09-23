# HarmonyOS NEXT 适配工程

本工程使用 CPF-Flutter 的原生 OHOS 引擎和 ArkTS 宿主，目标为 HarmonyOS NEXT，最低配置为 HarmonyOS 5.1 / API 18。它与 Android APK 使用同一套 Dart 课表界面和数据模型。

**当前交付状态（2026-09-21 核验）：原生 release 编译通过，已生成未签名 HAP，尚未完成签名和手机安装。** Command Line Tools 26.0.0.821 已安装在 `D:\Huawei\command-line-tools`，附带 HarmonyOS SDK 26.0.0.105 / API 26；旧工具包保留在 `D:\Huawei\command-line-tools-6.0.2`。编译 SDK 与最低兼容 API 18 是不同设置；最低版本可运行性仍待真机验证。

产物：`build/harmony/entry-default-unsigned.hap`，42,468,111 字节（40.5 MiB），2026-09-20 20:14 构建成功。SHA-256：`0ea6fd0b7ffd901dad81651465125c4f8723044a290e7a2884a45faa7cc0785a`。包内已核对 ArkTS 字节码、arm64 Flutter 引擎和应用库、Flutter 资源。未签名包不能直接安装到普通鸿蒙手机。

## 已准备的内容

- `ohos/`：从官方 Flutter OHOS 模板建立的 Stage 工程，应用标识 `cn.qingke.qing_schedule`，名称「轻课表」。
- `EntryAbility.ets`：注册鸿蒙插件、接入文件和字体 MethodChannel，处理启动与再次打开文件。
- `SchedulePlatformBridge.ets`：系统文件选择、UTF-8 JSON 读取、2 MiB 限制、原生 Share Kit 分享文件、通过 Want URI 接收文件。导入内容仍先进入 Flutter 预览，经用户确认后保存。当前仅声明 JSON 文件的“打开方式”；未声明作为任意第三方应用分享面板的接收目标。
- 鸿蒙版 `webview_flutter` 和 `shared_preferences`：保留 WebVPN、登录页退出清理、本地多课表与设置保存；插件版本独立于 Android。
- 本机字体：由鸿蒙 Flutter 引擎使用系统回退字体，关闭同步后使用内置 Noto Sans SC。Android 的 TextRunShaper 字体提取接口不会在鸿蒙执行；厂商主题字体同步需真机核验。
- 周选择、课表对比、课表切换、显示设置复用 Dart 实现。共同课程列出每张课表自己的上课时间。

## 工具链与依赖固定

`harmony/sources.json` 记录官方仓库地址、版本标签/分支及完整提交号：

| 组件 | 版本 / 来源 |
| --- | --- |
| Flutter OHOS | 官方稳定标签 `3.41.10-ohos-1.0.1` |
| WebView | `br_webview_flutter-v4.13.0_ohos` 固定提交 |
| Shared preferences | `br_shared_preferences-v2.5.3_ohos` 固定提交 |
| 编译 SDK | HarmonyOS 26.0.0.105 / API 26 |
| 当前命令行工具 | `D:\Huawei\command-line-tools`，26.0.0.821 |
| 当前辅助环境 | 内置 Node 24.14.1、ohpm 26.0.0.630、hvigor 6.26.4；使用项目 JDK 21 |
| 签名工具 | DevEco CLI 1.3.0-stable，`D:\Huawei\deveco-cli` |

脚本使用 `.tools/flutter-ohos`、`.tools/pub-cache-ohos` 和 `.tools/harmony-app`。鸿蒙插件的依赖覆盖只写入生成目录。Android 的 `pubspec.lock`、`.dart_tool` 和 APK 输出不受鸿蒙构建影响。

## 准备与构建

在项目根目录使用 PowerShell：

```powershell
.\tool\build-harmony.ps1 -PrepareOnly
```

该命令获取固定源码，在没有 OHOS 宿主目录的临时阶段解析依赖并运行 Dart 静态检查和回归测试，然后复制原生源码。这样准备阶段无需 SDK；原生 GeneratedPluginRegistrant 由 SDK 就绪后的正常构建生成。2026-09-20 实测此命令成功，静态检查无问题，56 项 Dart 测试通过。首次执行需网络连接。生成目录为 `.tools/harmony-app/ohos`；每次准备会重建其中的源码目录，**请在根目录 `ohos/` 修改源码，不要把唯一一份签名配置保存在生成目录中**。

安装包含 HarmonyOS API 26 SDK 的 Command Line Tools 或 DevEco Studio 后，将其安装目录传给脚本；先验证未签名编译：

```powershell
.\tool\build-harmony.ps1 -DevEcoHome 'D:\Huawei\command-line-tools' -Unsigned
```

`tool/harmony-env.ps1` 支持命令行包的 `tool/node` 和 Studio 的 `tools/node` 布局，为当前 PowerShell 进程设置 SDK、JDK、Node 和工具路径，并把 hvigor/npm 缓存放在 `D:\Huawei\cache`。当前机器为兼容 Flutter 工具查找另建了 `D:\Huawei\command-line-tools\tools` → `tool` 的目录联接。Node 使用 IPv4 优先，解决此网络对华为依赖 CDN 的 IPv6 连接超时；未修改系统网络或证书设置。

也可以自行设置 `DEVECO_SDK_HOME`、`JAVA_HOME` 和 DevEco 的 Node、ohpm、hvigor 路径，再调用脚本。正常构建会先读取 SDK 元数据；低于 API 26 时在替换生成工程之前直接说明缺少的版本，避免重复下载和无效编译。

根目录的 `ohos/build-profile.json5` 不包含签名。已安装的 DevEco CLI 可以为生成工程配置调试签名。首先运行 `.\tool\deveco.ps1 auth login`，在华为官方页面由账号所有者完成登录，然后连接鸿蒙手机并在手机上开启、允许 USB 调试。签名需要开发者账号满足华为的实名认证要求及设备授权。

在生成的 `.tools/harmony-app/ohos` 目录运行 `& 'D:\wbc\shuyo\tool\deveco.ps1' signature generate`，完成后将包含签名的完整 `build-profile.json5` 备份至本地私有目录，证书、profile 和密钥路径使用绝对路径。也可在 DevEco Studio 打开生成工程并配置自动签名。重新构建可执行：

```powershell
.\tool\build-harmony.ps1 -DevEcoHome 'D:\Huawei\command-line-tools' -SigningProfile 'D:\private-signing\qingke-build-profile.json5'
```

脚本执行 `flutter build hap --release --no-pub`，仅在构建成功后将 HAP 复制到 `build/harmony/`。未签名文件不能作为手机安装成品；调试签名包只能安装至签名允许的设备。签名密码及私钥不应写入仓库或发送到聊天。

`tool/deveco.ps1` 把 CLI 数据保存在 `D:\Huawei\deveco-cli-data` 并禁用该工具的使用情况遥测；账号凭据由官方工具管理，不写入项目。安装 CLI 时跳过了文档后台下载脚本，签名命令不依赖该脚本。

`-SkipChecks` 仅适用于已经通过检查、只重试原生打包的场景，不表示跳过 SDK 编译。

## 本次 HAP 构建尝试

2026-09-20 安装前首次执行因 `No Hmos SDK found` 失败，原始日志在 `harmony/build-attempt.log`。

同日安装用户下载的 6.0.2.670 工具包后，Flutter doctor 的 HarmonyOS toolchain 检查通过。依赖安装、鸿蒙插件注册、Flutter release AOT、资源处理、原生库打包步骤均已执行；ArkTS 编译发现应用文件桥接的两处隐式类型问题，已修复并复编确认不再出现。剩余错误全部位于 Flutter 引擎的自动填充与手势实现：API 22 没有 `autoFillManager.AutoFillType`、`requestAutoFill` 和 `CompetitionStrategy` 等 API 26 接口。未改动第三方引擎来跳过这些功能。编译返回失败，最新日志在 `harmony/build-sdk-installed.log`；没有生成 HAP。

随后安装用户提供的 API 26 工具包，完整重建独立工程并执行 `build-harmony.ps1 -Unsigned -SkipChecks`，构建退出码 0，耗时约 120 秒，成功生成上述未签名 HAP。日志：`harmony/build-api26.log`。`-SkipChecks` 复用此前已通过的 56 项 Dart 测试与静态检查，本轮实际执行了 ArkTS 编译、原生插件编译和 HAP 打包。第三方依赖仍有 SDK 弃用/类型警告，未视作真机兼容性已验证。

## SDK 就绪后仍需验证

1. 已完成 ArkTS 编译和未签名 HAP 打包；继续完成华为账号登录、设备调试签名及安装。
2. 真机首次启动、课表保存后重启恢复；文件选择取消、中文 JSON、损坏及超限文件、外部文件打开、分享给另一台设备。
3. WebVPN 真账号登录、学期选择与读取，退出后缓存和登录状态清理。
4. 七天/五天课表、1–16 周选择、本周标识、三个对比模式、浅深主题、透明度及大字体布局。
5. 使用签名允许的真实设备安装最终 HAP，保留 Android APK 与 HAP 两份交付物。

Dart 单元/界面测试不覆盖原生 ArkTS 编译或系统 WebView，不能视作上述真机测试已通过。

## 官方参考

- [CPF-Flutter 工具链](https://gitcode.com/CPF-Flutter/flutter_flutter)
- [CPF-Flutter 插件](https://gitcode.com/CPF-Flutter/flutter_packages)
- [DevEco 自动签名](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ide-signing-auto)
- [系统文件选择器](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-file-picker)
- [系统分享文件 URI 说明](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-share-2)


