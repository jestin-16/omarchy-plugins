// Control only the plugin's dedicated Chromium profile over loopback.
import {readFile, readlink} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';

const defaults = {readFile, readlink, spawn, fetch: globalThis.fetch,
  WebSocket: globalThis.WebSocket, kill: process.kill};

async function browserRunning(profile, io) {
  try {
    const lock = await io.readlink(join(profile, 'SingletonLock'));
    const pid = Number(lock.match(/-(\d+)$/)?.[1]);
    if (!Number.isSafeInteger(pid) || pid <= 0) return false;
    io.kill(pid, 0);
    return true;
  } catch (error) {
    return error.code === 'EPERM';
  }
}

async function pages(profile, io) {
  let port, browserPath;
  try {
    [port, browserPath] = (await io.readFile(join(profile, 'DevToolsActivePort'), 'utf8')).trim().split('\n');
    if (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535 ||
        !/^\/devtools\/browser\/[\w-]+$/.test(browserPath)) return null;
    const origin = `http://127.0.0.1:${port}`;
    const get = async path => {
      const response = await io.fetch(origin + path, {signal: AbortSignal.timeout(1500), redirect: 'error'});
      if (!response.ok) throw new Error('Browser control unavailable');
      return response.json();
    };
    const version = await get('/json/version');
    // A stale port file must never connect us to a different browser.
    if (version.webSocketDebuggerUrl !== `ws://127.0.0.1:${port}${browserPath}`) return null;
    const targets = await get('/json/list');
    if (!Array.isArray(targets)) throw new Error('Invalid browser target list');
    return targets.filter(target => target.type === 'page' &&
      typeof target.webSocketDebuggerUrl === 'string' &&
      target.webSocketDebuggerUrl.startsWith(`ws://127.0.0.1:${port}/devtools/page/`));
  } catch (error) {
    return null;
  }
}

export async function navigate(socketUrl, url, WebSocketImpl = WebSocket) {
  const socket = new WebSocketImpl(socketUrl);
  let sequence = 0;
  const pending = new Map();
  const rejectAll = error => {
    for (const task of pending.values()) task.reject(error);
    pending.clear();
  };
  const timer = setTimeout(() => {
    rejectAll(new Error('Lens window did not respond within 10 seconds.'));
    socket.close();
  }, 10000);
  try {
    await new Promise((resolve, reject) => {
      pending.set(0, {reject});
      socket.addEventListener('open', () => { pending.delete(0); resolve(); }, {once: true});
      socket.addEventListener('error', () => rejectAll(new Error('Could not connect to Lens window.')));
      socket.addEventListener('close', () => rejectAll(new Error('Lens window was closed.')));
      socket.addEventListener('message', event => {
        let message;
        try { message = JSON.parse(event.data); } catch { return; }
        const task = pending.get(message.id);
        if (!task) return;
        pending.delete(message.id);
        if (message.error) task.reject(new Error(message.error.message));
        else task.resolve(message.result);
      });
    });
    const command = (method, params = {}) => new Promise((resolve, reject) => {
      const id = ++sequence;
      pending.set(id, {resolve, reject});
      socket.send(JSON.stringify({id, method, params}));
    });
    await command('Page.bringToFront');
    const result = await command('Page.navigate', {url});
    if (result.errorText) throw new Error(result.errorText);
  } finally {
    clearTimeout(timer);
    socket.close();
  }
}

export async function openWindow(url, profile, io = defaults) {
  const targets = await pages(profile, io);
  if (targets?.length) {
    await navigate(targets[0].webSocketDebuggerUrl, url, io.WebSocket);
    return 'reused';
  }
  if (targets === null && await browserRunning(profile, io)) {
    throw new Error('Close all existing Google Lens windows once, then retry. The running browser was started without window reuse enabled.');
  }
  const child = io.spawn('chromium', [
    `--app=${url}`, `--user-data-dir=${profile}`,
    '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0',
    '--class=chrome-lens.google.com__overlay', '--no-first-run',
    '--no-default-browser-check', '--disable-features=Translate', '--ozone-platform=wayland',
    '--disable-background-mode',
  ], {detached: true, stdio: ['ignore', 'inherit', 'inherit']});
  await new Promise((resolve, reject) => {
    child.once('spawn', resolve);
    child.once('error', reject);
  });
  child.unref();
  return 'opened';
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (typeof WebSocket !== 'function') throw new Error('Node.js 22 or newer is required.');
    const [, , url, profile] = process.argv;
    if (!url || !profile) throw new Error('Expected upload URL and Lens profile directory.');
    await openWindow(url, profile);
  } catch (error) {
    console.error(`Google Lens: ${error.message}`);
    process.exitCode = 1;
  }
}
