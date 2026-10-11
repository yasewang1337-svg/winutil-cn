import test from 'node:test';
import assert from 'node:assert/strict';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { requireDisposableWindows, requireEvidencePath } from './integration/guard.mjs';

const fixture = { GITHUB_ACTIONS: 'true', RUNNER_ENVIRONMENT: 'github-hosted', RUNNER_OS: 'Windows',
  WINUTIL_MCP_DISPOSABLE_TEST: '1', GITHUB_RUN_ID: '1234', RUNNER_TEMP: tmpdir() };
test('disposable integration guard rejects local, self-hosted and non-Windows execution', () => {
  for (const change of [{ GITHUB_ACTIONS: undefined }, { RUNNER_ENVIRONMENT: 'self-hosted' },
    { RUNNER_OS: 'Linux' }, { WINUTIL_MCP_DISPOSABLE_TEST: undefined }, { GITHUB_RUN_ID: '' }]) {
    assert.throws(() => requireDisposableWindows({ ...fixture, ...change }, 'win32'), /LOCAL_EXECUTION_REFUSED/);
  }
  assert.throws(() => requireDisposableWindows(fixture, 'linux'), /LOCAL_EXECUTION_REFUSED/);
  assert.doesNotThrow(() => requireDisposableWindows(fixture, 'win32'));
});
test('integration evidence paths cannot escape runner temporary scope', () => {
  assert.equal(requireEvidencePath(join(tmpdir(), 'mcp-integration-evidence'), fixture), join(tmpdir(), 'mcp-integration-evidence'));
  assert.throws(() => requireEvidencePath(tmpdir(), fixture));
  assert.throws(() => requireEvidencePath(join(tmpdir(), '..', 'outside'), fixture));
});
