import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, writeFile, readFile, rm, lstat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

test('真实 CLI 默认只读：五个查询均可用且不派发系统修改或联网', { timeout: 30000 }, async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'winutil-mcp-protocol-'));
  t.after(async () => {
    const target = path.resolve(directory), root = path.resolve(tmpdir());
    const within = path.relative(root, target);
    assert.ok(within && !within.startsWith('..') && !path.isAbsolute(within));
    assert.ok(path.basename(target).startsWith('winutil-mcp-protocol-'));
    const info = await lstat(target);
    assert.ok(info.isDirectory() && !info.isSymbolicLink());
    await rm(target, { recursive: true, force: true });
  });
  const attempts = path.join(directory, 'blocked.jsonl');
  const guard = path.join(directory, 'guard.mjs');
  await writeFile(attempts, '');
  await writeFile(guard, `
import cp from 'node:child_process';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';
import tls from 'node:tls';
import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const block = name => (...args) => {
  fs.appendFileSync(process.env.WINUTIL_TEST_ATTEMPTS, JSON.stringify({ name, argument: String(args[0]) }) + '\\n');
  throw new Error('READ_ONLY_PROTOCOL_GUARD: ' + name);
};
// A source checkout reports its commit/dirty metadata using these two exact,
// read-only Git commands. Everything else stays blocked, including PowerShell.
const originalExecFile = cp.execFile;
cp.execFile = (file, args, ...rest) => {
  const metadata = file === 'git' && args[0] === '-C' && (
    (args.length === 4 && args[2] === 'rev-parse' && args[3] === 'HEAD') ||
    (args.length === 5 && args[2] === 'status' && args[3] === '--porcelain' && args[4] === '--untracked-files=normal')
  );
  if (metadata) return originalExecFile(file, args, ...rest);
  return block('execFile')(file, args);
};
for (const key of ['exec', 'spawn', 'fork', 'execSync', 'execFileSync', 'spawnSync']) cp[key] = block(key);
for (const source of [http, https]) for (const key of ['request', 'get']) source[key] = block(key);
net.connect = net.createConnection = block('net.connect');
tls.connect = block('tls.connect');
syncBuiltinESMExports();
globalThis.fetch = block('fetch');
`, 'utf8');
  const directoryUrl = new URL('../', import.meta.url);
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: ['--import', pathToFileURL(guard).href, fileURLToPath(new URL('index.js', directoryUrl))],
    cwd: fileURLToPath(directoryUrl),
    env: { WINUTIL_TEST_ATTEMPTS: attempts },
    stderr: 'pipe',
  });
  let stderr = '';
  transport.stderr.on('data', chunk => { stderr += chunk; });
  const client = new Client({ name: 'stdio-regression', version: '1.0.0' });
  t.after(() => client.close());
  await client.connect(transport);
  const packageInfo = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));
  assert.equal(client.getServerVersion().version, packageInfo.version);
  const { tools } = await client.listTools();
  assert.deepEqual(tools.map(tool => tool.name).sort(), ['get_status', 'list_bundles', 'list_dns', 'list_tweaks', 'search_apps']);
  for (const [name, args, field] of [
    ['search_apps', { query: '微信' }, 'apps'],
    ['list_bundles', {}, 'bundles'],
    ['list_tweaks', { query: '', limit: 100 }, 'tweaks'],
    ['list_dns', {}, 'dns'],
  ]) {
    const result = await client.callTool({ name, arguments: args });
    assert.notEqual(result.isError, true, `${name}: ${JSON.stringify(result)}; ${stderr}`);
    const payload = JSON.parse(result.content[0].text);
    assert.ok(payload[field]?.length > 0, `${name} 必须返回实际仓库数据`);
  }
  const status = await client.callTool({ name: 'get_status', arguments: {} });
  assert.equal(JSON.parse(status.content[0].text).mode, 'read-only');
  assert.equal((await readFile(attempts, 'utf8')).trim(), '', '只读查询不得尝试派发系统修改进程或联网');
  assert.doesNotMatch(stderr, /READ_ONLY_PROTOCOL_GUARD/);
  await client.close();
});
