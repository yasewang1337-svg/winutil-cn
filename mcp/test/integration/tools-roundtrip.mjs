import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdir, mkdtemp, readFile, writeFile, lstat, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { toolCommand } from '../../lib/executor.mjs';
import { windowsEnvironment } from './windows-environment.mjs';

// This file intentionally is not part of npm test. Real commands are permitted
// only on an explicitly opted-in GitHub-hosted disposable Windows machine.
function assertDisposableRunner() {
  for (const [name, value] of Object.entries({ GITHUB_ACTIONS: 'true', RUNNER_ENVIRONMENT: 'github-hosted', RUNNER_OS: 'Windows', WINUTIL_MCP_DISPOSABLE_TEST: '1' })) {
    if (process.env[name] !== value) throw new Error(`DISPOSABLE_RUNNER_REQUIRED: ${name} must equal ${value}; no changes were started.`);
  }
  assert.equal(process.platform, 'win32', 'DISPOSABLE_RUNNER_REQUIRED: Windows is required.');
  assert.ok(process.env.RUNNER_TEMP && path.isAbsolute(process.env.RUNNER_TEMP), 'An absolute RUNNER_TEMP is required.');
}

function inside(root, candidate) {
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  return relative !== '' && !relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative);
}

async function safeRemove(root, target) {
  assert.ok(inside(root, target), `Refusing deletion outside test root: ${target}`);
  const stat = await lstat(target).catch(error => { if (error.code === 'ENOENT') return null; throw error; });
  if (!stat) return;
  assert.ok(!stat.isSymbolicLink(), 'Refusing recursive deletion of a reparse/symbolic-link root.');
  await rm(target, { force: true, recursive: stat.isDirectory() });
}

function run(command, args, options = {}) {
  return new Promise(resolve => execFile(command, args, { windowsHide: true, encoding: 'utf8', timeout: 45000, maxBuffer: 2 * 1024 * 1024, ...options }, (error, stdout, stderr) => {
    resolve({ exitCode: error ? Number.isInteger(error.code) ? error.code : null : 0, stdout: String(stdout || ''), stderr: String(stderr || ''), ...(error ? { error: error.message, code: error.code, killed: Boolean(error.killed) } : {}) });
  }));
}

function toolRun(tool, args, settings = {}) {
  const command = toolCommand(tool, args, 'win32');
  return run(command.command, command.args, { ...settings, ...(command.windowsVerbatimArguments ? { windowsVerbatimArguments: true } : {}) });
}

const cli = fileURLToPath(new URL('../../index.js', import.meta.url));
const mirrors = {
  npm: { read: ['config', 'get', 'registry'], set: value => ['config', 'set', 'registry', value], seed: 'https://npm.example.invalid/original', cn: 'https://registry.npmmirror.com', official: 'https://registry.npmjs.org', file: home => path.join(home, '.npmrc') },
  pip: { read: ['config', 'get', 'global.index-url'], set: value => ['config', 'set', 'global.index-url', value], seed: 'https://pip.example.invalid/original', cn: 'https://pypi.tuna.tsinghua.edu.cn/simple', official: null, file: home => path.join(home, 'AppData', 'Roaming', 'pip', 'pip.ini') },
  yarn: { read: ['config', 'get', 'registry'], set: value => ['config', 'set', 'registry', value], seed: 'https://yarn.example.invalid/original', cn: 'https://registry.npmmirror.com', official: 'https://registry.yarnpkg.com', file: home => path.join(home, '.yarnrc') },
  go: { read: ['env', 'GOPROXY'], set: value => ['env', '-w', `GOPROXY=${value}`], seed: 'https://go.example.invalid/original,direct', cn: 'https://goproxy.cn,direct', official: 'https://proxy.golang.org,direct', file: home => path.join(home, 'go.env') },
};

function isolatedEnvironment(home, work) {
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^(?:NPM_CONFIG_|YARN_|PIP_|GOPROXY$|GOENV$|VIRTUAL_ENV$|HOME$|USERPROFILE$|APPDATA$|LOCALAPPDATA$|HOMEDRIVE$|HOMEPATH$)/i.test(key)));
  return { ...env, HOME: home, USERPROFILE: home, HOMEDRIVE: path.parse(home).root.replace(/[\\/]$/, ''), HOMEPATH: home.slice(path.parse(home).root.length - 1),
    APPDATA: path.join(home, 'AppData', 'Roaming'), LOCALAPPDATA: path.join(home, 'AppData', 'Local'),
    NPM_CONFIG_USERCONFIG: path.join(home, '.npmrc'), NPM_CONFIG_GLOBALCONFIG: path.join(home, 'global.npmrc'), NPM_CONFIG_CACHE: path.join(home, 'npm-cache'),
    GOENV: path.join(home, 'go.env'), GOCACHE: path.join(home, 'go-cache'), GOPATH: path.join(home, 'go-path'),
    PIP_DISABLE_PIP_VERSION_CHECK: '1', PIP_CACHE_DIR: path.join(home, 'pip-cache'),
    YARN_CACHE_FOLDER: path.join(home, 'yarn-cache'), INIT_CWD: work, NO_COLOR: '1' };
}

async function fileEvidence(file) {
  try {
    const bytes = await readFile(file);
    return { path: file, exists: true, sha256: createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length };
  } catch (error) { if (error.code === 'ENOENT') return { path: file, exists: false }; throw error; }
}

async function openMcp(env, cwd, record) {
  const transport = new StdioClientTransport({ command: process.execPath, args: [cli, '--allow-write', '--data-mode', 'source'], env: windowsEnvironment(env), cwd, stderr: 'pipe' });
  record.serverStderr = '';
  transport.stderr.on('data', chunk => { record.serverStderr = (record.serverStderr + String(chunk)).slice(-30000); });
  const client = new Client({ name: 'disposable-windows-roundtrip', version: '1.0.0' });
  try { await client.connect(transport); } catch (error) { await client.close(); throw error; }
  record.server = client.getServerVersion();
  return client;
}

async function call(client, name, args, record, label) {
  const response = await client.callTool({ name, arguments: args }, undefined, { timeout: 360000 });
  const payload = JSON.parse(response.content.find(item => item.type === 'text').text);
  record[label] = { isError: response.isError === true, ...payload };
  assert.notEqual(response.isError, true, `${name} ${label} failed: ${JSON.stringify(payload)}`);
  return payload;
}

async function confirm(client, name, args, record, label, beforeConfirm = async () => {}) {
  const preview = await call(client, name, args, record, `${label}Preview`);
  assert.equal(preview.preview, true);
  assert.ok(preview.planId);
  assert.equal(preview.plan.supported, true);
  await beforeConfirm();
  const result = await call(client, name, { ...args, confirm: true, planId: preview.planId }, record, label);
  assert.equal(result.status, 'completed');
  assert.ok(result.results.length > 0);
  assert.ok(result.results.every(item => item.status === 'completed' && item.exitCode === 0));
  return result;
}

async function mirrorRoundtrip(tool, root) {
  const spec = mirrors[tool], record = { scenario: 'mirror-roundtrip', tool, status: 'failed' };
  const scope = path.join(root, tool), home = path.join(scope, 'home'), work = path.join(scope, 'work');
  await mkdir(home, { recursive: true });
  await mkdir(work, { recursive: true });
  const env = isolatedEnvironment(home, work), settings = { env, cwd: work };
  let configFile = spec.file(home);
  let client, seeded = false;
  try {
    if (tool === 'pip') {
      // On Windows, pip's platformdirs may use Known Folder APIs and ignore
      // APPDATA. A real, disposable venv with an existing pip.ini selects pip's
      // native site-config mode without patching pip or touching the user file.
      const venv = path.join(scope, 'venv');
      record.createEnvironment = await run('python', ['-m', 'venv', venv], { ...settings, timeout: 120000 });
      assert.equal(record.createEnvironment.exitCode, 0);
      const pathKey = Object.keys(env).find(key => key.toLowerCase() === 'path') || 'PATH';
      env[pathKey] = `${path.join(venv, 'Scripts')}${path.delimiter}${env[pathKey] || ''}`;
      env.VIRTUAL_ENV = venv;
      configFile = path.join(venv, 'pip.ini');
      await writeFile(configFile, '', { flag: 'wx' });
      record.configurationScope = 'real disposable Python venv site configuration';
    }
    record.version = await toolRun(tool, [tool === 'go' ? 'version' : '--version'], settings);
    if (record.version.exitCode !== 0) { record.status = 'blocked'; record.reason = 'Tool is unavailable on this disposable runner.'; return record; }
    if (tool === 'yarn' && !/^1\./.test(record.version.stdout.trim())) { record.status = 'blocked'; record.reason = 'Only installed Yarn Classic 1.x can be tested.'; return record; }
    // Verify the paths the real runtimes use before the first configuration write.
    record.homeProbe = await run(process.execPath, ['-e', 'process.stdout.write(require("node:os").homedir())'], settings);
    assert.equal(path.resolve(record.homeProbe.stdout.trim()), path.resolve(home));
    if (tool === 'pip') {
      record.configProbe = await run('python', ['-c', 'import json, os, pip; from pip._internal.configuration import get_configuration_files; print(json.dumps({"files":get_configuration_files(),"pip":pip.__file__}))'], settings);
      assert.equal(record.configProbe.exitCode, 0);
      const probe = JSON.parse(record.configProbe.stdout);
      assert.ok(record.version.stdout.toLowerCase().includes(path.dirname(probe.pip).toLowerCase()), 'python and pip must refer to the same installation.');
      assert.ok(probe.files.site.every(file => inside(scope, file)), 'pip site configuration escaped the isolated venv.');
      assert.equal(path.resolve(probe.files.site.at(-1)), path.resolve(configFile));
      assert.equal((await fileEvidence(configFile)).bytes, 0, 'Only the new empty venv site configuration may be selected.');
    }
    record.initialFile = await fileEvidence(configFile);
    assert.equal(record.initialFile.exists, tool === 'pip', 'Each case must start with a fresh isolated configuration.');
    record.seed = await toolRun(tool, spec.set(spec.seed), settings);
    assert.equal(record.seed.exitCode, 0);
    seeded = true;
    record.before = await toolRun(tool, spec.read, settings);
    assert.equal(record.before.exitCode, 0);
    assert.equal(record.before.stdout.trim(), spec.seed);
    record.beforeFile = await fileEvidence(configFile);
    assert.equal(record.beforeFile.exists, true, 'The tool must write the expected isolated file.');
    client = await openMcp(env, work, record);
    const changed = await confirm(client, 'switch_mirror', { tool, action: 'cn' }, record, 'change', async () => {
      assert.deepEqual(await fileEvidence(configFile), record.beforeFile, 'Preview changed the tool configuration.');
      record.previewWasReadOnly = true;
    });
    assert.equal(changed.results[0].before.value, spec.seed);
    assert.equal(changed.results[0].recovery.previousValue, spec.seed);
    record.after = await toolRun(tool, spec.read, settings);
    assert.equal(record.after.exitCode, 0);
    assert.equal(record.after.stdout.trim(), spec.cn);
    record.afterFile = await fileEvidence(configFile);
    assert.notEqual(record.afterFile.sha256, record.beforeFile.sha256, 'Actual configuration bytes must change.');
    const official = await confirm(client, 'switch_mirror', { tool, action: 'official' }, record, 'official');
    assert.equal(official.results[0].before.value, spec.cn);
    record.afterOfficial = await toolRun(tool, spec.read, settings);
    if (spec.official === null) {
      assert.equal(record.afterOfficial.exitCode, 1);
      assert.match(record.afterOfficial.stderr || record.afterOfficial.stdout, /No such key\s*[-:]?\s*global\.index-url/i);
      await confirm(client, 'switch_mirror', { tool, action: 'official' }, record, 'officialAlreadyUnset');
      assert.equal(record.officialAlreadyUnset.results[0].before.unset, true);
    } else { assert.equal(record.afterOfficial.exitCode, 0); assert.equal(record.afterOfficial.stdout.trim(), spec.official); }
    // Mirrors expose recovery data, not a generic MCP restore command. Exercise
    // the documented native command using the exact recovery value as one argv.
    record.restore = await toolRun(tool, spec.set(changed.results[0].recovery.previousValue), settings);
    assert.equal(record.restore.exitCode, 0);
    record.restored = await toolRun(tool, spec.read, settings);
    assert.equal(record.restored.exitCode, 0);
    assert.equal(record.restored.stdout, record.before.stdout);
    record.restoredFile = await fileEvidence(configFile);
    assert.equal(record.restoredFile.sha256, record.beforeFile.sha256, 'Restoration must preserve the seeded configuration bytes.');
    record.status = 'passed';
  } catch (error) { record.error = { message: error.message, stack: error.stack }; }
  finally {
    if (client) await client.close().catch(error => { record.status = 'failed'; record.closeError = error.message; });
    if (seeded && record.status !== 'passed') {
      record.cleanupRestore = await toolRun(tool, spec.set(spec.seed), settings);
      record.cleanupReadback = await toolRun(tool, spec.read, settings);
    }
    record.finalFile = await fileEvidence(configFile);
    record.isolationRoot = scope;
  }
  return record;
}

const wingetId = 'sharkdp.hexyl'; // Official winget manifest: small, standalone portable utility.
const noApplications = result => (result.exitCode >>> 0) === 0x8A150014;
const containsPackage = result => result.exitCode === 0 && result.stdout.toLowerCase().includes(wingetId.toLowerCase());

async function installationRoundtrip(root) {
  const record = { scenario: 'install-uninstall-roundtrip', tool: 'winget', packageId: wingetId, status: 'failed', recoveryMechanism: 'native winget uninstall; MCP does not promise installer rollback' };
  let client, owned = false;
  const listArgs = ['list', '--id', wingetId, '--exact', '--accept-source-agreements', '--disable-interactivity'];
  const work = path.join(root, 'winget-work');
  await mkdir(work);
  const settings = { cwd: work, env: { ...process.env, NO_COLOR: '1' }, timeout: 180000 };
  try {
    record.version = await toolRun('winget', ['--version'], settings);
    if (record.version.exitCode !== 0) { record.status = 'blocked'; record.reason = 'winget is unavailable. No installer was downloaded or mocked.'; return record; }
    record.before = await toolRun('winget', listArgs, settings);
    if (containsPackage(record.before)) { record.status = 'blocked'; record.reason = 'Test package already exists; this test will not remove a package it does not own.'; return record; }
    if (!noApplications(record.before)) { record.status = 'blocked'; record.reason = 'Cannot establish that the test package is absent; refusing installation.'; return record; }
    client = await openMcp(settings.env, work, record);
    owned = true; // We established absence; from here cleanup is restricted to this exact package ID.
    await confirm(client, 'install_apps', { ids: [wingetId] }, record, 'install', async () => {
      record.afterPreview = await toolRun('winget', listArgs, settings);
      assert.ok(noApplications(record.afterPreview), 'Preview must not install the package.');
      record.previewWasReadOnly = true;
    });
    record.after = await toolRun('winget', listArgs, settings);
    assert.ok(containsPackage(record.after), 'winget must independently report the package after confirmed installation.');
    const executableCandidates = [process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'Microsoft', 'WinGet', 'Links', 'hexyl.exe'),
      process.env.ProgramFiles && path.join(process.env.ProgramFiles, 'WinGet', 'Links', 'hexyl.exe')].filter(Boolean);
    for (const executable of executableCandidates) {
      if ((await fileEvidence(executable)).exists) { record.executable = executable; break; }
    }
    assert.ok(record.executable, 'The real portable executable must exist in a documented winget Links directory.');
    record.installedVersion = await run(record.executable, ['--version'], settings);
    assert.equal(record.installedVersion.exitCode, 0);
    assert.match(record.installedVersion.stdout.trim(), /^hexyl\s+[0-9]+\./);
    record.uninstall = await toolRun('winget', ['uninstall', '--id', wingetId, '--exact', '--silent', '--disable-interactivity', '--accept-source-agreements'], { ...settings, timeout: 300000 });
    assert.equal(record.uninstall.exitCode, 0);
    record.restored = await toolRun('winget', listArgs, settings);
    assert.ok(noApplications(record.restored), 'The package must be absent again after uninstall.');
    assert.equal((await fileEvidence(record.executable)).exists, false, 'The installed portable executable link must also be removed.');
    owned = false;
    record.status = 'passed';
  } catch (error) { record.error = { message: error.message, stack: error.stack }; }
  finally {
    if (client) await client.close().catch(error => { record.status = 'failed'; record.closeError = error.message; });
    if (owned) {
      record.cleanupBefore = await toolRun('winget', listArgs, settings);
      if (containsPackage(record.cleanupBefore)) record.cleanupUninstall = await toolRun('winget', ['uninstall', '--id', wingetId, '--exact', '--silent', '--disable-interactivity', '--accept-source-agreements'], { ...settings, timeout: 300000 });
      record.cleanupAfter = await toolRun('winget', listArgs, settings);
      record.cleanupVerified = noApplications(record.cleanupAfter);
    }
  }
  return record;
}

async function main() {
  assertDisposableRunner(); // Deliberately before mkdir, subprocesses, or configuration reads/writes.
  const runnerTemp = path.resolve(process.env.RUNNER_TEMP);
  const evidenceDirectory = path.resolve(process.env.WINUTIL_MCP_EVIDENCE_DIR || path.join(runnerTemp, 'mcp-integration-evidence'));
  assert.ok(inside(runnerTemp, evidenceDirectory), 'Evidence must remain inside RUNNER_TEMP.');
  await mkdir(evidenceDirectory, { recursive: true });
  const root = await mkdtemp(path.join(runnerTemp, 'winutil-mcp-real-tools-'));
  const report = { schemaVersion: 1, startedAt: new Date().toISOString(), sourceCommit: process.env.GITHUB_SHA, runId: process.env.GITHUB_RUN_ID,
    environment: { githubActions: true, runnerEnvironment: process.env.RUNNER_ENVIRONMENT, runnerOS: process.env.RUNNER_OS, imageOS: process.env.ImageOS, imageVersion: process.env.ImageVersion, node: process.version, disposableRoot: root },
    scope: 'Real stdio MCP on a disposable GitHub-hosted Windows machine. All mirrors use isolated user/config paths. Only winget may install a package in the disposable runner profile.', cases: [] };
  try {
    for (const tool of Object.keys(mirrors)) {
      report.cases.push(await mirrorRoundtrip(tool, root));
      await writeFile(path.join(evidenceDirectory, 'tools-roundtrip.json'), JSON.stringify(report, null, 2));
    }
    report.cases.push(await installationRoundtrip(root));
  } catch (error) { report.error = { message: error.message, stack: error.stack }; }
  finally {
    report.finishedAt = new Date().toISOString();
    report.status = !report.error && report.cases.length === 5 && report.cases.every(item => item.status === 'passed') ? 'passed' : 'failed';
    // Preserve evidence, remove only the verified, freshly-created test directory.
    try { await safeRemove(runnerTemp, root); report.testDirectoryRemoved = true; }
    catch (error) { report.cleanupError = error.message; report.status = 'failed'; }
    await writeFile(path.join(evidenceDirectory, 'tools-roundtrip.json'), `${JSON.stringify(report, null, 2)}\n`);
    console.log(JSON.stringify({ status: report.status, evidence: path.join(evidenceDirectory, 'tools-roundtrip.json'), cases: report.cases.map(({ tool, status, reason, error }) => ({ tool, status, ...(reason ? { reason } : {}), ...(error ? { error: error.message } : {}) })) }, null, 2));
    if (report.status !== 'passed') process.exitCode = 1;
  }
}

main().catch(error => { console.error(error.message); process.exitCode = 2; });
