// Build with: flutter build apk --release -t tool/device_font_probe.dart
// Install the diagnostic APK on a test emulator; it logs DEVICE_FONT_PROBE.
// A standalone diagnostic entry point; does not read or modify saved timetables.
import 'package:flutter/material.dart';
import 'package:qing_schedule/shared/device_font_service.dart';
import 'package:qing_schedule/shared/theme/shuyo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final native = await DeviceFontService.channel
      .invokeMapMethod<String, dynamic>('read');
  if (native == null) {
    throw StateError('Native font API unavailable on this device');
  }
  final unchanged = await DeviceFontService.channel
      .invokeMapMethod<String, dynamic>('read', {
        'signature': native['signature'],
      });
  if (unchanged?['unchanged'] != true) {
    throw StateError('Font fingerprint cache failed');
  }
  final fonts = DeviceFontService()..enabled = true;
  fonts.start();
  await fonts.refresh();
  if (fonts.families.isEmpty) throw StateError('Flutter font load failed');
  final description = (native['fonts'] as List)
      .map((f) => '${f['index']}:${(f['bytes'] as List).length}')
      .join(',');
  debugPrint(
    'DEVICE_FONT_PROBE PASS families=${fonts.families.length} faces=$description unchanged=true',
  );
  runApp(
    MaterialApp(
      theme: ShuYoThemes.byId(
        ShuYoThemes.defaultId,
      ).themeData(deviceFonts: fonts.families),
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '本机字体读取通过\n课程名称 教师 地点\n第 3 周（本周） 九月\n数学 MATH-101 3.0\nAa 0123456789',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    ),
  );
}
