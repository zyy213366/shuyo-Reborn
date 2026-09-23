import 'dart:async';
import 'package:flutter/material.dart';
import '../data/schedule_store.dart';
import '../data/repositories/academic_schedule_repository.dart';
import '../services/schedule_files.dart';
import 'home/academic_schedule_page.dart';
import 'import_preview.dart';
import 'school_import.dart';

class ScheduleHome extends StatefulWidget {
  const ScheduleHome({super.key, required this.store});
  final ScheduleStore store;
  @override
  State<ScheduleHome> createState() => _ScheduleHomeState();
}

class _ScheduleHomeState extends State<ScheduleHome> {
  final files = ScheduleFiles();
  late final Future<void> ready;
  int _reload = 0;
  bool _importing = false;
  final _incoming = <Map<String, dynamic>>[];
  Timer? _deferredImport;
  bool _inboxOverflow = false;
  @override
  void initState() {
    super.initState();
    ready = widget.store.documents.isEmpty
        ? widget.store.create('我的课表').then((_) {})
        : Future.value();
    widget.store.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ready;
      if (mounted) {
        await files.start((event) async {
          if (_incoming.length < 4) {
            _incoming.add(event);
          } else {
            _inboxOverflow = true;
          }
          unawaited(_drainIncoming());
        });
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _deferredImport?.cancel();
    widget.store.removeListener(_changed);
    files.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) await _error(error);
    }
  }

  Future<void> _error(Object error) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('操作未完成'),
      content: Text(
        error is FormatException ? error.message : error.toString(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Future<void> _drainIncoming() async {
    if (_importing || !mounted) return;
    if (_incoming.isEmpty) return;
    // Preserve any in-progress course editor or modal before showing an import.
    if (Navigator.of(context).canPop()) {
      if (_deferredImport?.isActive != true) {
        _deferredImport = Timer(
          const Duration(milliseconds: 300),
          _drainIncoming,
        );
      }
      return;
    }
    _importing = true;
    try {
      while (_incoming.isNotEmpty && mounted) {
        final event = _incoming.removeAt(0);
        await _guard(() async {
          if (event['error'] != null) {
            throw FormatException(event['error'] as String);
          }
          await _preview(ScheduleCodec.decode(event['text'] as String));
        });
      }
      if (_inboxOverflow && mounted) {
        _inboxOverflow = false;
        await _error(const FormatException('一次最多接收四个课表，请重新打开其余文件。'));
      }
    } finally {
      _importing = false;
    }
  }

  Future<void> _preview(
    ScheduleDocument document, {
    bool fromSchool = false,
  }) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPreviewPage(
          store: widget.store,
          source: document,
          fromSchool: fromSchool,
        ),
      ),
    );
    if (mounted) setState(() => _reload++);
  }

  Future<void> _import() async {
    if (_importing) return;
    _importing = true;
    try {
      await _guard(() async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('导入课表')),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('上海大学教务官网'),
                  subtitle: const Text('登录官网，读取课表后导入'),
                  onTap: () => Navigator.pop(context, 'school'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('朋友分享的课表文件'),
                  subtitle: const Text('选择 .shuyoschedule.json 文件'),
                  onTap: () => Navigator.pop(context, 'file'),
                ),
              ],
            ),
          ),
        );
        if (!mounted || choice == null) return;
        if (choice == 'school') {
          final schedule = await Navigator.push<ScheduleDocument>(
            context,
            MaterialPageRoute(builder: (_) => const SchoolImportPage()),
          );
          if (schedule != null && mounted) {
            await _preview(schedule, fromSchool: true);
          }
        } else {
          final text = await files.pick();
          if (text != null && mounted) {
            await _preview(ScheduleCodec.decode(text));
          }
        }
      });
    } finally {
      _importing = false;
      unawaited(_drainIncoming());
    }
  }

  Future<String?> _name({String initial = '', String title = '新建课表'}) async {
    final controller = TextEditingController(text: initial);
    final key = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: '课表名称'),
            validator: (v) => (v?.trim().isEmpty ?? true) ? '请输入名称' : null,
            onFieldSubmitted: (_) {
              if (key.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    // The route animation may retain the field briefly after pop.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return name;
  }

  Future<void> _manage() async {
    final action = await showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '我的课表',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, ('new', null)),
                      icon: const Icon(Icons.add),
                      label: const Text('新建'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final doc in widget.store.documents)
                      Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        elevation: 0,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                doc.id == widget.store.active.id
                                    ? Icons.check_circle
                                    : Icons.calendar_month_outlined,
                              ),
                              title: Text(doc.name),
                              subtitle: Text(
                                '${doc.schedule.sessions.length} 个课程时段 · ${doc.firstWeekStart.month}月${doc.firstWeekStart.day}日开学',
                              ),
                              onTap: () =>
                                  Navigator.pop(context, ('select', doc.id)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: '重命名课表',
                                  icon: const Icon(
                                    Icons.drive_file_rename_outline,
                                  ),
                                  onPressed: () => Navigator.pop(context, (
                                    'rename',
                                    doc.id,
                                  )),
                                ),
                                IconButton(
                                  tooltip: '复制课表',
                                  icon: const Icon(Icons.copy_outlined),
                                  onPressed: () =>
                                      Navigator.pop(context, ('copy', doc.id)),
                                ),
                                IconButton(
                                  tooltip: '删除课表',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => Navigator.pop(context, (
                                    'delete',
                                    doc.id,
                                  )),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _guard(() async {
      final (kind, id) = action;
      switch (kind) {
        case 'new':
          final name = await _name();
          if (name != null) await widget.store.create(name);
        case 'select':
          await widget.store.select(id!);
        case 'copy':
          await widget.store.duplicate(id!);
        case 'rename':
          final name = await _name(
            initial: widget.store.byId(id!).name,
            title: '重命名课表',
          );
          if (name != null) {
            await widget.store.mutate(id, (d) => d.copyWith(name: name));
          }
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('删除这张课表？'),
              content: Text('将删除「${widget.store.byId(id!).name}」。其他课表和副本不受影响。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('删除'),
                ),
              ],
            ),
          );
          if (confirmed == true) await widget.store.delete(id!);
      }
    });
  }

  Future<void> _times() async {
    final doc = widget.store.active;
    final times = doc.sectionTimes.map((r) => List<int>.of(r)).toList();
    final result = await showModalBottomSheet<List<List<int>>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              children: [
                const ListTile(
                  title: Text('作息时间'),
                  subtitle: Text('仅修改当前课表；默认使用上海大学作息'),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < times.length; i++)
                        ListTile(
                          title: Text('第 ${i + 1} 节'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final offset in [0, 2])
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay(
                                        hour: times[i][offset],
                                        minute: times[i][offset + 1],
                                      ),
                                    );
                                    if (picked != null && context.mounted) {
                                      update(() {
                                        times[i][offset] = picked.hour;
                                        times[i][offset + 1] = picked.minute;
                                      });
                                    }
                                  },
                                  child: Text(
                                    '${times[i][offset].toString().padLeft(2, '0')}:${times[i][offset + 1].toString().padLeft(2, '0')}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, times),
                    child: const Text('保存作息'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      await _guard(
        () => widget.store.mutate(
          doc.id,
          (d) => d.copyWith(sectionTimes: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(body: Center(child: Text(snapshot.error.toString())));
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final doc = widget.store.active;
      return SectionTimesScope(
        times: doc.sectionTimes,
        child: SafeArea(
          top: false,
          child: AcademicSchedulePage(
            key: ValueKey(_reload),
            repository: AcademicScheduleRepository(
              store: widget.store,
              documentId: doc.id,
            ),
            onImport: _import,
            onShare: () => _guard(() => files.share(widget.store.active)),
            onManage: _manage,
            onTimes: _times,
          ),
        ),
      );
    },
  );
}
