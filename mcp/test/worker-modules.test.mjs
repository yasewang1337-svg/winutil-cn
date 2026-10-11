import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, relative, resolve, isAbsolute, delimiter } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { defaultRunner } from '../lib/executor.mjs';

test('real worker isolates inherited modules before the first read-only ACL call', { skip: process.platform !== 'win32' }, async t => {
  const root = await mkdtemp(join(tmpdir(), 'winutil-mcp-module-test-'));
  t.after(async () => {
    const scoped = relative(resolve(tmpdir()), resolve(root));
    assert.ok(scoped && !scoped.startsWith('..') && !isAbsolute(scoped));
    await rm(root, { recursive: true, force: true });
  });
  const fakeModule = join(root, 'Microsoft.PowerShell.Security');
  await mkdir(fakeModule);
  await writeFile(join(fakeModule, 'Microsoft.PowerShell.Security.psd1'), "@{ RootModule = 'shadow.psm1'; ModuleVersion = '999.0.0'; GUID = '55555555-4444-3333-2222-111111111111'; FunctionsToExport = @('Get-Acl'); CmdletsToExport = @() }\n");
  await writeFile(join(fakeModule, 'shadow.psm1'), "function Get-Acl { param($LiteralPath) throw 'WINUTIL_MCP_INHERITED_MODULE_SENTINEL' }\nExport-ModuleMember -Function Get-Acl\n");

  // This request is read-only even if ValidateOnly ever regresses. No registry,
  // service, DNS, package installation or backup restoration is requested.
  const body = JSON.stringify({ schemaVersion: 1, operation: 'list_adapters' });
  const inputPath = join(root, 'request.json');
  await writeFile(inputPath, body);
  const hash = createHash('sha256').update(body).digest('hex');
  const sourceWorker = fileURLToPath(new URL('../powershell/worker.ps1', import.meta.url));
  const sourceCore = fileURLToPath(new URL('../powershell/worker-core.ps1', import.meta.url));
  const fixtureDirectory = join(root, 'entry-point');
  await mkdir(fixtureDirectory);
  const worker = join(fixtureDirectory, 'worker.ps1');
  await writeFile(worker, await readFile(sourceWorker));
  // Keep the production entry point byte-for-byte. The copied core adds only a
  // read of this temporary fixture file's ACL, reproducing the first Security
  // autoload used by backup handling without requesting any privileged changes.
  const aclProbe = "\n$null = Get-Acl -LiteralPath ([IO.Path]::Combine($PSScriptRoot, 'worker-core.ps1')) -ErrorAction Stop\n";
  await writeFile(join(fixtureDirectory, 'worker-core.ps1'), (await readFile(sourceCore, 'utf8')) + aclProbe);
  const shell = process.env.WINUTIL_MCP_TEST_POWERSHELL || 'pwsh.exe';
  const inheritedKey = Object.keys(process.env).find(key => key.toLowerCase() === 'psmodulepath');
  const parentModulePath = inheritedKey ? process.env[inheritedKey] : undefined;
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => key.toLowerCase() !== 'psmodulepath'));
  env.PSModulePath = root + delimiter + (parentModulePath || '');

  const output = await defaultRunner(shell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', worker,
    '-InputPath', inputPath, '-ExpectedSha256', hash, '-ValidateOnly'], { env });
  if (output.code === 'ENOENT' || /PSSecurityException|running scripts is disabled|cannot be loaded because|禁止运行脚本/.test(output.stderr)) {
    if (process.env.CI) assert.fail(output.stderr || output.error);
    t.skip('PowerShell 不可用或执行策略阻止；未绕过策略。');
    return;
  }
  assert.equal(output.exitCode, 0, `${output.stdout}\n${output.stderr}`);
  assert.equal(output.stderr.trim(), '');
  const result = JSON.parse(output.stdout.trim());
  assert.equal(result.status, 'completed');
  assert.equal(result.validationOnly, true);
  assert.deepEqual(result.results, []);

  assert.equal(inheritedKey ? process.env[inheritedKey] : undefined, parentModulePath);
});
