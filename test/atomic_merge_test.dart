import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'schedule_store_test.dart' show fixture;

class CountingDisk extends InMemorySharedPreferencesStore {
  CountingDisk() : super.empty();
  int writes = 0;
  bool reject = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes++;
    return reject ? false : super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'merge and selection share one commit; failed commit changes neither',
    () async {
      SharedPreferences.setMockInitialValues({});
      final disk = CountingDisk();
      SharedPreferencesStorePlatform.instance = disk;
      final store = ScheduleStore();
      await store.load();
      final target = await store.create('目标');
      final active = await store.create('当前');
      final source = ScheduleDocument(
        id: 'source',
        name: '共享课表',
        schedule: fixture(),
        firstWeekStart: target.firstWeekStart,
      );
      final before = disk.writes;
      disk.reject = true;
      await expectLater(
        store.mutate(
          target.id,
          (d) => ScheduleMerge.preview(d, source).document,
          selectAfter: true,
        ),
        throwsStateError,
      );
      expect(store.active.id, active.id);
      expect(store.byId(target.id).schedule.sessions, isEmpty);
      disk.reject = false;
      await store.mutate(
        target.id,
        (d) => ScheduleMerge.preview(d, source).document,
        selectAfter: true,
      );
      expect(
        disk.writes - before,
        2,
      ); // Exactly one failed attempt and one successful commit.
      expect(store.active.id, target.id);
      expect(store.active.schedule.sessions, isNotEmpty);
    },
  );
}
