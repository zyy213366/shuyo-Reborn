import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/schedule_store.dart';
import '../services/shu_import_script.dart';
import '../services/shu_exam_import.dart';

class SchoolImportPage extends StatefulWidget {
  const SchoolImportPage({super.key, this.exams = false});
  final bool exams;
  @override
  State<SchoolImportPage> createState() => _SchoolImportPageState();
}

class _SchoolImportPageState extends State<SchoolImportPage> {
  late final WebViewController _controller;
  late final Future<void> _ready;
  String _url = ShuImport.vpn;
  String? _error;
  int _progress = 0;
  bool _reading = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    await WebViewCookieManager().clearCookies();
    await _controller.clearLocalStorage();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
        onPageStarted: (url) {
          if (mounted) {
            setState(() {
              _url = url;
              _error = null;
            });
          }
        },
        onPageFinished: (url) async {
          if (widget.exams && !_closing && ShuImport.isTimetableUrl(url)) {
            try {
              await _controller.runJavaScript(ShuExamImport.observeScript);
            } catch (_) {}
          }
        },
        onNavigationRequest: (request) {
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _error = 'WebVPN 加载失败，请检查网络后刷新重试');
          }
        },
      ),
    );
    await _controller.loadRequest(Uri.parse(ShuImport.vpn));
  }

  Future<void> _read() async {
    if (widget.exams) {
      await _readExams();
      return;
    }
    if (_reading || _closing) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final url = await _controller.currentUrl() ?? '';
      if (!ShuImport.isTimetableUrl(url)) {
        throw const FormatException('请先完成官网登录，再打开个人课表页面');
      }
      final key = '__qing_${newScheduleId().replaceAll('-', '_')}';
      await _controller.runJavaScript(ShuImport.extractionScript(key));
      for (var i = 0; i < 90; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted || _closing) return;
        if (!ShuImport.isTimetableUrl(await _controller.currentUrl() ?? '')) {
          throw const FormatException('页面已跳转，请完成登录后重新读取');
        }
        final raw = await _controller.runJavaScriptReturningResult(
          'JSON.stringify(window[${jsonEncode(key)}] || null)',
        );
        dynamic decoded = raw;
        if (decoded is String) decoded = jsonDecode(decoded);
        if (decoded is String) decoded = jsonDecode(decoded);
        if (decoded == null) continue;
        if (decoded is! Map) throw const FormatException('无法读取课表');
        await _controller.runJavaScript('delete window[${jsonEncode(key)}]');
        if (decoded['error'] != null) {
          throw FormatException(decoded['error'].toString());
        }
        final schedule = ShuImport.parse(decoded['data'] as String);
        final document = ScheduleDocument(
          id: 'school',
          name: schedule.term.displayName.trim().isEmpty
              ? '上海大学课表'
              : schedule.term.displayName,
          schedule: schedule,
          firstWeekStart: DateTime.now(),
        );
        if (mounted) setState(() => _closing = true);
        await _clearSession();
        if (mounted) Navigator.pop(context, document);
        return;
      }
      throw const FormatException('读取超时，请在个人课表页面重试');
    } catch (error) {
      if (mounted && !_closing) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : '读取失败，请确认当前页面已显示课表后重试',
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _readExams() async {
    if (_reading || _closing) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      if (!ShuImport.isTimetableUrl(await _controller.currentUrl() ?? '')) {
        throw const FormatException('请先登录 WebVPN，进入教务系统的考试安排页');
      }
      await _controller.runJavaScript(ShuExamImport.observeScript);
      Object? value = await _controller.runJavaScriptReturningResult(
        ShuExamImport.readScript,
      );
      if (value is String) value = jsonDecode(value);
      if (value is String) value = jsonDecode(value);
      if (value == null) {
        throw const FormatException('请在考试安排页点击“查询”，待结果显示后再点击导入考试安排');
      }
      final exams = ShuExamImport.parse(jsonEncode(value));
      if (exams.isEmpty) throw const FormatException('此次查询没有考试安排，已保留现有考试');
      if (mounted) setState(() => _closing = true);
      await _clearSession();
      if (mounted) Navigator.pop(context, exams);
    } catch (error) {
      if (mounted && !_closing) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : '读取失败，请在考试安排页重新查询后重试',
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _clearSession() async {
    for (final clear in <Future<void> Function()>[
      () => _controller.loadHtmlString('<html><body></body></html>'),
      () async {
        await WebViewCookieManager().clearCookies();
      },
      _controller.clearLocalStorage,
      _controller.clearCache,
    ]) {
      try {
        await clear().timeout(const Duration(seconds: 4));
      } catch (_) {
        /* Attempt every cleanup even if a WebView operation fails. */
      }
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      await _ready;
      await _clearSession();
    } catch (_) {
      /* Closing never prevents returning to the saved local timetable. */
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _closing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_close());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('上海大学 WebVPN'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭官网',
          onPressed: _close,
        ),
        actions: [
          IconButton(
            tooltip: '刷新网页',
            onPressed: _reading ? null : _controller.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('无法启动内置浏览器，请检查系统 WebView 组件后重试'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exams
                          ? '登录 WebVPN → 考试安排 → 点击查询 → 导入'
                          : '登录 WebVPN → 打开个人课表 → 读取课表',
                    ),
                    Text(
                      Uri.tryParse(_url)?.host ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        if (!widget.exams)
                          TextButton(
                            onPressed: _reading
                                ? null
                                : () => _controller.loadRequest(
                                    Uri.parse(
                                      '${ShuImport.vpn}${ShuImport.indexPath}',
                                    ),
                                  ),
                            child: const Text('打开课表页'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_progress < 100)
                LinearProgressIndicator(value: _progress / 100),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(child: WebViewWidget(controller: _controller)),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: _reading || _closing ? null : _read,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(
            _reading ? '正在读取…' : (widget.exams ? '导入考试安排' : '读取当前学期课表'),
          ),
        ),
      ),
    ),
  );
}
