
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { AbilityConstant, Want } from '@kit.AbilityKit';
import { SchedulePlatformBridge } from '../platform/SchedulePlatformBridge';

export default class EntryAbility extends FlutterAbility {
  private scheduleBridge?: SchedulePlatformBridge;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
    this.scheduleBridge?.receiveWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    this.scheduleBridge?.receiveWant(want);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    this.scheduleBridge = new SchedulePlatformBridge(this.context,
      flutterEngine.getDartExecutor().getBinaryMessenger());
  }

  onDestroy(): void {
    this.scheduleBridge?.dispose();
    super.onDestroy();
  }
}
