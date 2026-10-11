import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, lstat } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export function verifyBuildRun(run, { runId, repository, version, sourceCommit }) {
  assert.match(String(runId), /^[1-9]\d*$/);
  assert.equal(String(run.id), String(runId), 'Unexpected build run');
  assert.equal(run.repository?.full_name, repository, 'Build belongs to another repository');
  assert.equal(run.path, '.github/workflows/publish-mcp.yaml', 'Unexpected build workflow');
  assert.equal(run.status, 'completed');
  assert.equal(run.conclusion, 'success', 'Only a successful build can be reused');
  assert.ok(['push', 'workflow_dispatch'].includes(run.event), 'PR builds cannot be published');
  assert.equal(run.head_branch, `mcp-v${version}`, 'Reuse requires a version-tag build');
  assert.equal(run.head_sha, sourceCommit, 'Build does not match the version tag');
}

export async function verifyArtifact(directory, { version, sourceCommit, runId, tagged = false }) {
  assert.match(version, /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/);
  assert.match(sourceCommit, /^[0-9a-f]{40}$/);
  assert.match(String(runId), /^[1-9]\d*$/);
  const evidence = JSON.parse(await readFile(join(directory, 'release-evidence.json'), 'utf8'));
  assert.equal(evidence.package, 'winutil-cn-mcp');
  assert.equal(evidence.version, version);
  assert.equal(evidence.filename, `winutil-cn-mcp-${version}.tgz`);
  assert.equal(evidence.sourceCommit, sourceCommit, 'Artifact source differs from the validated build');
  assert.equal(String(evidence.runId), String(runId));
  if (tagged) assert.equal(evidence.sourceRef, `refs/tags/mcp-v${version}`);
  const file = join(directory, evidence.filename);
  assert.ok((await lstat(file)).isFile(), 'Tarball must be a regular file');
  const bytes = await readFile(file);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), evidence.sha256, 'SHA256 mismatch');
  assert.equal('sha512-' + createHash('sha512').update(bytes).digest('base64'), evidence.integrity, 'SHA512 mismatch');
  return evidence;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [directory] = process.argv.slice(2);
  assert.ok(directory, 'Artifact directory is required');
  const expected = { version: process.env.PACKAGE_VERSION, sourceCommit: process.env.PACKAGE_SOURCE_COMMIT,
    runId: process.env.PACKAGE_RUN_ID, tagged: Boolean(process.env.EXISTING_RUN_ID) };
  if (process.env.EXISTING_RUN_ID) {
    const run = JSON.parse(await readFile(process.env.BUILD_RUN_FILE, 'utf8'));
    verifyBuildRun(run, { ...expected, repository: process.env.GITHUB_REPOSITORY });
  }
  const evidence = await verifyArtifact(directory, expected);
  process.stdout.write(JSON.stringify({ status: 'passed', ...evidence }) + '\n');
}
