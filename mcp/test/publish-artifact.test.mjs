import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { verifyArtifact, verifyBuildRun } from '../release/verify-artifact.mjs';

const expected = { runId: '123456', repository: 'owner/repository', version: '0.4.1', sourceCommit: 'a'.repeat(40), tagged: true };
const run = { id: 123456, repository: { full_name: expected.repository }, path: '.github/workflows/publish-mcp.yaml',
  status: 'completed', conclusion: 'success', event: 'push', head_branch: 'mcp-v0.4.1', head_sha: expected.sourceCommit };

test('publishing only reuses a successful version-tag build from this repository and workflow', () => {
  verifyBuildRun(run, expected);
  for (const change of [{ conclusion: 'failure' }, { status: 'in_progress' }, { event: 'pull_request' }, { repository: { full_name: 'other/repository' } },
    { path: '.github/workflows/unrelated.yaml' }, { head_branch: 'main' }, { head_sha: 'b'.repeat(40) }, { id: 1 }]) {
    assert.throws(() => verifyBuildRun({ ...run, ...change }, expected));
  }
});

test('artifact reuse rejects wrong identity, traversal, changed source and modified bytes', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'winutil-publish-evidence-'));
  t.after(() => {
    assert.equal(dirname(resolve(directory)), resolve(tmpdir()), 'Only remove this test temporary directory');
    assert.ok(directory.startsWith(join(tmpdir(), 'winutil-publish-evidence-')));
    return rm(directory, { recursive: true, force: true });
  });
  const bytes = Buffer.from('artifact bytes fixture');
  const evidence = { package: 'winutil-cn-mcp', version: expected.version, filename: 'winutil-cn-mcp-0.4.1.tgz',
    sourceCommit: expected.sourceCommit, sourceRef: 'refs/tags/mcp-v0.4.1', runId: expected.runId,
    sha256: createHash('sha256').update(bytes).digest('hex'), integrity: 'sha512-' + createHash('sha512').update(bytes).digest('base64') };
  const save = value => writeFile(join(directory, 'release-evidence.json'), JSON.stringify(value));
  await writeFile(join(directory, evidence.filename), bytes);
  await save(evidence);
  assert.deepEqual(await verifyArtifact(directory, expected), evidence);
  for (const change of [{ package: 'other' }, { version: '0.3.0' }, { filename: '../escape.tgz' }, { runId: '999' },
    { sourceCommit: 'b'.repeat(40) }, { sourceRef: 'refs/heads/main' }, { integrity: 'sha512-wrong' }]) {
    await save({ ...evidence, ...change });
    await assert.rejects(verifyArtifact(directory, expected));
  }
  await save(evidence);
  await writeFile(join(directory, evidence.filename), 'changed bytes');
  await assert.rejects(verifyArtifact(directory, expected), /SHA256 mismatch/);
});
