import test from 'node:test';
import assert from 'node:assert/strict';
import { waitForRegistry } from '../release/wait-registry.mjs';

const evidence = { package: 'winutil-cn-mcp', version: '0.4.1', integrity: 'sha512-tested' };
const missing = { status: 1, stdout: JSON.stringify({ error: { code: 'E404' } }) };
const available = { status: 0, stdout: JSON.stringify({ integrity: evidence.integrity }) };

test('publication waits for npm processing and verifies the same package without republishing', async () => {
  const replies = [missing, missing, available];
  const pauses = [];
  const result = await waitForRegistry(evidence, {
    query: async spec => { assert.equal(spec, 'winutil-cn-mcp@0.4.1'); return replies.shift(); },
    wait: async ms => { pauses.push(ms); },
  });
  assert.equal(result.attempts, 3);
  assert.deepEqual(pauses, [15000, 15000]);
});

test('registry verification stops on mismatched bytes, auth errors, malformed responses and timeout', async () => {
  for (const reply of [
    { status: 0, stdout: JSON.stringify({ integrity: 'sha512-other' }) },
    { status: 1, stdout: JSON.stringify({ error: { code: 'E401' } }) },
    { status: 0, stdout: 'not JSON' },
  ]) {
    await assert.rejects(waitForRegistry(evidence, { query: async () => reply,
      wait: async () => { assert.fail('Non-transient failure must not wait'); } }));
  }
  let calls = 0;
  await assert.rejects(waitForRegistry(evidence, { attempts: 3, query: async () => { calls++; return missing; },
    wait: async () => {} }), /still unavailable/);
  assert.equal(calls, 3);
});
