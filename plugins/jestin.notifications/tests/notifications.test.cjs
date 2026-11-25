const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  let source = fs.readFileSync(path.join(root, name), 'utf8');
  const context = { console };
  source = source.replace(/^\.import "([^"]+)" as (\w+)\s*$/gm, (_, file, alias) => {
    context[alias] = load(file); return '';
  }).replace(/^\.pragma library\s*$/gm, '');
  vm.createContext(context); vm.runInContext(source, context, {filename: name});
  cache.set(name, context); return context;
}
const appearance = load('Appearance.js');
const duration = (urgency, requested) => appearance.durationFor(urgency, requested, 3000, 4500, 30000);
assert.equal(duration(1, 2500), 2500, 'honor a short sender timeout');
assert.equal(duration(0, -1), 3000, 'low urgency default');
assert.equal(duration(1, 0), 4500, 'normal default');
assert.equal(duration(1, NaN), 4500, 'invalid durations fall back');
assert.equal(duration(1, 1), 750, 'avoid unreadable flashes');
assert.equal(duration(1, 9999999), 30000, 'bound long durations');
assert.equal(duration(2, 1000), 0, 'critical stays until dismissed');
const store = load('Store.js');
const markup = load('Markup.js');
const malicious = '<img src="https://example.invalid/tracker"><script>alert(1)</script>';
const row = store.normalise({key: 'test', app: malicious, summary: malicious, body: malicious, urgency:1});
assert(!row.bodyRich.includes('<img'), 'remote images are never rendered');
assert(!row.bodyRich.includes('<script'), 'scripts remain inert text');
assert(!markup.render('<a href="file:///etc/passwd">click</a>').includes('href='));
assert.equal(store.restored({key:'old', urgency:1}).duration, 5000);
assert.equal(store.restored({key:'alert', urgency:2}).duration, 0);
const toast = fs.readFileSync(path.join(root,'Toast.qml'),'utf8');
const sourceLabel = toast.slice(toast.indexOf('id: sourceLabel'),toast.indexOf('// Title, marks'));
assert(sourceLabel.includes('textFormat: Text.PlainText'), 'sender label is plain text');
const title = toast.slice(toast.lastIndexOf('Text {',toast.indexOf('id: title')),toast.indexOf('id: titleMarks'));
assert(title.includes('textFormat: Text.PlainText'), 'title stays plain text');
const layout = load('Layout.js').compute([
  {key:'a',groupKey:'app:x'}, {key:'b',groupKey:'app:x'}, {key:'c',groupKey:'app:x'}
], {heightOf:()=>80});
assert.equal(layout.placements.a.front,true);
assert.equal(layout.placements.b.hidden,false);
assert.equal(layout.placements.c.hidden,true);
assert.equal(layout.height,85);
console.log('18 checks passed: timeouts, persistent critical alerts, markup safety, restoration, compact grouping.');
