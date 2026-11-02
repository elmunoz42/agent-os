const test = require('node:test');
const assert = require('node:assert');
const { validateTitle, createStore } = require('./tasks');

test('US-001 AC2: blank titles are rejected', () => {
  assert.equal(validateTitle('').ok, false);
  assert.equal(validateTitle('   ').ok, false);
  assert.equal(validateTitle(undefined).ok, false);
});

test('US-001 AC2: titles are trimmed and limited to 120 characters', () => {
  assert.deepEqual(validateTitle('  Buy milk  '), { ok: true, value: 'Buy milk' });
  assert.equal(validateTitle('x'.repeat(121)).ok, false);
});

test('US-004 AC2: a title of exactly 120 characters is accepted', () => {
  assert.equal(validateTitle('x'.repeat(120)).ok, true);
});

test('US-002 AC2: toggling twice returns a task to active', () => {
  const store = createStore();
  const { value } = store.add('Write docs');
  store.toggle(value.id);
  store.toggle(value.id);
  assert.equal(store.list()[0].done, false);
});
