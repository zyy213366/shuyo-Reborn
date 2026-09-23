import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Fonts are obtained from a native TextView, never from a hard-coded file path.
class DeviceFontService extends ChangeNotifier with WidgetsBindingObserver {
  static const channel = MethodChannel('cn.qingke.qing_schedule/fonts');
  List<String> families = const [];
  String? _signature;
  bool _busy = false;
  bool _disposed = false;
  bool enabled = false;
  bool _refreshAgain = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (!enabled || _disposed) return;
    if (_busy) {
      _refreshAgain = true;
      return;
    }
    _busy = true;
    try {
      final response = await channel.invokeMapMethod<String, dynamic>('read', {
        'signature': _signature,
      });
      if (_disposed || response == null || response['unchanged'] == true) {
        return;
      }
      final signature = response['signature'] as String?;
      if (signature == null || signature == _signature) return;
      final next = <String>[];
      final fonts = response['fonts'] as List;
      for (var i = 0; i < fonts.length; i++) {
        final font = fonts[i] as Map;
        final bytes = await compute(extractFontFace, (
          font['bytes'] as Uint8List,
          font['index'] as int,
        ));
        final family = 'DeviceFont-$signature-$i';
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
        next.add(family);
      }
      if (_disposed) return;
      _signature = signature;
      families = List.unmodifiable(next);
      notifyListeners();
    } on MissingPluginException {
      // Tests and non-Android platforms use the engine's system fallback.
    } on PlatformException {
      // A vendor may not expose its theme font through the public API.
    } on FormatException {
      // Keep the last valid font when a native font cannot be decoded.
    } finally {
      _busy = false;
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        refresh();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}

/// Flutter FontLoader has no collection-index parameter. Rebuild the selected
/// TTC face as standalone SFNT, retaining table checksums and fixing head.
Uint8List extractFontFace((Uint8List, int) input) {
  final (bytes, face) = input;
  final data = ByteData.sublistView(bytes);
  void require(bool valid) {
    if (!valid) throw const FormatException('Invalid font');
  }

  require(bytes.length >= 12 && bytes.length <= 96 * 1024 * 1024);
  if (data.getUint32(0) != 0x74746366) return bytes;
  final count = data.getUint32(8);
  require(face >= 0 && face < count && 12 + count * 4 <= bytes.length);
  final start = data.getUint32(12 + face * 4);
  require(start + 12 <= bytes.length);
  final tables = data.getUint16(start + 4);
  require(
    tables > 0 && tables <= 256 && start + 12 + tables * 16 <= bytes.length,
  );
  var size = 12 + tables * 16;
  for (var i = 0; i < tables; i++) {
    final record = start + 12 + i * 16;
    final offset = data.getUint32(record + 8);
    final length = data.getUint32(record + 12);
    require(offset + length <= bytes.length);
    size += (length + 3) & ~3;
  }
  require(size <= 96 * 1024 * 1024);
  final output = Uint8List(size);
  final result = ByteData.sublistView(output);
  output.setRange(0, 12 + tables * 16, bytes, start);
  var cursor = 12 + tables * 16;
  int? head;
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    final offset = result.getUint32(record + 8);
    final length = result.getUint32(record + 12);
    result.setUint32(record + 8, cursor);
    output.setRange(cursor, cursor + length, bytes, offset);
    if (result.getUint32(record) == 0x68656164) {
      require(length >= 12);
      head = cursor;
      result.setUint32(cursor + 8, 0);
    }
    cursor += (length + 3) & ~3;
  }
  if (head != null) {
    var checksum = 0;
    for (var i = 0; i < output.length; i += 4) {
      checksum = (checksum + result.getUint32(i)) & 0xffffffff;
    }
    result.setUint32(head + 8, (0xb1b0afba - checksum) & 0xffffffff);
  }
  return output;
}
