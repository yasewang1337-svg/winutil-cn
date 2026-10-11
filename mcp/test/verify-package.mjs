#!/usr/bin/env node
// Verify a real tarball with no repository configuration or runtime network.
// With --tarball, the supplied artifact is never repacked or modified.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFile } from 'node:child_process';
import { cp, lstat, mkdir, mkdtemp, readFile, readdir, realpath, rename, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { delimiter, dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { SOURCE_FILES } from '../lib/data.mjs';

const execFileAsync = promisify(execFile);
const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = resolve(packageDir, '..');
const packageInfo = JSON.parse(await readFile(join(packageDir, 'package.json'), 'utf8'));
const options = process.argv.slice(2);
assert.ok(options.length === 0 || (options.length === 2 && options[0] === '--tarball'), '用法: node test/verify-package.mjs [--tarball file.tgz]');
const temporary = await mkdtemp(join(tmpdir(), 'winutil-mcp-pack-'));
const run = (file, args, extra = {}) => execFileAsync(file, args, { windowsHide: true, timeout: 120000, maxBuffer: 8 * 1024 * 1024, ...extra });
async function exists(path) { try { await lstat(path); return true; } catch (error) { if (error.code === 'ENOENT') return false; throw error; } }
async function npmCli() {
  const candidates = [process.env.npm_execpath, join(dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js')].filter(Boolean);
  for (const path of (process.env.PATH || '').split(delimiter)) {
    const candidate = join(path, process.platform === 'win32' ? 'npm.cmd' : 'npm');
    if (process.platform !== 'win32' && await exists(candidate)) candidates.push(await realpath(candidate));
    if (process.platform === 'win32') candidates.push(join(path, 'node_modules/npm/bin/npm-cli.js'));
  }
  for (const path of candidates) if (await exists(path)) return path;
  throw new Error('无法定位 npm CLI；请通过 npm run test:pack 执行。');
}
async function filesUnder(directory, prefix = '') {
  const output = [];
  if (!await exists(directory)) return output;
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    assert.ok(!entry.isSymbolicLink(), `运行时源码不应包含符号链接: ${relative}`);
    if (entry.isDirectory()) output.push(...await filesUnder(join(directory, entry.name), relative));
    else output.push(relative);
  }
  return output;
}

try {
  let tarball;
  if (options.length) tarball = resolve(options[1]);
  else {
    // Reproduce a fresh checkout: deliberately do not copy data.json or dependencies.
    const stage = join(temporary, 'source');
    await mkdir(stage);
    await cp(packageDir, join(stage, 'mcp'), {
      recursive: true,
      filter: source => {
        const relative = source.slice(packageDir.length).replaceAll('\\', '/');
        return relative !== '/data.json' && !relative.startsWith('/node_modules') && !relative.endsWith('.tgz');
      },
    });
    for (const file of [...SOURCE_FILES, 'Compile.ps1', 'scripts/main.ps1']) {
      await mkdir(dirname(join(stage, file)), { recursive: true });
      await cp(join(repoRoot, file), join(stage, file));
    }
    await writeFile(join(stage, '.gitignore'), 'mcp/data.json\n');
    await run('git', ['init', '--quiet', stage]);
    await run('git', ['-C', stage, 'add', '--all']);
    await run('git', ['-C', stage, '-c', 'user.name=Package Fixture', '-c', 'user.email=fixture@invalid.example', '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'Clean package verification fixture']);
    assert.equal(await exists(join(stage, 'mcp/data.json')), false);
    const destination = join(temporary, 'tarballs');
    await mkdir(destination);
    await run(process.execPath, [await npmCli(), 'pack', '--json', '--offline', '--pack-destination', destination], {
      cwd: join(stage, 'mcp'), env: { ...process.env, WINUTIL_MCP_REQUIRE_CLEAN: '1' },
    });
    const archives = (await readdir(destination)).filter(x => x.endsWith('.tgz'));
    assert.equal(archives.length, 1, '一次构建应产生一份发布包');
    tarball = join(destination, archives[0]);
  }
  const archiveBytes = await readFile(tarball);
  const { stdout: listing } = await run('tar', ['-tzf', tarball]);
  const entries = listing.trim().split(/\r?\n/);
  for (const entry of entries) {
    const parts = entry.split('/');
    assert.ok(parts[0] === 'package' && parts.length > 1 && !parts.includes('..') && !parts.includes('.')
      && !/[\\\0:]/.test(entry), `tar 路径必须在 package/ 下: ${entry}`);
  }
  const { stdout: verbose } = await run('tar', ['-tvzf', tarball]);
  for (const line of verbose.trim().split(/\r?\n/)) assert.ok(line.startsWith('-') || line.startsWith('d'), '发布包不能包含符号链接或设备文件');
  const requiredFiles = ['index.js', 'build-data.js', 'data.json', 'package.json', 'README.md',
    ...await filesUnder(join(packageDir, 'lib'), 'lib'), ...await filesUnder(join(packageDir, 'powershell'), 'powershell')];
  for (const file of requiredFiles) assert.ok(entries.includes(`package/${file}`), `发布包缺少 ${file}`);
  assert.ok(!entries.some(x => x.startsWith('package/node_modules/') || x.startsWith('package/test/')), '包不应包含开发依赖目录或测试夹具');
  const isolated = join(temporary, 'isolated');
  await mkdir(isolated);
  await run('tar', ['-xzf', tarball, '-C', isolated]);
  const installedDir = join(isolated, 'package');
  const installedInfo = JSON.parse(await readFile(join(installedDir, 'package.json'), 'utf8'));
  assert.equal(installedInfo.name, packageInfo.name);
  assert.equal(installedInfo.version, packageInfo.version);
  const snapshot = JSON.parse(await readFile(join(installedDir, 'data.json'), 'utf8'));
  assert.equal(snapshot.metadata.packageVersion, installedInfo.version);
  for (const file of SOURCE_FILES) {
    const expected = createHash('sha256').update(await readFile(join(repoRoot, file))).digest('hex');
    assert.equal(snapshot.metadata.sourceFiles[file], expected, `发布包数据必须对应待验收的源文件: ${file}`);
  }
  assert.equal(await exists(join(isolated, 'config')), false);
  assert.equal(await exists(join(isolated, '.git')), false);
  // These are installed npm dependencies, not a link back into the source checkout.
  await cp(join(packageDir, 'node_modules'), join(installedDir, 'node_modules'), { recursive: true });
  const guardPath = join(isolated, 'offline-guard.cjs');
  const guardLog = join(isolated, 'forbidden-operations.log');
  await writeFile(guardPath, `
const { appendFileSync } = require('node:fs');
const { syncBuiltinESMExports } = require('node:module');
function deny(kind) { return function () { appendFileSync(${JSON.stringify(guardLog)}, kind + '\\n'); throw new Error('Package verification forbids ' + kind); }; }
globalThis.fetch = deny('fetch');
for (const [module, methods] of [
  ['node:net', ['connect', 'createConnection']], ['node:tls', ['connect']],
  ['node:http', ['get', 'request']], ['node:https', ['get', 'request']],
  ['node:dgram', ['createSocket']], ['node:dns', ['lookup', 'resolve', 'resolve4', 'resolve6']],
  ['node:child_process', ['spawn', 'spawnSync', 'exec', 'execSync', 'execFile', 'execFileSync', 'fork']],
]) { const api = require(module); for (const method of methods) api[method] = deny(module + '.' + method); }
require('node:net').Socket.prototype.connect = deny('Socket.connect');
syncBuiltinESMExports();
`, 'utf8');
  const childEnvironment = Object.fromEntries(Object.entries(process.env).filter(([key, value]) => typeof value === 'string' && !['NODE_OPTIONS', 'WINUTIL_MCP_ALLOW_WRITE', 'WINUTIL_MCP_DATA_MODE', 'WINUTIL_MCP_REQUIRE_CLEAN'].includes(key)));
  const client = new Client({ name: 'winutil-package-verifier', version: '1.0.0' });
  const transport = new StdioClientTransport({ command: process.execPath, args: ['--require', guardPath, join(installedDir, 'index.js')], cwd: isolated, env: childEnvironment, stderr: 'pipe' });
  let stderr = '';
  transport.stderr?.on('data', chunk => { stderr += chunk; });
  let toolCount;
  try {
    await client.connect(transport, { timeout: 15000 });
    assert.equal(client.getServerVersion()?.version, installedInfo.version, '握手版本应来自 package.json');
    const { tools } = await client.listTools();
    toolCount = tools.length;
    assert.deepEqual(tools.map(x => x.name).sort(), ['get_status', 'list_bundles', 'list_dns', 'list_tweaks', 'search_apps']);
    const statusResult = await client.callTool({ name: 'get_status', arguments: {} }, undefined, { timeout: 15000 });
    const status = JSON.parse(statusResult.content.find(x => x.type === 'text').text);
    assert.equal(status.mode, 'read-only');
    assert.equal(status.data.source, 'bundled');
    assert.equal(status.data.metadata.packageVersion, installedInfo.version);
    for (const [name, args] of [['search_apps', { query: '微信', limit: 5 }], ['list_bundles', {}], ['list_tweaks', { limit: 5 }], ['list_dns', {}]]) {
      const result = await client.callTool({ name, arguments: args }, undefined, { timeout: 15000 });
      assert.ok(!result.isError, `${name} 调用失败: ${JSON.stringify(result)}`);
      const payload = JSON.parse(result.content.find(x => x.type === 'text').text);
      const rows = payload.apps || payload.bundles || payload.tweaks || payload.dns;
      assert.ok(Array.isArray(rows) && rows.length > 0, `${name} 应从包内快照返回真实数据`);
    }
  } catch (error) { throw new Error(`${error.message}\nMCP stderr: ${stderr}`, { cause: error }); }
  finally { await client.close(); }
  assert.equal(await exists(guardLog), false, '离线查询不应尝试网络或系统命令');

  // Broken distribution must fail startup, not fetch live GitHub content.
  const dataPath = join(installedDir, 'data.json');
  const savedDataPath = join(installedDir, 'data.saved.json');
  await rename(dataPath, savedDataPath);
  for (const missing of [true, false]) {
    if (!missing) await writeFile(dataPath, '{corrupt');
    await assert.rejects(run(process.execPath, ['--require', guardPath, join(installedDir, 'index.js')], { cwd: isolated, env: childEnvironment, timeout: 15000 }),
      error => error.code !== 0 && /打包数据|data\.json/.test(error.stderr || ''), `${missing ? '缺失' : '损坏'}快照必须拒绝启动`);
  }
  assert.equal(await exists(guardLog), false, '损坏包不应回退到网络或源仓库');
  console.log(JSON.stringify({ status: 'passed', input: options.length ? tarball : 'clean-checkout fixture', packageVersion: installedInfo.version,
    integrity: `sha512-${createHash('sha512').update(archiveBytes).digest('base64')}`, sourceCommit: snapshot.metadata.sourceCommit,
    requiredRuntimeFiles: requiredFiles.length, readOnlyTools: toolCount, forbiddenOperations: 0, invalidSnapshotsRejected: 2 }, null, 2));
} finally {
  const scoped = resolve(temporary);
  assert.ok(scoped.startsWith(resolve(tmpdir()) + sep) && scoped.includes('winutil-mcp-pack-'), '清理目标必须是本次隔离目录');
  await rm(scoped, { recursive: true, force: true });
}
