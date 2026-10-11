import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { readFile, writeFile, appendFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';
import { setTimeout } from 'node:timers/promises';

const run = promisify(execFile);
async function queryNpm(spec) {
  try {
    const { stdout } = await run('npm', ['view', spec, 'dist', '--json', '--prefer-online', '--registry=https://registry.npmjs.org'],
      { encoding: 'utf8', timeout: 60000, maxBuffer: 2 * 1024 * 1024 });
    return { status: 0, stdout };
  } catch (error) {
    if (typeof error.code !== 'number') throw error;
    return { status: error.code, stdout: error.stdout };
  }
}

export async function waitForRegistry(evidence, { query = queryNpm, wait = setTimeout, attempts = 21, delayMs = 15000,
  onRetry = () => {} } = {}) {
  assert.ok(Number.isInteger(attempts) && attempts > 0);
  for (let attempt = 1; attempt <= attempts; attempt++) {
    const result = await query(`${evidence.package}@${evidence.version}`);
    let dist;
    try { dist = JSON.parse(result.stdout); } catch { throw new Error('npm registry returned invalid JSON'); }
    if (result.status === 0) {
      assert.equal(dist.integrity, evidence.integrity, 'Registry package differs from the tested tarball');
      return { dist, attempts: attempt };
    }
    assert.equal(dist.error?.code, 'E404', 'Registry lookup failed; do not retry authentication or other errors');
    if (attempt === attempts) throw new Error('npm accepted the upload but the version is still unavailable; do not republish blindly');
    onRetry(attempt);
    await wait(delayMs);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const directory = process.argv[2];
  assert.ok(directory, 'Artifact directory is required');
  const evidence = JSON.parse(await readFile(join(directory, 'release-evidence.json'), 'utf8'));
  const { dist, attempts } = await waitForRegistry(evidence, {
    onRetry: attempt => process.stdout.write(`npm is still processing this version (${attempt}/21); waiting 15 seconds.\n`),
  });
  await writeFile(join(directory, 'registry-dist.json'), JSON.stringify(dist, null, 2) + '\n');
  if (process.env.GITHUB_STEP_SUMMARY) await appendFile(process.env.GITHUB_STEP_SUMMARY,
    `已发布 [${evidence.package}@${evidence.version}](https://www.npmjs.com/package/${evidence.package}/v/${evidence.version})，registry SHA512 与已测试包一致（${attempts} 次查询）。\n\nSHA256: ${evidence.sha256}\n`);
  process.stdout.write(JSON.stringify({ status: 'passed', package: evidence.package, version: evidence.version, attempts, integrity: dist.integrity }) + '\n');
}
