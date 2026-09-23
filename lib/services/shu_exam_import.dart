import 'dart:convert';
import '../data/calendar_records.dart';

class ShuExamImport {
  static List<ExamRecord> parse(String raw) {
    if (raw.length > 2000000) throw const FormatException('考试数据过大');
    final Object? value = jsonDecode(raw);
    if (value is! Map || value['items'] is! List) {
      throw const FormatException('未读到考试查询结果，请完成登录并在考试安排页点击查询');
    }
    final rows = value['items'] as List;
    final total = int.tryParse(
      '${value['totalResult'] ?? value['totalCount']}',
    );
    if (total == null || total != rows.length || rows.length > 1000) {
      throw const FormatException('考试结果尚未完整加载，请在网页中调整每页条数，显示全部考试后重新查询');
    }
    final result = <ExamRecord>[];
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map) throw const FormatException('考试记录格式无效');
      String text(String key) => row[key]?.toString().trim() ?? '';
      final match = RegExp(
        r'^(\d{4}-\d{2}-\d{2})\s*[（(](\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})[)）]$',
      ).firstMatch(text('kssj'));
      if (match == null) {
        throw FormatException('${text('kcmc')}的考试时间尚未确定或格式不受支持，请保留原安排并稍后重试');
      }
      int minute(int i) {
        final h = int.parse(match.group(i)!);
        final m = int.parse(match.group(i + 1)!);
        if (h > 23 || m > 59) throw const FormatException('考试时间无效');
        return h * 60 + m;
      }

      if (text('kch').isEmpty ||
          text('sjbh').isEmpty ||
          text('xnm').isEmpty ||
          text('xqm').isEmpty) {
        throw const FormatException('缺少考试识别信息，无法安全更新');
      }
      final id =
          'shu-exam:${text('xnm')}:${text('xqm')}:${text('kch')}:${text('sjbh')}';
      if (!ids.add(id)) throw const FormatException('考试结果存在重复标识，请检查查询结果');
      result.add(
        ExamRecord(
          id: id,
          courseName: text('kcmc'),
          date: calendarDate(match.group(1)),
          startMinute: minute(2),
          endMinute: minute(4),
          location: [
            text('cdxqmc'),
            text('cdmc'),
          ].where((s) => s.isNotEmpty).join(' '),
          details: {
            for (final entry in const {
              'kch': '课程代码',
              'ksmc': '考试名称',
              'jxbmc': '教学班',
              'kccc': '课程层次',
              'xnmc': '学年',
              'xqmmc': '学期',
            }.entries)
              if (text(entry.key).isNotEmpty) entry.value: text(entry.key),
          },
        ),
      );
    }
    return result;
  }

  /// Query results update matching school exams; unrelated/manual records remain.
  static List<ExamRecord> merge(
    List<ExamRecord> existing,
    List<ExamRecord> incoming,
  ) {
    final byId = {for (final e in existing) e.id: e};
    for (final e in incoming) {
      final previous = byId[e.id];
      byId[e.id] = ExamRecord(
        id: e.id,
        courseName: e.courseName,
        date: e.date,
        startMinute: e.startMinute,
        endMinute: e.endMinute,
        location: e.location,
        seat: previous?.seat ?? e.seat,
        note: previous?.note ?? e.note,
        details: e.details,
      );
    }
    return byId.values.toList();
  }

  // Observe the school's real POST, including its existing authentication and
  // parameters. No endpoint request or student identity is synthesized.
  static const observeScript = r"""
(() => {
  function allowed(w) { try { return w.location.protocol === 'https:' &&
    ['jwxt.shu.edu.cn','https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn'].includes(w.location.hostname); } catch (_) { return false; } }
  function matches(w, raw) { try { const u=new URL(raw,w.location.href); return u.origin===w.location.origin && u.pathname.endsWith('/jwglxt/kwgl/kscx_cxXsksxxIndex.html') &&
    u.searchParams.get('doType')==='query' && u.searchParams.get('gnmkdm')==='N358105'; } catch (_) { return false; } }
  function install(w) {
    if (!allowed(w) || w.__shuyoExamCapture) return;
    const state = w.__shuyoExamCapture = {packet:null,time:0,sequence:0};
    function begin() { state.packet=null; state.time=Date.now(); return ++state.sequence; }
    function receive(data,sequence) {
      if(sequence!==state.sequence) return;
      try {
        const value=typeof data==='string'?JSON.parse(data):data;
        if(!value || !Array.isArray(value.items)) return;
        state.packet=value;
      } catch (_) {}
    }
    const open=w.XMLHttpRequest.prototype.open;
    w.XMLHttpRequest.prototype.open=function(method,url,...args) {
      this.__shuyoExamRequest=String(method).toUpperCase()==='POST' && matches(w,url);
      if(this.__shuyoExamRequest) this.__shuyoExamSequence=begin();
      if(!this.__shuyoExamListener) {
        this.__shuyoExamListener=true;
        this.addEventListener('load',()=>{
          if(this.__shuyoExamRequest && this.status>=200 && this.status<300) {
            try { receive(this.responseType==='json'?this.response:this.responseText,this.__shuyoExamSequence); } catch (_) {}
          }
        });
      }
      return open.call(this,method,url,...args);
    };
    if(w.fetch) {
      const fetch=w.fetch;
      w.fetch=function(input,init) {
        const match=String(init?.method||input?.method||'GET').toUpperCase()==='POST' && matches(w,typeof input==='string'?input:input.url);
        const sequence=match?begin():0;
        return fetch.apply(this,arguments).then(response=>{
          if(match && response.ok) response.clone().text().then(data=>receive(data,sequence)).catch(()=>{});
          return response;
        });
      };
    }
    function frames() { for(let i=0;i<w.frames.length;i++) { try { install(w.frames[i]); } catch (_) {} } }
    w.document.addEventListener('load',frames,true);
    frames();
    // A page may have finished its first query before the observer was installed.
    // Only accept a table explicitly bound to the verified exam query URL.
    for(const table of w.document.querySelectorAll('table')) {
      const p=table.p;
      if(p && matches(w,p.url) && Array.isArray(p.data) && p.data.length && p.data.every(r=>r.kssj && r.kcmc)) {
        receive({items:p.data,totalResult:Number(p.records)},begin());
      }
    }
  }
  install(window);
})();
""";

  static const readScript = r"""
(() => {
  let latest=null;
  function visit(w) { try {
    if(!['jwxt.shu.edu.cn','https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn'].includes(w.location.hostname)) return;
    const state=w.__shuyoExamCapture;
    if(state?.time && (!latest || state.time>=latest.time)) latest=state;
    for(let i=0;i<w.frames.length;i++) visit(w.frames[i]);
  } catch (_) {} }
  visit(window);
  return JSON.stringify(latest?.packet||null);
})();
""";
}
