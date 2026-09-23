import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'schedule_store_test.dart' show fixture;
import 'dart:convert';

class FailingDisk extends InMemorySharedPreferencesStore {
  FailingDisk() : super.empty();
  bool reject = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (reject) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed writes never reappear when loading through singleton cache',
    () async {
      SharedPreferences.setMockInitialValues({});
      final disk = FailingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      final store = ScheduleStore();
      await store.load();
      await store.create('原有课表');
      disk.reject = true;
      await expectLater(store.create('不应出现'), throwsStateError);
      final restarted = ScheduleStore();
      await restarted.load();
      expect(restarted.documents.map((d) => d.name), ['原有课表']);
    },
  );
  test('duplicate IDs and impossible dates are rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ScheduleStore();
    await store.load();
    final doc = await store.create('课表', schedule: fixture());
    final data = jsonDecode(ScheduleCodec.encode(doc)) as Map<String, dynamic>;
    final sessions = data['document']['schedule']['sessions'] as List;
    sessions[1]['id'] = sessions[0]['id'];
    expect(() => ScheduleCodec.decode(jsonEncode(data)), throwsFormatException);
    final badDate =
        jsonDecode(ScheduleCodec.encode(doc)) as Map<String, dynamic>;
    badDate['document']['firstWeekStart'] = '2026-02-31';
    expect(
      () => ScheduleCodec.decode(jsonEncode(badDate)),
      throwsFormatException,
    );
  });
}
