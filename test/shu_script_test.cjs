const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const script = fs.readFileSync('.tools/shu_extract.js', 'utf8');
const fixture = JSON.parse(fs.readFileSync('test/fixtures/shu_schedule.json', 'utf8'));

async function run(origin, response, hasTerm = true) {
  const calls = [];
  const context = { window: {}, location: { origin }, URL, URLSearchParams,
    AbortController, setTimeout, clearTimeout,
    document: { querySelector: s => hasTerm ? ({ value: s.includes('xnm') ? '2026' : '3' }) : null },
    DOMParser: class { parseFromString() { return { querySelector: () => null }; } },
    fetch: async (url, options) => { calls.push({url, options}); return {
      ok: true, url, text: async () => typeof response === 'string' ? response : JSON.stringify(response),
    }; },
  };
  vm.runInNewContext(script, context);
  await new Promise(resolve => setTimeout(resolve, 20));
  return { value: context.window.test_result, calls };
}
(async () => {
  const result = await run('https://jwxt.shu.edu.cn', fixture);
  assert.ok(JSON.parse(result.value.data).kbList.length);
  assert.equal(result.calls[0].options.credentials, 'same-origin');
  assert.equal(result.calls[0].options.method, 'POST');
  assert.equal(new URLSearchParams(result.calls[0].options.body).get('xnm'), '2026');
  const vpn = await run('https://https-jwxt-shu-edu-cn-443.webvpn.shu.edu.cn', fixture);
  assert.ok(vpn.value.data);
  const foreign = await run('https://jwxt.shu.edu.cn.evil.test', fixture);
  assert.equal(foreign.calls.length, 0);
  const login = await run('https://jwxt.shu.edu.cn', '<html>登录</html>', false);
  assert.match(login.value.error, /登录|课表/);
  const invalid = await run('https://jwxt.shu.edu.cn', {});
  assert.match(invalid.value.error, /课表/);
  console.log('5 school extraction script cases passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
