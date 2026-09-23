import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:qing_schedule/features/school_import.dart';
import 'package:qing_schedule/services/shu_import_script.dart';

class FakeWebPlatform extends WebViewPlatform {
  final controller=FakeController(const PlatformWebViewControllerCreationParams());
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params)=>controller;
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params)=>FakeWebWidget(params);
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(PlatformWebViewCookieManagerCreationParams params)=>FakeCookies(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params)=>FakeNavigation(params);
}
class FakeController extends PlatformWebViewController {
  FakeController(super.params):super.implementation();
  final requests=<Uri>[];
  int clears=0;
  @override
  Future<void> loadRequest(LoadRequestParams params) async { requests.add(params.uri); }
  @override
  Future<void> clearLocalStorage() async { clears++; }
  @override
  Future<void> clearCache() async { clears++; }
  @override
  Future<void> loadHtmlString(String html,{String? baseUrl}) async {}
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}
}
class FakeCookies extends PlatformWebViewCookieManager {
  FakeCookies(super.params):super.implementation();
  @override
  Future<bool> clearCookies() async=>true;
}
class FakeNavigation extends PlatformNavigationDelegate {
  FakeNavigation(super.params):super.implementation();
  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback callback) async {}
}
class FakeWebWidget extends PlatformWebViewWidget {
  FakeWebWidget(super.params):super.implementation();
  @override
  Widget build(BuildContext context)=>const SizedBox.expand();
}
void main() {
  testWidgets('school import starts at WebVPN, exposes no alternative login and cleans up on close',(tester) async {
    final platform=FakeWebPlatform();
    WebViewPlatform.instance=platform;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const SchoolImportPage())),child:const Text('进入')))));
    await tester.tap(find.text('进入'));
    await tester.pumpAndSettle();
    expect(platform.controller.requests.single.toString(),ShuImport.vpn);
    expect(find.text('切换直连'),findsNothing);
    expect(find.text('切换 WebVPN'),findsNothing);
    await tester.tap(find.text('打开课表页'));
    await tester.pumpAndSettle();
    expect(platform.controller.requests.last.toString(),'${ShuImport.vpn}${ShuImport.indexPath}');
    await tester.tap(find.byTooltip('关闭官网'));
    await tester.pumpAndSettle();
    expect(platform.controller.clears,3);
    expect(find.text('进入'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
