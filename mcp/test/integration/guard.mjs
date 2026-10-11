import assert from 'node:assert/strict';
import { isAbsolute, relative, resolve } from 'node:path';

export function requireDisposableWindows(env = process.env, platform = process.platform) {
  assert.ok(platform === 'win32' && env.GITHUB_ACTIONS === 'true'
    && env.RUNNER_ENVIRONMENT === 'github-hosted' && env.RUNNER_OS === 'Windows'
    && env.WINUTIL_MCP_DISPOSABLE_TEST === '1' && /^\d+$/.test(env.GITHUB_RUN_ID || ''),
  'LOCAL_EXECUTION_REFUSED: real mutation tests only run on an explicitly enabled GitHub-hosted disposable Windows VM.');
  assert.ok(env.RUNNER_TEMP && isAbsolute(env.RUNNER_TEMP), 'RUNNER_TEMP is required');
}

export function requireEvidencePath(path, env = process.env) {
  const target = resolve(path), root = resolve(env.RUNNER_TEMP);
  const within = relative(root, target);
  assert.ok(within && !within.startsWith('..') && !isAbsolute(within), 'Evidence must stay below RUNNER_TEMP');
  return target;
}
