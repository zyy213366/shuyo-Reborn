import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/schedule_store.dart';
import 'data/appearance_settings.dart';
import 'features/schedule_home.dart';
import 'shared/theme/shuyo_theme.dart';
import 'shared/device_font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'ShuYo / 轻课表',
    ], await rootBundle.loadString('NOTICE.md'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<ScheduleStore> _loading = _load();
  Future<ScheduleStore> _load() async {
    final store = ScheduleStore();
    await store.load();
    if (store.documents.isEmpty) await store.create('我的课表');
    return store;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ScheduleStore>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) return QingScheduleApp(store: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 40),
                          const SizedBox(height: 16),
                          Text(
                            snapshot.error is FormatException
                                ? (snapshot.error as FormatException).message
                                : '课表读取失败，原有数据已保留。',
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() => _loading = _load()),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}

class QingScheduleApp extends StatefulWidget {
  const QingScheduleApp({super.key, required this.store});
  final ScheduleStore store;
  @override
  State<QingScheduleApp> createState() => _QingScheduleAppState();
}

class _QingScheduleAppState extends State<QingScheduleApp> {
  final _fonts = DeviceFontService();
  late AppearanceSettings _appearance;
  late ThemeData _light;
  late ThemeData _dark;

  @override
  void initState() {
    super.initState();
    _fonts.start();
    _fonts.addListener(_fontChanged);
    _readAppearance();
    widget.store.addListener(_changed);
  }

  void _readAppearance() {
    _appearance = widget.store.appearance;
    final wasEnabled = _fonts.enabled;
    _fonts.enabled = _appearance.useSystemFont;
    if (!wasEnabled && _fonts.enabled) _fonts.refresh();
    _light = ShuYoThemes.byId(ShuYoThemes.systemLightId).themeData(
      useSystemFont: _appearance.useSystemFont,
      deviceFonts: _fonts.families,
      popupOpacity: _appearance.popupOpacity,
    );
    _dark = ShuYoThemes.byId(ShuYoThemes.systemDarkId).themeData(
      useSystemFont: _appearance.useSystemFont,
      deviceFonts: _fonts.families,
      popupOpacity: _appearance.popupOpacity,
    );
  }

  void _fontChanged() {
    if (mounted) setState(_readAppearance);
  }

  void _changed() {
    if (widget.store.appearance != _appearance) setState(_readAppearance);
  }

  @override
  void didUpdateWidget(covariant QingScheduleApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_changed);
      widget.store.addListener(_changed);
      _readAppearance();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    _fonts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '轻课表',
    debugShowCheckedModeBanner: false,
    theme: _light,
    darkTheme: _dark,
    themeMode: _appearance.themeMode,
    themeAnimationDuration: const Duration(milliseconds: 180),
    themeAnimationCurve: Curves.easeOut,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ScheduleHome(store: widget.store),
  );
}
