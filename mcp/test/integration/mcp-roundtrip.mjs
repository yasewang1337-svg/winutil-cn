import assert from 'node:assert/strict';
import { execFile, spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createWinutilServer } from '../../lib/server.mjs';
import { createExecutor } from '../../lib/executor.mjs';
import { requireDisposableWindows, requireEvidencePath } from './guard.mjs';

requireDisposableWindows(); // Must precede every filesystem/registry/process mutation.
const shell = join(process.env.SystemRoot, 'System32/WindowsPowerShell/v1.0/powershell.exe');
const worker = fileURLToPath(new URL('../../powershell/worker.ps1', import.meta.url));
const prefix = 'Software\\WinUtilCNMcpIntegration\\';
const subkey = process.argv.includes('--serve-fixture') ? process.env.WINUTIL_MCP_TEST_REG_SUBKEY : prefix + randomUUID();
assert.ok(subkey?.startsWith(prefix) && /^[0-9a-f-]{36}$/.test(subkey.slice(prefix.length)), 'Fixture registry scope is invalid');
const registryPath = 'HKCU:\\' + subkey;
const actionValues = [{ Path: registryPath, Name: 'Original', Type: 'DWord', Value: '17' },
  { Path: registryPath, Name: 'Created', Type: 'String', Value: 'real MCP write' }];
const cancellationValues = Array.from({ length: 80 }, (_, i) => ({ Path: registryPath, Name: 'Cancel' + i, Type: 'DWord', Value: '99' }));
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

if (process.argv.includes('--serve-fixture')) {
  // Real production protocol, plans, executor and PowerShell worker. Only the
  // catalog targets are test-owned registry values instead of Windows settings.
  const data = { source: 'integration-fixture', metadata: {}, apps: {}, bundles: {}, dns: {}, tweaks: {
    roundtrip: { Content: 'Disposable registry roundtrip', registry: actionValues },
    cancel: { Content: 'Disposable cancellation roundtrip', registry: cancellationValues },
  } };
  await createWinutilServer({ data, allowWrite: true, executor: createExecutor() }).connect(new StdioServerTransport());
} else {
  const evidenceDir = requireEvidencePath(process.env.WINUTIL_MCP_EVIDENCE_DIR);
  await mkdir(evidenceDir, { recursive: true });
  const evidence = { schemaVersion: 1, status: 'running', environment: 'github-hosted-windows',
    commit: process.env.GITHUB_SHA, runId: process.env.GITHUB_RUN_ID, runAttempt: process.env.GITHUB_RUN_ATTEMPT,
    subkey, scenarios: [], cleanup: {} };
  const run = promisify(execFile);
  const ps = script => run(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
    "$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); " + script],
  { windowsHide: true, encoding: 'utf8', timeout: 30000, maxBuffer: 4 * 1024 * 1024 });
  const snapshot = async () => {
    const { stdout } = await ps(`$key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('${subkey}'); try { $rows=@(); foreach($name in @($key.GetValueNames()|Sort-Object)) { $rows+= [pscustomobject]@{name=$name;type=$key.GetValueKind($name).ToString();value=$key.GetValue($name)} }; ConvertTo-Json -InputObject @($rows) -Compress -Depth 6 } finally {$key.Dispose()}`);
    return JSON.parse(stdout.trim());
  };
  const restore = async (id, name) => {
    assert.match(id, /^[0-9a-f-]{36}$/);
    let result;
    try {
      result = await run(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', worker, '-RestoreBackupId', id], { windowsHide: true, encoding: 'utf8', timeout: 30000 });
    } catch (error) {
      await writeFile(join(evidenceDir, `${name}-restore.log`), String(error.stdout || '') + '\n' + String(error.stderr || ''));
      await writeFile(join(evidenceDir, `${name}-restore-error.json`), JSON.stringify({ code: error.code, signal: error.signal, killed: error.killed, message: error.message }, null, 2) + '\n');
      throw error;
    }
    await writeFile(join(evidenceDir, `${name}-restore.log`), result.stdout + '\n' + result.stderr);
    const payload = JSON.parse(result.stdout.trim());
    assert.equal(payload.status, 'completed', result.stdout);
    return payload;
  };
  const client = new Client({ name: 'real-mutation-roundtrip', version: '1.0.0' });
  const envKeys = ['GITHUB_ACTIONS', 'RUNNER_ENVIRONMENT', 'RUNNER_OS', 'RUNNER_TEMP', 'GITHUB_RUN_ID', 'WINUTIL_MCP_DISPOSABLE_TEST', 'SystemRoot', 'ProgramData', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE', 'TEMP', 'TMP', 'PATH'];
  const env = Object.fromEntries(envKeys.filter(key => process.env[key] !== undefined).map(key => [key, process.env[key]]));
  const transport = new StdioClientTransport({ command: process.execPath, args: [fileURLToPath(import.meta.url), '--serve-fixture'],
    env: { ...env, WINUTIL_MCP_TEST_REG_SUBKEY: subkey }, stderr: 'pipe' });
  let stderr = '', initialized = false, connected = false, mutationDispatched = false, observer, cancellationController, cancellationPending;
  transport.stderr.on('data', chunk => { stderr += chunk; });
  const decode = response => JSON.parse(response.content[0].text);
  const call = (name, args = {}, options) => client.callTool({ name, arguments: args }, undefined, { timeout: 60000, ...options });
  const waitUntilIdle = async () => {
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const execution = decode(await call('get_status', {}, { timeout: Math.min(5000, Math.max(1, deadline - Date.now())) })).execution;
      if (execution.busy === false) return execution;
      await delay(100);
    }
    throw new Error('Worker did not confirm idle before cleanup; the fixture key must remain untouched.');
  };
  try {
    await ps(`if([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('${subkey}')){throw 'Fixture already exists'}; $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('${subkey}'); try {$key.SetValue('Original',5,[Microsoft.Win32.RegistryValueKind]::DWord); 0..79|ForEach-Object{$key.SetValue(('Cancel'+$_),0,[Microsoft.Win32.RegistryValueKind]::DWord)}} finally {$key.Dispose()}`);
    initialized = true;
    const before = await snapshot();
    await client.connect(transport);
    connected = true;
    const preview = decode(await call('apply_tweaks', { keys: ['roundtrip'] }));
    assert.ok(preview.planId && preview.preview);
    assert.deepEqual(await snapshot(), before, 'Preview must leave the real registry unchanged');
    const mismatch = await call('apply_tweaks', { keys: ['cancel'], confirm: true, planId: preview.planId });
    assert.equal(mismatch.isError, true);
    assert.deepEqual(await snapshot(), before, 'Mismatched confirmation must not write');
    mutationDispatched = true;
    const response = await call('apply_tweaks', { keys: ['roundtrip'], confirm: true, planId: preview.planId });
    const result = decode(response);
    assert.ok(!response.isError, JSON.stringify(result));
    assert.equal(result.status, 'completed');
    assert.equal(result.backupStatus, 'confirmed');
    const changed = await snapshot();
    assert.equal(changed.find(r => r.name === 'Original').value, 17);
    assert.equal(changed.find(r => r.name === 'Created').value, 'real MCP write');
    await restore(result.backupId, 'mcp-roundtrip');
    assert.deepEqual(await snapshot(), before, 'Restore must remove newly created values and restore exact old values/types');
    evidence.scenarios.push({ name: 'real-stdio-preview-confirm-restore', status: 'passed', before, changed, restored: before, backupId: result.backupId });

    // A separate read-only native observer signals the first actual registry
    // write. Cancellation is therefore tested after mutation, not just startup.
    let observerOutput = '', observerError = '';
    observer = spawn(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
      `$ErrorActionPreference='Stop';[Console]::Out.WriteLine('READY');[Console]::Out.Flush();$watch=[Diagnostics.Stopwatch]::StartNew();while($watch.Elapsed.TotalSeconds -lt 25){$key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('${subkey}');try{$value=$key.GetValue('Cancel0')}finally{$key.Dispose()};if($value -eq 99){[Console]::Out.WriteLine('CHANGED');[Console]::Out.Flush();exit 0};Start-Sleep -Milliseconds 1};exit 2`], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    observer.stdout.on('data', chunk => { observerOutput += chunk; });
    observer.stderr.on('data', chunk => { observerError += chunk; });
    const waitObserver = async marker => {
      const until = Date.now() + 30000;
      while (!observerOutput.includes(marker) && Date.now() < until && observer.exitCode === null) await delay(5);
      assert.ok(observerOutput.includes(marker), `${marker}: ${observerOutput}; ${observerError}`);
    };
    await waitObserver('READY');
    const cancelPreview = decode(await call('apply_tweaks', { keys: ['cancel'] }));
    cancellationController = new AbortController();
    cancellationPending = call('apply_tweaks', { keys: ['cancel'], confirm: true, planId: cancelPreview.planId }, { signal: cancellationController.signal }).catch(error => ({ cancelled: true, message: error.message }));
    await waitObserver('CHANGED');
    cancellationController.abort();
    const clientResult = await cancellationPending;
    const execution = await waitUntilIdle();
    assert.equal(execution.busy, false, 'Cancelled worker must settle');
    const cancelled = execution.lastResult;
    assert.equal(cancelled.code, 'CANCELLED', JSON.stringify({ clientResult, cancelled }));
    assert.ok(['partial', 'cancelled'].includes(cancelled.status));
    assert.equal(cancelled.backupStatus, 'confirmed');
    const afterCancel = await snapshot();
    assert.ok(afterCancel.some(r => r.name.startsWith('Cancel') && r.value === 99), 'Cancellation must happen after a real write');
    await restore(cancelled.backupId, 'mcp-cancel');
    assert.deepEqual(await snapshot(), before, 'Interrupted operation must restore original registry state');
    evidence.scenarios.push({ name: 'real-stdio-cancel-after-write-and-restore', status: 'passed', backupId: cancelled.backupId,
      changedValues: afterCancel.filter(r => r.value === 99).length, confirmedValues: cancelled.results.length, outcomeKnown: cancelled.outcomeKnown, restored: true });
    evidence.status = 'passed';
  } catch (error) {
    evidence.status = 'failed'; evidence.error = error.stack || String(error); process.exitCode = 1;
  } finally {
    observer?.kill();
    cancellationController?.abort();
    // A closed stdio server does not prove its PowerShell child has exited. First
    // let the production executor settle; never race registry cleanup against it.
    let safeToCleanRegistry = !mutationDispatched;
    if (connected && mutationDispatched) {
      try {
        const execution = await waitUntilIdle();
        evidence.cleanup.workerSettled = execution.busy === false;
        safeToCleanRegistry = execution.busy === false;
      } catch (error) {
        evidence.cleanup.workerSettled = false;
        evidence.cleanup.workerError = error.message;
        evidence.status = 'failed'; process.exitCode = 1;
      }
    }
    await client.close().catch(() => {});
    if (initialized && safeToCleanRegistry) {
      try {
        await ps(`[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('${subkey}',$false); if([Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('${subkey}')){throw 'Fixture cleanup failed'}`);
        evidence.cleanup.registryRemoved = true;
      } catch (error) { evidence.cleanup.error = error.message; evidence.status = 'failed'; process.exitCode = 1; }
    } else if (initialized) {
      evidence.cleanup.registryRemoved = false;
      evidence.cleanup.registryPreservedReason = 'Worker completion is unconfirmed; only the disposable VM teardown may remove this fixture.';
      evidence.status = 'failed'; process.exitCode = 1;
    }
    await writeFile(join(evidenceDir, 'mcp-roundtrip.json'), JSON.stringify(evidence, null, 2) + '\n');
    await writeFile(join(evidenceDir, 'mcp-roundtrip-stderr.log'), stderr);
    console.log(JSON.stringify({ status: evidence.status, scenarios: evidence.scenarios.map(s => s.name), error: evidence.error, cleanup: evidence.cleanup }));
  }
}
