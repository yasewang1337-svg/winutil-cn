import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { promisify } from 'node:util';
import { loadData, parseConfig, SOURCE_FILES, validateData } from '../lib/data.mjs';

const execFileAsync = promisify(execFile);
const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const version = JSON.parse(await readFile(join(packageDir, 'package.json'), 'utf8')).version;
function catalog() {
  return {
    apps: { alpha: { content: '示例软件', winget: 'Example.Alpha', choco: 'alpha;alpha-helper', description: '说明' } },
    bundles: { office: { name: '办公', region: '国内', desc: '说明', apps: ['WPFInstallalpha'], defaultApps: ['WPFInstallalpha'], purposes: { WPFInstallalpha: '用途' } } },
    tweaks: { WPFTweaksExample: { Content: '示例设置', registry: [{ Path: 'HKCU:\\Software\\Example', Name: 'Enabled', Type: 'DWord', Value: '0' }], service: [{ Name: 'ExampleService', StartupType: 'Disable' }], InvokeScript: ['Write-Output "example"'] } },
    dns: { Example: { Primary: '1.1.1.1', Secondary: '1.0.0.1', Primary6: '2606:4700:4700::1111', Secondary6: '' } },
  };
}
function snapshot() {
  return { ...catalog(), metadata: { schemaVersion: 1, packageVersion: version, sourceCommit: 'a'.repeat(40), sourceDirty: false, generatedAt: '2026-10-11T00:00:00.000Z', sourceFiles: Object.fromEntries(SOURCE_FILES.map(f => [f, 'b'.repeat(64)])) } };
}
async function fixture(t, { source = true } = {}) {
  const repoRoot = await mkdtemp(join(tmpdir(), 'winutil-mcp-data-'));
  t.after(() => rm(repoRoot, { recursive: true, force: true }));
  const packageDir = join(repoRoot, 'mcp');
  await mkdir(packageDir);
  await writeFile(join(packageDir, 'package.json'), JSON.stringify({ name: 'winutil-cn-mcp', version }));
  await writeFile(join(packageDir, 'data.json'), JSON.stringify(snapshot()));
  if (source) {
    await mkdir(join(repoRoot, '.git'));
    await mkdir(join(repoRoot, 'scripts'));
    await writeFile(join(repoRoot, 'Compile.ps1'), '# source fixture');
    await writeFile(join(repoRoot, 'scripts/main.ps1'), '# source fixture');
    const data = catalog();
    const documents = [data.apps, {}, data.bundles, data.tweaks, data.dns];
    await Promise.all(SOURCE_FILES.map(async (file, i) => {
      await mkdir(dirname(join(repoRoot, file)), { recursive: true });
      await writeFile(join(repoRoot, file), JSON.stringify(documents[i]));
    }));
  }
  return { packageDir, repoRoot };
}

test('real source catalog validates and records file hashes and package version', async () => {
  const data = await loadData({ mode: 'source' });
  assert.equal(data.source, 'source');
  assert.equal(data.metadata.packageVersion, version);
  assert.equal(data.metadata.schemaVersion, 1);
  assert.ok(Object.keys(data.apps).length > 200);
  assert.deepEqual(Object.keys(data.metadata.sourceFiles).sort(), [...SOURCE_FILES].sort());
  for (const hash of Object.values(data.metadata.sourceFiles)) assert.match(hash, /^[a-f0-9]{64}$/);
  assert.ok(data.bundles.cn_office.defaultApps.length > 0);
  assert.ok(data.bundles.cn_office.purposes.WPFInstallwechat);
});

test('auto prefers live source despite a stale bundled snapshot', async t => {
  const paths = await fixture(t);
  const app = { alpha: { content: '当前源码', winget: 'Example.Current' } };
  await writeFile(join(paths.repoRoot, 'config/applications.json'), JSON.stringify(app));
  const data = await loadData(paths);
  assert.equal(data.source, 'source');
  assert.equal(data.apps.alpha.winget, 'Example.Current');
  assert.equal(data.tweaks.WPFTweaksExample.service[0].StartupType, 'Disabled');
});

test('explicit bundled mode ignores even a valid source checkout', async t => {
  const paths = await fixture(t);
  const result = await loadData({ ...paths, mode: 'bundled' });
  assert.equal(result.source, 'bundled');
  assert.equal(result.apps.alpha.winget, 'Example.Alpha');
});

test('a neighboring config directory does not impersonate a repository', async t => {
  const paths = await fixture(t);
  await rm(join(paths.repoRoot, '.git'), { recursive: true });
  await writeFile(join(paths.repoRoot, 'config/applications.json'), 'BROKEN');
  assert.equal((await loadData(paths)).source, 'bundled');
});

for (const [name, value] of [['missing', null], ['malformed', '{ broken'], ['invalid type', '{"alpha":42}']]) {
  test(`source ${name} fails instead of serving a stale bundle`, async t => {
    const paths = await fixture(t);
    const file = join(paths.repoRoot, 'config/applications.json');
    if (value === null) await rm(file); else await writeFile(file, value);
    await assert.rejects(loadData(paths), /源配置|数据无效/);
  });
}

test('explicit source mode supports source archives without Git metadata', async t => {
  const paths = await fixture(t);
  await rm(join(paths.repoRoot, '.git'), { recursive: true });
  const data = await loadData({ ...paths, mode: 'source' });
  assert.equal(data.source, 'source');
  assert.equal(data.metadata.sourceCommit, null);
});

for (const [name, transform, expected] of [
  ['missing snapshot', null, /无法加载 MCP 打包数据/],
  ['malformed JSON', () => '{bad', /无法加载 MCP 打包数据/],
  ['old metadata-free snapshot', () => JSON.stringify(catalog()), /metadata/],
  ['wrong version', d => { d.metadata.packageVersion = '0.0.1'; return JSON.stringify(d); }, /packageVersion/],
  ['wrong schema', d => { d.metadata.schemaVersion = 999; return JSON.stringify(d); }, /schemaVersion/],
  ['missing provenance hashes', d => { delete d.metadata.sourceFiles; return JSON.stringify(d); }, /sourceFiles/],
]) {
  test(`packaged ${name} fails locally without network fallback`, async t => {
    const paths = await fixture(t, { source: false });
    const originalFetch = globalThis.fetch;
    let fetches = 0;
    globalThis.fetch = () => { fetches++; throw new Error('network forbidden'); };
    t.after(() => { globalThis.fetch = originalFetch; });
    const path = join(paths.packageDir, 'data.json');
    if (!transform) await rm(path); else await writeFile(path, transform(snapshot()));
    await assert.rejects(loadData(paths), expected);
    assert.equal(fetches, 0);
  });
}

test('literal controls, BOM and escaped quotes parse without corrupting valid escapes', () => {
  assert.deepEqual(parseConfig('\uFEFF{"line":"a\nb\r\tc", "quote":"say \\"hi\\"", "path":"C:\\\\temp"}'), { line: 'a\nb\r\tc', quote: 'say "hi"', path: 'C:\\temp' });
  assert.throws(() => parseConfig('{"name":}'), SyntaxError);
});

for (const [name, mutate, expected] of [
  ['winget argument injection', d => { d.apps.alpha.winget = 'Example.App; calc.exe'; }, /winget/],
  ['option-like package ID', d => { d.apps.alpha.winget = '--override'; }, /winget/],
  ['non-string app description', d => { d.apps.alpha.description = {}; }, /description/],
  ['unknown bundle app', d => { d.bundles.office.apps = ['WPFInstallmissing']; }, /未知软件引用/],
  ['invalid recommended subset', d => { d.bundles.office.defaultApps = ['WPFInstallmissing']; }, /defaultApps/],
  ['unrelated purpose', d => { d.bundles.office.purposes.missing = 'purpose'; }, /purposes/],
  ['case-insensitive duplicate app keys', d => { d.apps.ALPHA = d.apps.alpha; }, /重复的软件键/],
  ['registry type injection', d => { d.tweaks.WPFTweaksExample.registry[0].Type = 'DWord; calc'; }, /Type/],
  ['file path as registry key', d => { d.tweaks.WPFTweaksExample.registry[0].Path = 'C:\\file'; }, /Path/],
  ['service startup injection', d => { d.tweaks.WPFTweaksExample.service[0].StartupType = 'Automatic; calc'; }, /StartupType/],
  ['script scalar', d => { d.tweaks.WPFTweaksExample.InvokeScript = 'bad shape'; }, /InvokeScript/],
  ['DNS argument injection', d => { d.dns.Example.Primary = "1.1.1.1'; calc"; }, /Primary/],
  ['invalid IPv6', d => { d.dns.Example.Primary6 = 'not-ipv6'; }, /Primary6/],
]) {
  test(`rejects ${name}`, () => {
    const data = catalog(); mutate(data);
    assert.throws(() => validateData(data), expected);
  });
}

test('rejects prototype-related keys even inside arbitrary catalog fields', () => {
  const data = catalog();
  data.apps.alpha.extra = JSON.parse('{"__proto__":{"polluted":true}}');
  assert.throws(() => validateData(data), /不允许的对象键/);
});

test('invalid data mode never silently chooses another source', async () => {
  await assert.rejects(loadData({ mode: 'raw' }), /未知 MCP 数据模式/);
});

test('clean-build flag rejects dirty source without overwriting the previous snapshot', async t => {
  const paths = await fixture(t);
  const { cp } = await import('node:fs/promises');
  await cp(join(packageDir, 'build-data.js'), join(paths.packageDir, 'build-data.js'));
  await cp(join(packageDir, 'lib'), join(paths.packageDir, 'lib'), { recursive: true });
  const before = await readFile(join(paths.packageDir, 'data.json'), 'utf8');
  await assert.rejects(execFileAsync(process.execPath, [join(paths.packageDir, 'build-data.js')], {
    env: { ...process.env, WINUTIL_MCP_REQUIRE_CLEAN: '1' }, windowsHide: true,
  }), error => /干净的 Git/.test(error.stderr));
  assert.equal(await readFile(join(paths.packageDir, 'data.json'), 'utf8'), before);
});
