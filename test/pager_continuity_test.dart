import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_interactions_test.dart' show launch;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('neighbor is prepared and drag reuses the mounted course grid', (
    tester,
  ) async {
    await launch(tester);
    final grids = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_ScheduleGrid',
      skipOffstage: false,
    );
    final before = tester.widgetList(grids).toList();
    expect(before.length, greaterThanOrEqualTo(2));
    final drag = await tester.startGesture(const Offset(350, 350));
    await drag.moveBy(const Offset(-80, 0));
    await tester.pump();
    var after = tester.widgetList(grids).toList();
    expect(before.every((w) => after.any((a) => identical(w, a))), isTrue);
    await drag.moveBy(const Offset(-180, 0));
    await tester.pump();
    after = tester.widgetList(grids).toList();
    expect(before.every((w) => after.any((a) => identical(w, a))), isTrue);
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('第 2 周'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('heading follows the majority-visible week during drag', (
    tester,
  ) async {
    await launch(tester);
    final drag = await tester.startGesture(const Offset(350, 350));
    await drag.moveBy(const Offset(-260, 0));
    await tester.pump();
    expect(find.text('第 2 周'), findsOneWidget);
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('第 2 周'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'second short swipe takes over in-flight target without reverting',
    (tester) async {
      await launch(tester);
      final first = await tester.startGesture(const Offset(300, 350));
      await first.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await first.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final second = await tester.startGesture(const Offset(300, 350));
      await second.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('第 3 周'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
