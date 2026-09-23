import 'dart:convert';
import '../data/models/academic_schedule.dart';
import '../data/schedule_document.dart';

class ShuImport {
  static const direct = 'https://jwxt.shu.edu.cn';
  static const vpn = 'https://https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn';
  static const indexPath =
      '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default';
  static bool isTimetableUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        (uri.host == 'jwxt.shu.edu.cn' ||
            uri.host == 'https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn');
  }

  static AcademicSchedule parse(String raw) {
    if (raw.length > ScheduleCodec.maxBytes ||
        utf8.encode(raw).length > ScheduleCodec.maxBytes) {
      throw const FormatException('学校课表数据过大');
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['kbList'] is! List ||
          data['xsxx'] is! Map ||
          (data['kbList'] as List).length > 1000 ||
          (data['sjkList'] != null &&
              (data['sjkList'] is! List ||
                  (data['sjkList'] as List).length > 500))) {
        throw const FormatException('没有读到课表，请先完成教务登录并打开个人课表页面');
      }
      // Bound range strings before passing them to the upstream parser.
      for (final row in [
        ...data['kbList'] as List,
        ...?data['sjkList'] as List?,
      ]) {
        if (row is! Map) throw const FormatException('学校课表结构异常');
        for (final key in ['zcd', 'qsjsz', 'jcs', 'jc']) {
          final value = row[key]?.toString() ?? '';
          if (value.length > 500 ||
              RegExp(r'\d+')
                  .allMatches(value)
                  .any(
                    (m) =>
                        (int.tryParse(m.group(0)!) ?? 999) >
                        (key == 'jcs' || key == 'jc' ? 12 : 32),
                  )) {
            throw const FormatException('课表周次或节次超出支持范围');
          }
        }
      }
      final schedule = anonymousSchedule(AcademicScheduleParser.parse(data));
      ScheduleCodec.validateDocument(
        ScheduleDocument(
          id: 'school',
          name: '上海大学课表',
          schedule: schedule,
          firstWeekStart: DateTime.now(),
        ).toJson(),
      );
      return schedule;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('学校返回的课表格式无法识别，请重新进入个人课表页面');
    }
  }

  static String extractionScript(String resultKey) =>
      '''
(() => {
  const key = ${jsonEncode(resultKey)};
  const origin = location.origin;
  if (![${jsonEncode(direct)}, ${jsonEncode(vpn)}].includes(origin)) return;
  window[key] = null;
  (async () => {
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), 20000);
    try {
      const value = (doc, id) => doc.querySelector('#' + id)?.value || doc.querySelector('[name="' + id + '"]')?.value || '';
      let year = value(document, 'xnm'), term = value(document, 'xqm');
      if (!year || !term) {
        const response = await fetch(origin + ${jsonEncode(indexPath)}, {credentials: 'same-origin', signal: abort.signal});
        if (!response.ok || new URL(response.url).origin !== origin) throw new Error('请先登录上海大学教务系统');
        const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
        year = value(doc, 'xnm'); term = value(doc, 'xqm');
      }
      if (!year || !term) throw new Error('请先打开个人课表页面，并选择需要导入的学期');
      const body = new URLSearchParams({xnm: year, xqm: term, kzlx: 'ck', xsdm: '', kclbdm: '', kclxdm: ''});
      const response = await fetch(origin + '/jwglxt/kbcx/xskbcx_cxXsgrkb.html?gnmkdm=N2151', {
        method: 'POST', credentials: 'same-origin', signal: abort.signal,
        headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8', 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest'},
        body: body.toString()
      });
      if (!response.ok || new URL(response.url).origin !== origin) throw new Error('登录已过期或教务系统暂时不可用');
      const text = await response.text();
      if (text.length > ${ScheduleCodec.maxBytes}) throw new Error('课表数据过大');
      const data = JSON.parse(text);
      if (!Array.isArray(data.kbList) || !data.xsxx) throw new Error('未找到课表，请打开个人课表页面后重试');
      window[key] = {data: JSON.stringify(data)};
    } catch (error) {
      window[key] = {error: error.name === 'AbortError' ? '读取超时，请检查网络后重试' : error.message};
    } finally { clearTimeout(timeout); }
  })();
})();
''';
}
