import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qing_schedule/data/schedule_store.dart';
import 'package:qing_schedule/features/calendar_records_page.dart';
import 'package:qing_schedule/services/shu_exam_import.dart';

void main(){
 testWidgets('imported exams render by actual week and expose source details',(tester) async {
  tester.view.physicalSize=const Size(412,850);tester.view.devicePixelRatio=1;
  await (FontLoader('QingSans')..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'))).load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final store=ScheduleStore();await store.load();await store.create('考试安排');
  final exams=ShuExamImport.parse(File('test/fixtures/shu_exams.json').readAsStringSync());
  await store.mutate(store.active.id,(d)=>d.copyWith(exams:exams));
  final key=GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key:key,child:MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData(fontFamily:'QingSans'),
    home:CalendarRecordsPage(store:store,documentId:store.active.id,exams:true))));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('exam-week-grid')),findsWidgets);
  expect(find.text('计算机组成原理A(2)'),findsOneWidget);
  expect(find.text('数据结构(2)'),findsOneWidget);
  await tester.runAsync(() async {
    final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image=await boundary.toImage(pixelRatio:2);
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    File('build/previews/exams-imported.png').writeAsBytesSync(bytes!.buffer.asUint8List());image.dispose();
  });
  await tester.tap(find.text('计算机组成原理A(2)'));
  await tester.pumpAndSettle();
  expect(find.text('2025-2026春季期末考试'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());
 });
}

