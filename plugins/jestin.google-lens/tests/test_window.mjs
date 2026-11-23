import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {openWindow} from '../libexec/google-lens-window.mjs';

function environment({running = true, endpoint = true, targets = true, stale = false, navigationError = false} = {}) {
  const calls = [];
  const launched = [];
  const missing = () => { throw Object.assign(new Error('missing'), {code: 'ENOENT'}); };
  class Socket extends EventTarget {
    constructor(url) {
      super();
      this.url = url;
      queueMicrotask(() => this.dispatchEvent(new Event('open')));
    }
    send(data) {
      const command = JSON.parse(data);
      calls.push({...command, socket: this.url});
      const result = command.method === 'Page.navigate' && navigationError
        ? {error: {message: 'Navigation failed'}} : {result: {}};
      queueMicrotask(() => this.dispatchEvent(new MessageEvent('message', {
        data: JSON.stringify({id: command.id, ...result}),
      })));
    }
    close() { this.dispatchEvent(new Event('close')); }
  }
  return {calls, launched, io: {
    readFile: async () => endpoint ? '9222\n/devtools/browser/lens-browser\n' : missing(),
    readlink: async () => running ? 'hostname-12345' : missing(),
    kill: () => {},
    WebSocket: Socket,
    fetch: async url => ({ok: true, json: async () => url.endsWith('/json/version')
      ? {webSocketDebuggerUrl: `ws://127.0.0.1:9222/devtools/browser/${stale ? 'other-browser' : 'lens-browser'}`}
      : targets ? [
        {type: 'service_worker', webSocketDebuggerUrl: 'ws://127.0.0.1:9222/devtools/page/extension'},
        {type: 'page', webSocketDebuggerUrl: 'ws://127.0.0.1:9222/devtools/page/lens'},
      ] : []}),
    spawn: (executable, args, options) => {
      launched.push({executable, args, options});
      const child = new EventEmitter();
      child.unref = () => {};
      queueMicrotask(() => child.emit('spawn'));
      return child;
    },
  }};
}

test('successive searches navigate the same page without opening windows', async () => {
  const env = environment();
  for (const url of ['http://127.0.0.1:1234/first', 'http://127.0.0.1:5678/second']) {
    assert.equal(await openWindow(url, '/lens/profile', env.io), 'reused');
  }
  assert.equal(env.launched.length, 0);
  const navigation = env.calls.filter(call => call.method === 'Page.navigate');
  assert.deepEqual(navigation.map(call => call.params.url), [
    'http://127.0.0.1:1234/first', 'http://127.0.0.1:5678/second',
  ]);
  assert.ok(navigation.every(call => call.socket.endsWith('/page/lens')));
  assert.equal(env.calls.filter(call => call.method === 'Page.bringToFront').length, 2);
});

test('first launch preserves the profile and enables loopback control', async () => {
  const env = environment({running: false, endpoint: false});
  assert.equal(await openWindow('http://127.0.0.1:1234/new', '/lens/profile', env.io), 'opened');
  const {args, executable} = env.launched[0];
  assert.equal(executable, 'chromium');
  assert.ok(args.includes('--user-data-dir=/lens/profile'));
  assert.ok(args.includes('--remote-debugging-address=127.0.0.1'));
  assert.ok(args.includes('--remote-debugging-port=0'));
});

test('old running browser requests a one-time close instead of duplicating it', async () => {
  const env = environment({endpoint: false});
  await assert.rejects(openWindow('http://127.0.0.1:1234/new', '/lens/profile', env.io), /Close all existing Google Lens windows once/);
  assert.equal(env.launched.length, 0);
});

test('stale port cannot control a different browser', async () => {
  const env = environment({stale: true});
  await assert.rejects(openWindow('http://127.0.0.1:1234/new', '/lens/profile', env.io), /Close all existing/);
  assert.equal(env.calls.length, 0);
  assert.equal(env.launched.length, 0);
});

test('a browser with no page opens a replacement window', async () => {
  const env = environment({targets: false});
  assert.equal(await openWindow('http://127.0.0.1:1234/new', '/lens/profile', env.io), 'opened');
  assert.equal(env.launched.length, 1);
});

test('failed navigation does not silently create a duplicate', async () => {
  const env = environment({navigationError: true});
  await assert.rejects(openWindow('http://127.0.0.1:1234/new', '/lens/profile', env.io), /Navigation failed/);
  assert.equal(env.launched.length, 0);
});
