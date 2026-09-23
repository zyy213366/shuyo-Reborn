import 'package:flutter/services.dart';
import '../data/schedule_store.dart';

class ScheduleFiles {
  static const channel = MethodChannel('cn.qingke.qing_schedule/files');
  Future<void> Function(Map<String, dynamic>)? _receive;
  bool _draining = false;
  bool _again = false;

  Future<void> start(
    Future<void> Function(Map<String, dynamic>) receive,
  ) async {
    _receive = receive;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'pending') await _drain();
    });
    await _drain();
  }

  Future<void> _drain() async {
    if (_draining) {
      _again = true;
      return;
    }
    _draining = true;
    try {
      do {
        _again = false;
        final events =
            await channel.invokeListMethod<dynamic>('takePending') ?? [];
        for (final event in events) {
          await _receive?.call(Map<String, dynamic>.from(event as Map));
        }
      } while (_again);
    } on MissingPluginException {
      // Desktop widget tests have no Android platform implementation.
    } finally {
      _draining = false;
    }
  }

  Future<String?> pick() => channel.invokeMethod<String>('pickFile');
  Future<void> share(ScheduleDocument doc) => channel.invokeMethod<void>(
    'shareFile',
    {'text': ScheduleCodec.encode(doc), 'name': doc.name},
  );
  void dispose() {
    _receive = null;
    channel.setMethodCallHandler(null);
  }
}
