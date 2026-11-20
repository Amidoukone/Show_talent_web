// Browser regression against the locally compiled Flutter PDF preview.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {spawn} from 'node:child_process';
import {createReadStream, existsSync, mkdirSync, readFileSync, statSync, writeFileSync} from 'node:fs';
import path from 'node:path';

const output = path.resolve('build/audit-2026-11-20');
mkdirSync(output, {recursive: true});
const profile = path.join(output, `chrome-${Date.now()}`);
const webRoot = path.resolve('build/document-preview-smoke');
assert.ok(existsSync(path.join(webRoot, 'main.dart.js')), 'Build the document preview fixture first');
const mime = {'.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm',
  '.json':'application/json', '.css':'text/css', '.mjs':'application/javascript'};
const server = createServer((req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  const file = path.resolve(webRoot, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(webRoot + path.sep) || !existsSync(file) || !statSync(file).isFile()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, {'Content-Type': mime[path.extname(file)] ?? 'application/octet-stream'});
  createReadStream(file).pipe(res);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
const browser = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', [
  '--headless=new', '--disable-gpu', '--no-first-run',
  '--no-default-browser-check', '--disable-background-networking',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, origin,
], {windowsHide: true, stdio: 'ignore'});
let socket;
try {
  const portFile = path.join(profile, 'DevToolsActivePort');
  for (let attempt = 0; !existsSync(portFile) && attempt < 100; attempt++) {
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.ok(existsSync(portFile), 'Chrome debugging endpoint unavailable');
  const port = readFileSync(portFile, 'utf8').split(/\r?\n/)[0];
  const list = async () => (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json())
    .filter(page => page.type === 'page');
  const before = await list();
  socket = new WebSocket(before[0].webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, {once: true});
    socket.addEventListener('error', reject, {once: true});
  });
  let sequence = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (!message.id) return;
    const task = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) task.reject(new Error(message.error.message));
    else task.resolve(message.result);
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, {resolve, reject});
    socket.send(JSON.stringify({id, method, params}));
  });
  async function evaluate(expression) {
    const result = await send('Runtime.evaluate', {expression, awaitPromise: true, returnByValue: true});
    if (result.exceptionDetails) throw Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    return result.result.value;
  }
  async function until(expression) {
    for (let n = 0; n < 200; n++) {
      const value = await evaluate(expression);
      if (value) return value;
      await new Promise(resolve => setTimeout(resolve, 150));
    }
    throw Error('Browser condition timed out: ' + expression);
  }
  const url = await until("document.querySelector('object[type=\"application/pdf\"]')?.data");
  assert.ok(url.startsWith('blob:' + origin + '/'));
  assert.equal(await evaluate("fetch(" + JSON.stringify(url) + ").then(r=>r.text()).then(t=>t.slice(0,5))"), '%PDF-');
  await evaluate('window.closePreview()');
  await until('window.previewClosed && !document.querySelector("object")');
  assert.equal(await evaluate("fetch(" + JSON.stringify(url) + ").then(()=>false,()=>true)"), true);
  const after = await list();
  assert.equal(after.length, before.length);
  const evidence = {pdfPreviewMounted: true, localBytesReadable: true,
    localUrlRevokedOnClose: true, newTabs: after.length - before.length};
  writeFileSync(path.join(output, 'browser-document-open.json'), JSON.stringify(evidence, null, 2));
  console.log(JSON.stringify(evidence, null, 2));
  await send('Browser.close').catch(() => {});
} finally {
  socket?.close();
  browser.kill();
  await new Promise(resolve => server.close(resolve));
}
