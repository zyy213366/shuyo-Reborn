import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/features/import_preview.dart';
import 'schedule_store_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'preview and cancellation preserve existing data; confirmation creates independent table',
    (tester) async {
      final store = ScheduleStore();
      await store.load();
      final original = await store.create('我的课表');
      final source = ScheduleDocument(
        id: 'shared',
        name: '朋友课表',
        schedule: fixture(),
        firstWeekStart: DateTime(2026, 9, 7),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) =>
                          ImportPreviewPage(store: store, source: source),
                    ),
                  );
                },
                child: const Text('预览'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();
      expect(store.documents.length, 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(store.active.id, original.id);
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认导入'));
      await tester.pumpAndSettle();
      expect(store.documents.length, 2);
      expect(store.active.name, '朋友课表');
      expect(store.active.id, isNot(source.id));
      expect(store.byId(original.id).schedule.sessions, isEmpty);
    },
  );
}
