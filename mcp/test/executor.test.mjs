import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { createExecutor, describeTweak, toolCommand, defaultRunner } from '../lib/executor.mjs';

const GUID = '11111111-2222-3333-4444-555555555555';
const adapter = { id: GUID, interfaceIndex: 7, name: '以太网', macAddress: '00-11-22-33-44-55', description: 'Fixture adapter', status: 'completed' };
const tweak = { Content: 'Fixture', registry: [{ Path: 'HKCU:\\Software\\Fixture', Name: 'Test', Type: 'DWord', Value: '1' }] };
const data = { apps: { wechat: { content: '微信', winget: 'Tencent.WeChat' }, WPFInstallgit: { content: 'Git', winget: 'Git.Git' }, noPackage: { content: 'None' } }, tweaks: { plain: tweak }, dns: { Fixture: { Primary: '1.1.1.1', Secondary: '1.0.0.1', Primary6: '2606:4700:4700::1111' } } };
const success = (stdout = '') => ({ exitCode: 0, stdout, stderr: '' });
const jsonResult = (results = [{ status: 'completed' }], extra = {}) => success(JSON.stringify({ schemaVersion: 1, status: 'completed', results, ...extra }));
async function sandbox(t) {
  const root = await mkdtemp(join(tmpdir(), 'winutil-mcp-executor-test-'));
  t.after(async () => {
    const suffix = relative(resolve(tmpdir()), resolve(root));
    assert.ok(suffix && !suffix.startsWith('..') && !isAbsolute(suffix));
    await rm(root, { recursive: true, force: true });
  });
  return root;
}
function injected(t, runner, extra = {}) {
  return sandbox(t).then(tempDirectory => createExecutor({ platform: 'win32', runner, tempDirectory, ...extra }));
}

test('declarative registry/service shapes are normalized without mutating the catalog', () => {
  const result = describeTweak({ ...tweak, service: [{ Name: 'FixtureSvc', StartupType: 'Disable', OriginalType: 'Manual' }] });
  assert.equal(result.supported, true);
  assert.deepEqual(result.services, [{ name: 'FixtureSvc', startupType: 'Disabled' }]);
  assert.equal(result.registry[0].value, '1');
  assert.equal(describeTweak({ ...tweak, registry: [{ ...tweak.registry[0], Name: '(default)', Type: 'String', Value: '' }] }).registry[0].name, '');
});

for (const [name, change] of Object.entries({
  script: { InvokeScript: ['throw "boom"'] }, undoScript: { UndoScript: ['script'] }, appx: { appx: ['package'] }, unknown: { futureAction: ['thing'] }, combo: { LinkedCombo: 'x' },
  hku: { registry: [{ ...tweak.registry[0], Path: 'HKU:\\Default\\Anything' }] },
  wildcard: { registry: [{ ...tweak.registry[0], Path: 'HKCU:\\Software\\*' }] },
  traversal: { registry: [{ ...tweak.registry[0], Path: 'HKCU:\\..\\Anything' }] },
  placeholder: { registry: [{ ...tweak.registry[0], Value: '<RemoveEntry>' }] },
  overflow: { registry: [{ ...tweak.registry[0], Value: '4294967296' }] },
  invalidService: { service: [{ Name: '*', StartupType: 'Automatic' }] },
})) test(`whole tweak is unsupported for ${name}`, () => {
  const result = describeTweak({ ...tweak, ...change });
  assert.equal(result.supported, false); assert.ok(result.reason);
});

test('package aliases normalize in both directions and deduplicate package IDs', async t => {
  const e = await injected(t, () => { throw new Error('preview must not execute'); });
  const plan = await e.plan('install_apps', { ids: ['wechat', 'WPFInstallwechat', 'Tencent.WeChat', 'git', 'WPFInstallgit'] }, data);
  assert.deepEqual(plan.packages.map(p => p.id), ['Tencent.WeChat', 'Git.Git']);
  assert.equal(plan.supported, true); assert.equal(Object.isFrozen(plan.packages[0]), true);
});

test('flags and invalid packages block the complete plan before dispatch', async t => {
  const e = await injected(t, () => { throw new Error('unexpected dispatch'); });
  for (const id of ['--override', 'Good.Id --silent', 'A;calc', 'noPackage']) {
    const plan = await e.plan('install_apps', { ids: ['Git.Git', id] }, data);
    assert.equal(plan.supported, false);
    await assert.rejects(e.execute('install_apps', plan), { code: 'UNSUPPORTED_PLAN' });
  }
});

test('forged, copied, or reused plans are rejected', async t => {
  const e = await injected(t, async () => success());
  const plan = await e.plan('install_apps', { ids: ['Git.Git'] }, data);
  await assert.rejects(e.execute('install_apps', structuredClone(plan)), { code: 'INVALID_PLAN' });
  assert.equal((await e.execute('install_apps', plan)).status, 'completed');
  await assert.rejects(e.execute('install_apps', plan), { code: 'INVALID_PLAN' });
});

test('winget exit codes determine per-package results and retain both streams', async t => {
  const calls = [];
  const e = await injected(t, async (command, args) => {
    calls.push({ command, args });
    if (args.includes('--version')) return success('v1.0');
    if (args.includes('Git.Git')) return { exitCode: 5, stdout: 'Successfully installed', stderr: 'Access denied' };
    return success('untranslated output');
  });
  const plan = await e.plan('install_apps', { ids: ['Git.Git', 'Tencent.WeChat'] }, data);
  const result = await e.execute('install_apps', plan);
  assert.equal(result.status, 'partial');
  assert.equal(result.results[0].status, 'failed'); assert.equal(result.results[0].exitCode, 5); assert.equal(result.results[0].stderr, 'Access denied');
  assert.equal(result.results[1].status, 'completed');
  assert.deepEqual(calls[1].args, ['install', '--id', 'Git.Git', '--exact', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity']);
});

test('missing tools stop before changes', async t => {
  let calls = 0;
  const e = await injected(t, async () => { calls++; return { exitCode: null, code: 'ENOENT', stderr: '', stdout: '', error: 'not found' }; });
  const result = await e.execute('install_apps', await e.plan('install_apps', { ids: ['Git.Git'] }, data));
  assert.equal(result.status, 'failed'); assert.equal(result.code, 'TOOL_UNAVAILABLE'); assert.equal(calls, 1);
});

test('Windows .cmd tools use a fixed command line with no arbitrary shell arguments', () => {
  const command = toolCommand('npm', ['config', 'set', 'registry', 'https://registry.npmmirror.com'], 'win32');
  assert.match(command.command, /cmd\.exe$/); assert.equal(command.windowsVerbatimArguments, true);
  assert.deepEqual(command.args, ['/d', '/s', '/c', 'npm.cmd config set registry https://registry.npmmirror.com']);
  assert.throws(() => toolCommand('npm', ['https://safe/&calc'], 'win32'), { code: 'INVALID_COMMAND' });
});

test('mirror change captures previous value and does not hide execution errors', async t => {
  const calls = [];
  const e = await injected(t, async (command, args) => {
    calls.push(args);
    if (args.at(-1).includes('--version')) return success('11.0.0');
    if (args.at(-1).includes('config get')) return success('https://old.example/\n');
    return { exitCode: 1, stdout: 'configuration updated', stderr: 'EACCES' };
  });
  const result = await e.execute('switch_mirror', await e.plan('switch_mirror', { tool: 'npm', action: 'cn' }, data));
  assert.equal(result.status, 'failed'); assert.equal(result.results[0].before.value, 'https://old.example/');
  assert.equal(result.results[0].stderr, 'EACCES'); assert.equal(calls.length, 3);
});

test('Yarn Berry is rejected before config writes', async t => {
  let calls = 0;
  const e = await injected(t, async () => { calls++; return success('4.9.0'); });
  const result = await e.execute('switch_mirror', await e.plan('switch_mirror', { tool: 'yarn', action: 'cn' }, data));
  assert.equal(result.code, 'UNSUPPORTED_YARN'); assert.equal(calls, 1);
});

test('pip default restoration treats specifically absent config as a no-op', async t => {
  let calls = 0;
  const e = await injected(t, async (_command, args) => {
    calls++;
    return args.includes('--version') ? success('pip 26') : { exitCode: 1, stdout: '', stderr: 'ERROR: No such key - global.index-url' };
  });
  const result = await e.execute('switch_mirror', await e.plan('switch_mirror', { tool: 'pip', action: 'official' }, data));
  assert.equal(result.status, 'completed'); assert.equal(result.results[0].before.unset, true); assert.equal(calls, 2);
});

test('DNS requires explicit stable adapter selection', async t => {
  let calls = 0;
  const e = await injected(t, async () => { calls++; return jsonResult([adapter]); });
  await assert.rejects(e.plan('set_dns', { provider: 'Fixture' }, data), { code: 'ADAPTER_SELECTION_REQUIRED' });
  assert.equal(calls, 0);
  const plan = await e.plan('set_dns', { provider: 'Fixture', adapterIds: [GUID] }, data);
  assert.equal(plan.adapters[0].interfaceIndex, 7); assert.equal(plan.adapters[0].macAddress, adapter.macAddress);
  assert.deepEqual(plan.addresses, ['1.1.1.1', '1.0.0.1', '2606:4700:4700::1111']);
});

test('worker requests are static JSON, digest-bound, without policy bypass, and cleaned', async t => {
  const temporaryRoot = await sandbox(t);
  let inputPath;
  const e = createExecutor({ platform: 'win32', tempDirectory: temporaryRoot, runner: async (_command, args) => {
    assert.ok(args.includes('-File')); assert.ok(!args.includes('-Command')); assert.ok(!args.includes('-ExecutionPolicy'));
    inputPath = args[args.indexOf('-InputPath') + 1];
    const body = await readFile(inputPath, 'utf8');
    assert.equal(createHash('sha256').update(body).digest('hex'), args[args.indexOf('-ExpectedSha256') + 1]);
    const payload = JSON.parse(body);
    assert.equal(payload.operation, 'apply_tweaks'); assert.equal(payload.tweaks[0].registry[0].value, '1');
    return jsonResult([{ status: 'completed', key: 'plain' }], { backupId: payload.backupId });
  } });
  const result = await e.execute('apply_tweaks', await e.plan('apply_tweaks', { keys: ['plain'] }, data));
  assert.equal(result.status, 'completed'); assert.match(result.backupId, /^[0-9a-f-]{36}$/); assert.equal(result.backupStatus, 'confirmed');
  await assert.rejects(readFile(inputPath), { code: 'ENOENT' }); assert.deepEqual(await readdir(temporaryRoot), []);
});

for (const [name, response] of Object.entries({
  completionMarker: { exitCode: 0, stdout: '__TWEAK_DONE__', stderr: 'Permission denied' },
  missingFunction: { exitCode: 0, stdout: 'DNS 已恢复默认', stderr: 'Invoke-WinUtilVerifiedTool not found' },
  stderrAfterSuccess: { ...jsonResult(), stderr: 'Access denied' },
  emptySuccess: jsonResult([]),
  inconsistentSuccess: jsonResult([{ status: 'failed', error: 'Access denied' }]),
})) test(`worker failure ${name} cannot report completed`, async t => {
  const root = await sandbox(t);
  const e = createExecutor({ platform: 'win32', tempDirectory: root, runner: async () => response });
  const result = await e.execute('apply_tweaks', await e.plan('apply_tweaks', { keys: ['plain'] }, data));
  assert.notEqual(result.status, 'completed'); assert.deepEqual(await readdir(root), []);
});

test('worker spawn exceptions clean request files', async t => {
  const root = await sandbox(t);
  const e = createExecutor({ platform: 'win32', tempDirectory: root, runner: async () => { throw new Error('fixture spawn failure'); } });
  const result = await e.execute('apply_tweaks', await e.plan('apply_tweaks', { keys: ['plain'] }, data));
  assert.equal(result.status, 'failed'); assert.deepEqual(await readdir(root), []);
});

test('PowerShell policy failures expose stable codes and original stderr without mutation recovery advice for queries', async t => {
  const stderr = 'File worker.ps1 cannot be loaded because running scripts is disabled on this system. PSSecurityException';
  const e = await injected(t, async () => ({ exitCode: 1, code: 1, stdout: '', stderr }));
  await assert.rejects(e.listNetworkAdapters(), error => {
    assert.equal(error.code, 'POLICY_BLOCKED'); assert.equal(error.details.processCode, 1);
    assert.equal(error.details.stderr, stderr); assert.equal(error.details.exitCode, 1);
    assert.equal(error.details.backupId, undefined); assert.equal(error.details.outcomeKnown, true);
    assert.doesNotMatch(error.message, /backupId|恢复|pending/); return true;
  });
  const result = await e.execute('apply_tweaks', await e.plan('apply_tweaks', { keys: ['plain'] }, data));
  assert.equal(result.code, 'POLICY_BLOCKED'); assert.equal(result.backupId, undefined); assert.equal(result.status, 'failed');
});

test('worker start errors and structured failure codes cannot be overwritten by numeric process codes', async t => {
  const missing = await injected(t, async () => ({ exitCode: null, code: 'ENOENT', stdout: '', stderr: '', error: 'not found' }));
  await assert.rejects(missing.listNetworkAdapters(), error => {
    assert.equal(error.code, 'WORKER_START_FAILED'); assert.equal(error.details.processCode, 'ENOENT'); assert.doesNotMatch(error.message, /backupId|恢复/); return true;
  });
  const denied = await injected(t, async () => ({ exitCode: 1, code: 1, stdout: JSON.stringify({ schemaVersion: 1, status: 'failed', code: 'WORKER_FAILED', message: 'ADMIN_REQUIRED', results: [] }), stderr: '' }));
  const result = await denied.execute('apply_tweaks', await denied.plan('apply_tweaks', { keys: ['plain'] }, data));
  assert.equal(result.code, 'WORKER_FAILED'); assert.equal(result.processCode, 1); assert.equal(result.message, 'ADMIN_REQUIRED');
});

test('interrupted worker retains confirmed backup and completed range from JSON checkpoints', async t => {
  const abort = new AbortController();
  const root = await sandbox(t);
  let id;
  const e = createExecutor({ platform: 'win32', tempDirectory: root, runner: async (_command, args) => {
    const request = JSON.parse(await readFile(args[args.indexOf('-InputPath') + 1], 'utf8'));
    id = request.backupId;
    abort.abort();
    return { exitCode: null, code: 'ABORT_ERR', stdout: JSON.stringify({ schemaVersion: 1, checkpoint: true, backupId: id, results: [{ key: 'plain', name: 'A', status: 'completed' }], pending: { key: 'plain', name: 'B' } }) + '\n', stderr: '' };
  } });
  const result = await e.execute('apply_tweaks', await e.plan('apply_tweaks', { keys: ['plain'] }, data), { signal: abort.signal });
  assert.equal(result.status, 'partial'); assert.equal(result.backupId, id); assert.equal(result.backupStatus, 'confirmed');
  assert.equal(result.results[0].name, 'A'); assert.equal(result.pending.name, 'B'); assert.equal(result.outcomeKnown, false);
  assert.deepEqual(await readdir(root), []);
});

test('worker termination before a checkpoint retains an explicitly unconfirmed backup ID', async t => {
  const e = await injected(t, async () => ({ exitCode: null, killed: true, signal: 'SIGTERM', stdout: '', stderr: '' }));
  const result = await e.execute('apply_tweaks', await e.plan('apply_tweaks', { keys: ['plain'] }, data));
  assert.equal(result.status, 'failed'); assert.equal(result.backupStatus, 'unconfirmed'); assert.equal(result.outcomeKnown, false);
  assert.equal(result.code, 'WORKER_INTERRUPTED');
  assert.match(result.backupId, /^[0-9a-f-]{36}$/);
});

test('abort stops later packages and never reports completed', async t => {
  const abort = new AbortController();
  let installs = 0;
  const e = await injected(t, async (_command, args) => {
    if (args.includes('install')) { installs++; abort.abort(); }
    return success();
  });
  const p = await e.plan('install_apps', { ids: ['Git.Git', 'Tencent.WeChat'] }, data);
  const result = await e.execute('install_apps', p, { signal: abort.signal });
  assert.equal(result.status, 'cancelled'); assert.equal(installs, 1);
});

test('default runner waits for process exit and preserves real stderr/exit code', async () => {
  const result = await defaultRunner(process.execPath, ['-e', 'process.stdout.write("done"); process.stderr.write("failure"); process.exitCode=7']);
  assert.equal(result.exitCode, 7); assert.equal(result.stdout, 'done'); assert.equal(result.stderr, 'failure');
});

test('non-Windows environments can preview but cannot execute changes', async t => {
  const e = await injected(t, () => { throw new Error('must not dispatch'); }, { platform: 'linux' });
  const p = await e.plan('install_apps', { ids: ['Git.Git'] }, data);
  assert.equal(p.supported, false); await assert.rejects(e.execute('install_apps', p), { code: 'UNSUPPORTED_PLAN' });
});

test('static PowerShell execution core reports real mocked failures without changing Windows', { skip: process.platform !== 'win32' }, async t => {
  const root = await sandbox(t);
  const fixture = join(root, 'fixture.ps1');
  const core = fileURLToPath(new URL('../powershell/worker-core.ps1', import.meta.url));
  const source = `param([string]$CorePath, [string]$Scenario)
$ErrorActionPreference='Stop'
. $CorePath
$script:Writes=0
$script:Backups=0
$script:Reads=0
function Assert-WinUtilMcpAdministrator {}
function Get-WinUtilMcpRegistry { param($Path,$Name) [pscustomobject]@{kind='registry';path=$Path;name=$Name;existed=$false;keyExisted=$false;type=$null;value=$null} }
function Write-WinUtilMcpBackup { param($Operation,$Entries) $script:Backups++; if($Scenario -eq 'backup-failure'){throw 'fixture backup unavailable'}; '${GUID}' }
function Set-WinUtilMcpRegistry { param($Path,$Name,$Type,$Value) $script:Writes++; if($Scenario -ne 'partial' -or $script:Writes -eq 2){throw 'fixture access denied'} }
function Get-WinUtilMcpAdapters { $script:Reads++; [pscustomobject]@{id='${GUID}';interfaceIndex=$(if($Scenario -eq 'adapter-changed' -and $script:Reads -gt 1){9}else{7});name='fixture';macAddress='00-11';description='fixture';status='completed'} }
function Get-WinUtilMcpDns { param($Adapter) [pscustomobject]@{kind='dns';adapter=$Adapter;families=@()} }
function Set-WinUtilMcpDnsFamily { param($InterfaceIndex,$Family,$Addresses,[switch]$Reset) $script:Writes++; throw 'fixture DNS permission denied' }
$json='{"schemaVersion":1,"backupId":"${GUID}","operation":"apply_tweaks","tweaks":[{"key":"fixture","name":"Fixture","registry":[{"path":"HKCU:\\\\Software\\\\Fixture","name":"A","type":"DWord","value":"1"},{"path":"HKCU:\\\\Software\\\\Fixture","name":"B","type":"DWord","value":"2"}],"services":[]}]}'
if($Scenario -in @('dns-failure','adapter-changed')){$json='{"schemaVersion":1,"backupId":"${GUID}","operation":"set_dns","provider":"fixture","addresses":["1.1.1.1"],"adapters":[{"id":"${GUID}","interfaceIndex":7,"name":"fixture","macAddress":"00-11","description":"fixture"}]}' }
if($Scenario -eq 'unknown-field'){$json=$json.Replace('"name":"Fixture"','"name":"Fixture","InvokeScript":["calc"]')}
try{$result=Invoke-WinUtilMcpRequest ($json|ConvertFrom-Json) -ReportProgress:($Scenario -eq 'partial')}catch{$result=[pscustomobject]@{status='failed';message=$_.Exception.Message;results=@()}}
[pscustomobject]@{result=$result;writes=$script:Writes;backups=$script:Backups}|ConvertTo-Json -Depth 30 -Compress
`;
  await writeFile(fixture, '\ufeff' + source, 'utf8');
  const shell = process.env.WINUTIL_MCP_TEST_POWERSHELL || 'pwsh.exe';
  for (const scenario of ['first-failure', 'partial', 'backup-failure', 'unknown-field', 'dns-failure', 'adapter-changed']) {
    const output = await defaultRunner(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', fixture, '-CorePath', core, '-Scenario', scenario]);
    if (output.code === 'ENOENT' || /running scripts is disabled|cannot be loaded because|UnauthorizedAccess|PSSecurityException|禁止运行脚本/.test(output.stderr)) {
      if (process.env.CI) assert.fail(`${shell} 必须在 Windows CI 中运行失败夹具：${output.stderr || output.error}`);
      t.skip(`${shell} 不可用或执行策略阻止；未绕过策略，CI 需验证此夹具。`); return;
    }
    assert.equal(output.exitCode, 0, output.stderr);
    const rows = output.stdout.trim().split(/\r?\n/).map(line => JSON.parse(line));
    const result = rows.at(-1);
    assert.equal(result.result.status, scenario === 'partial' ? 'partial' : 'failed', `${scenario}: ${output.stdout}`);
    if (scenario === 'unknown-field') { assert.equal(result.backups, 0); assert.equal(result.writes, 0); }
    if (['backup-failure', 'adapter-changed'].includes(scenario)) assert.equal(result.writes, 0, output.stdout);
    if (scenario === 'partial') {
      assert.equal(result.writes, 2); assert.equal(result.result.results[0].status, 'completed'); assert.equal(result.result.results[1].status, 'failed');
      assert.ok(rows.some(row => row.checkpoint && row.results.length === 1 && row.pending?.name === 'B'));
    }
    if (['first-failure', 'dns-failure'].includes(scenario)) { assert.equal(result.writes, 1); assert.equal(result.result.backupId, GUID); }
  }
});

test('PowerShell validates JSON requests and binds exact bytes before any operation', { skip: process.platform !== 'win32' }, async t => {
  const root = await sandbox(t);
  const worker = fileURLToPath(new URL('../powershell/worker.ps1', import.meta.url));
  const path = join(root, 'request.json');
  const body = JSON.stringify({ schemaVersion: 1, operation: 'apply_tweaks', backupId: GUID, tweaks: [{ key: 'plain', name: 'Fixture', registry: [{ path: 'HKCU:\\Software\\Fixture', name: 'A', type: 'DWord', value: '1' }], services: [] }] });
  await writeFile(path, body);
  const hash = createHash('sha256').update(body).digest('hex');
  const shell = process.env.WINUTIL_MCP_TEST_POWERSHELL || 'pwsh.exe';
  for (const [digest, expected] of [[hash, 'completed'], ['0'.repeat(64), 'failed']]) {
    const output = await defaultRunner(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', worker, '-InputPath', path, '-ExpectedSha256', digest, '-ValidateOnly']);
    if (output.code === 'ENOENT' || /PSSecurityException|running scripts is disabled|cannot be loaded because|禁止运行脚本/.test(output.stderr)) {
      if (process.env.CI) assert.fail(output.stderr || output.error);
      t.skip('PowerShell 不可用或执行策略阻止；未绕过策略。'); return;
    }
    const result = JSON.parse(output.stdout.trim());
    assert.equal(result.status, expected, output.stderr); assert.equal(output.exitCode, expected === 'completed' ? 0 : 1);
    if (expected === 'completed') assert.equal(result.validationOnly, true);
    else assert.match(result.message, /REQUEST_CHANGED/);
  }
});

test('PowerShell backup restoration validates every record before any write and reports partial failures', { skip: process.platform !== 'win32' }, async t => {
  const root = await sandbox(t);
  const fixture = join(root, 'restore-fixture.ps1');
  const core = fileURLToPath(new URL('../powershell/worker-core.ps1', import.meta.url));
  await writeFile(fixture, '\ufeff' + `param([string]$CorePath,[string]$Scenario,[string]$FixtureDirectory)
$ErrorActionPreference='Stop'
. $CorePath
$script:Writes=0
$script:Removed=0
function Assert-WinUtilMcpAdministrator {}
function Get-WinUtilMcpBackupRoot {$FixtureDirectory}
function Assert-WinUtilMcpBackupAcl {param($Path)}
function Set-WinUtilMcpRegistry {param($Path,$Name,$Type,$Value,[switch]$Remove) $script:Writes++; if($Remove){$script:Removed++}; if($Scenario -eq 'partial' -and $script:Writes -eq 2){throw 'fixture restore denied'} }
$entries=@([pscustomobject]@{kind='registry';path='HKCU:\\Software\\Fixture';name='A';existed=$false;keyExisted=$false;type=$null;value=$null},[pscustomobject]@{kind='registry';path='HKCU:\\Software\\Fixture';name='B';existed=$true;keyExisted=$true;type='DWord';value='0'})
if($Scenario -eq 'invalid-last'){$entries[1].type='ScriptBlock'}
$backup=@{schemaVersion=1;id='${GUID}';operation='apply_tweaks';createdUtc=[DateTime]::UtcNow.ToString('o');machine=[Environment]::MachineName;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;entries=$entries}
$backup|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $FixtureDirectory '${GUID}.json') -Encoding UTF8
try{$result=Restore-WinUtilMcpBackup $(if($Scenario -eq 'path'){ '../bad' }else{'${GUID}'})}catch{$result=[pscustomobject]@{status='failed';message=$_.Exception.Message;results=@()}}
[pscustomobject]@{result=$result;writes=$script:Writes;removed=$script:Removed}|ConvertTo-Json -Depth 30 -Compress
`, 'utf8');
  const shell = process.env.WINUTIL_MCP_TEST_POWERSHELL || 'pwsh.exe';
  for (const scenario of ['success', 'partial', 'invalid-last', 'path']) {
    const output = await defaultRunner(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', fixture, '-CorePath', core, '-Scenario', scenario, '-FixtureDirectory', root]);
    if (output.code === 'ENOENT' || /PSSecurityException|running scripts is disabled|cannot be loaded because|禁止运行脚本/.test(output.stderr)) {
      if (process.env.CI) assert.fail(output.stderr || output.error);
      t.skip('PowerShell 不可用或执行策略阻止；未绕过策略。'); return;
    }
    assert.equal(output.exitCode, 0, output.stderr);
    const result = JSON.parse(output.stdout.trim());
    assert.equal(result.result.status, scenario === 'success' ? 'completed' : scenario === 'partial' ? 'partial' : 'failed', output.stdout);
    if (scenario === 'success') { assert.equal(result.writes, 2); assert.equal(result.removed, 1); }
    if (['invalid-last', 'path'].includes(scenario)) assert.equal(result.writes, 0);
  }
});

test('registry snapshots preserve empty, single, and multiple Binary/MultiString elements through backup JSON', { skip: process.platform !== 'win32' }, async t => {
  const root = await sandbox(t);
  const fixture = join(root, 'snapshot-fixture.ps1');
  const core = fileURLToPath(new URL('../powershell/worker-core.ps1', import.meta.url));
  await writeFile(fixture, '\ufeff' + `param([string]$CorePath)
$ErrorActionPreference='Stop'
. $CorePath
$results=New-Object 'System.Collections.Generic.List[object]'
foreach($type in @('MultiString','Binary')){
    foreach($length in @(0,1,3)){
        if($type -eq 'MultiString'){$value=[string[]]@('one','two','three')|Select-Object -First $length; $value=[string[]]@($value)}
        else{$value=[byte[]]@(1,2,3)|Select-Object -First $length; $value=[byte[]]@($value)}
        $snapshot=New-WinUtilMcpRegistrySnapshot -Path 'HKCU:\\Software\\Fixture' -Name 'Test' -KeyExisted $true -Existed $true -Type $type -Value $value
        if($snapshot.value -isnot [array] -or $snapshot.value.Count -ne $length){throw 'Snapshot changed array cardinality'}
        $json=$snapshot|ConvertTo-Json -Depth 20 -Compress
        $restored=$json|ConvertFrom-Json
        Assert-WinUtilMcpBackupEntry $restored
        if($restored.value -isnot [array] -or $restored.value.Count -ne $length){throw 'Backup JSON changed array cardinality'}
        $results.Add([pscustomobject]@{type=$type;length=$length;value=$restored.value})
    }
}
ConvertTo-Json -InputObject @($results.ToArray()) -Depth 20 -Compress
`, 'utf8');
  const shell = process.env.WINUTIL_MCP_TEST_POWERSHELL || 'pwsh.exe';
  const output = await defaultRunner(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', fixture, '-CorePath', core]);
  if (output.code === 'ENOENT' || /PSSecurityException|running scripts is disabled|cannot be loaded because|禁止运行脚本/.test(output.stderr)) {
    if (process.env.CI) assert.fail(output.stderr || output.error);
    t.skip('PowerShell 不可用或执行策略阻止；未绕过策略。'); return;
  }
  assert.equal(output.exitCode, 0, output.stderr);
  const results = JSON.parse(output.stdout.trim());
  assert.equal(results.length, 6);
  for (const row of results) assert.deepEqual(row.value, row.type === 'MultiString' ? ['one', 'two', 'three'].slice(0, row.length) : [1, 2, 3].slice(0, row.length));
});
