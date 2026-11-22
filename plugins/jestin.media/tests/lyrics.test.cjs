const test = require('node:test');
const assert = require('node:assert/strict');
const m = require('../vendor/lyrics/Model.js');
test('YouTube Topic artists and timestamp boundaries', () => {
  assert.equal(m.cleanArtist('Harris Jayaraj - Topic'), 'Harris Jayaraj');
  const lines = m.parseSynced('[00:01.00]First\n[00:05.00]Second');
  assert.equal(m.activeLine(lines, 0), -1);
  assert.equal(m.activeLine(lines, 1), 0);
  assert.equal(m.activeLine(lines, 5), 1);
  assert.equal(m.activeLine(lines, 2), 0);
});
test('remote markup remains data and is neutralized for shell tooltips', () => {
  const markup = '<img src="https://example.invalid/tracker">';
  const lines = m.parseSynced('[00:01.00]' + markup);
  assert.equal(lines[0].text, markup);
  assert.equal(m.safeDisplayText(markup), 'img src="https://example.invalid/tracker"');
  assert.equal(m.safeDisplayText(null), '');
});
test('rejects another recording with a substantially different duration', () => {
  assert.equal(m.pickCandidate([{track:'Song',artist:'Artist',duration:400,synced:'test'}], 'Artist', 'Song', 200), null);
});
