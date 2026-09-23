const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lib/services/shu_exam_import.dart','utf8');
const observe=source.match(/observeScript = r"""([\s\S]*?)"""/)[1];
const read=source.match(/readScript = r"""([\s\S]*?)"""/)[1];
const fixture=JSON.parse(fs.readFileSync('test/fixtures/shu_exams.json','utf8'));
const endpoint='/jwglxt/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105';
function context(host) {
  class XHR {
    constructor(){this.events={};this.status=200;this.responseType='';}
    addEventListener(name,fn){this.events[name]=fn;}
    open(){}
    respond(data,status=200){this.status=status;this.responseText=typeof data==='string'?data:JSON.stringify(data);this.events.load();}
  }
  const w={location:new URL('https://'+host+'/jwglxt/'),XMLHttpRequest:XHR,frames:[],
    document:{addEventListener(){},querySelectorAll(){return[];}},
    fetch:async()=>({ok:true,clone:()=>({text:async()=>JSON.stringify(fixture)})})};
  return vm.createContext({window:w,URL,Date});
}
(async()=>{
  for(const host of ['jwxt.shu.edu.cn','https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn']){
    const c=context(host); vm.runInContext(observe,c);
    const xhr=new c.window.XMLHttpRequest();xhr.open('POST',endpoint);xhr.respond(fixture);
    assert.equal(JSON.parse(vm.runInContext(read,c)).items.length,10);
    const slow=new c.window.XMLHttpRequest();slow.open('POST',endpoint);
    assert.equal(vm.runInContext(read,c),'null');
    const current=new c.window.XMLHttpRequest();current.open('POST',endpoint);current.respond('<html>login</html>');
    slow.respond(fixture);assert.equal(vm.runInContext(read,c),'null');
    await c.window.fetch(endpoint,{method:'POST'});await new Promise(r=>setImmediate(r));
    assert.equal(JSON.parse(vm.runInContext(read,c)).items.length,10);
    xhr.open('POST',endpoint);xhr.respond('error',500);assert.equal(vm.runInContext(read,c),'null');
  }
  const c=context('evil.test');vm.runInContext(observe,c);assert.equal(c.window.__shuyoExamCapture,undefined);
  console.log('WebVPN/direct XHR, fetch, stale-response rejection and host guard passed');
})();
