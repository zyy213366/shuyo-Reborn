import { common, Want } from '@kit.AbilityKit';
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { BinaryMessenger, MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';

const MAX_FILE_BYTES: number = 2 * 1024 * 1024;

// Mirrors ScheduleFiles on Dart. All imported content still goes through
// ScheduleCodec and the user's import preview before it can change saved data.
export class SchedulePlatformBridge implements MethodCallHandler {
  private context: common.UIAbilityContext;
  private files: MethodChannel;
  private fonts: MethodChannel;
  private pending: Map<string, string>[] = [];
  private picking: boolean = false;

  constructor(context: common.UIAbilityContext, messenger: BinaryMessenger) {
    this.context = context;
    this.files = new MethodChannel(messenger, 'cn.qingke.qing_schedule/files');
    this.files.setMethodCallHandler(this);
    this.fonts = new MethodChannel(messenger, 'cn.qingke.qing_schedule/fonts');
    this.fonts.setMethodCallHandler(new SystemFontHandler());
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'takePending') {
      const events = this.pending;
      this.pending = [];
      result.success(events);
    } else if (call.method === 'pickFile') {
      this.pickFile(result);
    } else if (call.method === 'shareFile') {
      const text: Object | null = call.argument('text');
      const name: Object | null = call.argument('name');
      if (typeof text !== 'string' || typeof name !== 'string') {
        result.error('invalid_arguments', '课表内容无效', null);
        return;
      }
      this.shareFile(text, name, result);
    } else {
      result.notImplemented();
    }
  }

  private async readText(uri: string): Promise<string> {
    // Import only granted local file URIs; do not fetch links supplied by other apps.
    if (!uri.startsWith('file://')) {
      throw new Error('请选择本地 JSON 课表文件');
    }
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = await fs.stat(file.fd);
      if (stat.size <= 0 || stat.size > MAX_FILE_BYTES) {
        throw new Error('课表文件不能为空，且不能超过 2 MiB');
      }
      const buffer = new ArrayBuffer(stat.size);
      let offset = 0;
      while (offset < stat.size) {
        const chunk = new ArrayBuffer(stat.size - offset);
        const count = await fs.read(file.fd, chunk, { offset: offset, length: chunk.byteLength });
        if (count <= 0) { throw new Error('课表文件读取不完整'); }
        new Uint8Array(buffer).set(new Uint8Array(chunk, 0, count), offset);
        offset += count;
      }
      return util.TextDecoder.create('utf-8', { fatal: true }).decodeWithStream(new Uint8Array(buffer));
    } finally {
      await fs.close(file);
    }
  }

  private async pickFile(result: MethodResult): Promise<void> {
    if (this.picking) {
      result.error('busy', '文件选择器已打开', null);
      return;
    }
    this.picking = true;
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['课表文件|.json'];
      const uris = await new picker.DocumentViewPicker(this.context).select(options);
      result.success(uris.length === 0 ? null : await this.readText(uris[0]));
    } catch (error) {
      result.error('read_failed', (error as Error).message, null);
    } finally {
      this.picking = false;
    }
  }

  private async shareFile(text: string, name: string, result: MethodResult): Promise<void> {
    try {
      const bytes = new util.TextEncoder().encodeInto(text);
      if (bytes.byteLength > MAX_FILE_BYTES) { throw new Error('课表文件不能超过 2 MiB'); }
      const safeName = name.replace(/[\\/:*?"<>|\x00-\x1f]/g, '_').slice(0, 60) || '课表';
      const path = `${this.context.cacheDir}/${safeName}-${Date.now()}.json`;
      const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        let offset = 0;
        while (offset < bytes.byteLength) {
          const count = await fs.write(file.fd, bytes.slice(offset).buffer);
          if (count <= 0) { throw new Error('课表文件写入失败'); }
          offset += count;
        }
      } finally {
        await fs.close(file);
      }
      const data = new systemShare.SharedData({
        utd: uniformTypeDescriptor.getUniformDataTypeByFilenameExtension('.json'),
        uri: fileUri.getUriFromPath(path),
        title: `${safeName}.json`
      });
      await new systemShare.ShareController(data).show(this.context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
      result.success(null);
    } catch (error) {
      result.error('share_failed', (error as Error).message, null);
    }
  }

  receiveWant(want: Want): void {
    if (want.uri) { this.queueFile(want.uri); }
  }

  private async queueFile(uri: string): Promise<void> {
    const event = new Map<string, string>();
    try {
      event.set('text', await this.readText(uri));
    } catch (error) {
      event.set('error', (error as Error).message);
    }
    this.pending.push(event);
    this.files.invokeMethod('pending', null);
  }

  dispose(): void {
    this.files.setMethodCallHandler(null);
    this.fonts.setMethodCallHandler(null);
  }
}

class SystemFontHandler implements MethodCallHandler {
  onMethodCall(call: MethodCall, result: MethodResult): void {
    // System fallback is rendered by the OHOS engine. Android TextRunShaper
    // font-byte extraction cannot run on HarmonyOS.
    if (call.method === 'read') { result.success(null); }
    else { result.notImplemented(); }
  }
}
