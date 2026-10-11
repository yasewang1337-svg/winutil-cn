import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { createWinutilServer } from '../lib/server.mjs';

const reads = ['get_status', 'list_bundles', 'list_dns', 'list_tweaks', 'search_apps'];
const writes = ['apply_tweaks', 'install_apps', 'set_dns', 'switch_mirror'];
const adapterId = '11111111-2222-3333-4444-555555555555';
const fixtures = () => ({
  source: 'test', metadata: { sourceCommit: 'a'.repeat(40) },
  apps: {
    WPFInstallwechat: { content: '微信', description: '聊天与文件传输', category: '通讯', winget: 'Tencent.WeChat' },
    WPFInstallgit: { content: 'Git', description: '版本控制', category: '开发', winget: 'Git.Git' },
    WPFInstallcode: { content: 'Visual Studio Code', description: '代码编辑器', category: '开发', winget: 'Microsoft.VisualStudioCode' },
  },
  bundles: { _meta: {}, coding: { name: '编程', region: 'global', desc: '代码与版本控制', apps: ['WPFInstallgit', 'WPFInstallcode'], defaultApps: ['WPFInstallgit'], purposes: { WPFInstallgit: '版本控制', WPFInstallcode: '编写代码' } } },
  tweaks: {
    WPFTweaksFixture: { Content: '测试优化', Description: '测试注册表设置', registry: [{ Path: 'HKCU:\\Software\\WinUtilFixture', Name: 'Example', Type: 'DWord', Value: 1 }] },
    WPFTweaksScript: { Content: '脚本优化', Description: '有脚本依赖的测试项', InvokeScript: ['Invoke-WinUtilFixture'] },
  },
  dns: { Cloudflare: { Primary: '1.1.1.1', Secondary: '1.0.0.1' } },
});

function deferred() {
  let resolve;
  const promise = new Promise(r => { resolve = r; });
  return { promise, resolve };
}

function decode(result) {
  const text = result.content?.find(item => item.type === 'text')?.text;
  assert.equal(typeof text, 'string', 'MCP 工具结果必须含文本内容');
  return JSON.parse(text);
}

async function harness(t, options = {}) {
  const calls = { plans: [], executions: [], adapters: 0 };
  const executor = {
    async plan(operation, args) {
      calls.plans.push({ operation, args });
      return { summary: operation, details: structuredClone(args), supported: true, blockers: [] };
    },
    async execute(operation, plan, context) {
      calls.executions.push({ operation, plan, context });
      return { status: 'completed', results: [{ status: 'completed' }] };
    },
    async listNetworkAdapters() {
      calls.adapters++;
      return [{ id: adapterId, name: '测试网卡', status: 'Up' }];
    },
    ...options.executor,
  };
  const data = options.data ?? fixtures();
  const server = createWinutilServer({ data, version: '0.4.0', allowWrite: false, ...options, executor });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: 'protocol-regression', version: '1.0.0' });
  t.after(async () => { await client.close(); await server.close(); });
  await server.connect(serverTransport);
  await client.connect(clientTransport);
  const call = (name, args = {}, requestOptions) => client.callTool({ name, arguments: args }, undefined, requestOptions);
  return { client, server, data, executor, calls, call };
}

test('默认握手只暴露五个只读工具，并声明只读属性', async t => {
  const h = await harness(t);
  assert.deepEqual(h.client.getServerVersion(), { name: 'winutil-cn-mcp', version: '0.4.0' });
  const { tools } = await h.client.listTools();
  assert.deepEqual(tools.map(tool => tool.name).sort(), reads);
  for (const tool of tools) assert.equal(tool.annotations?.readOnlyHint, true, tool.name);
  const status = decode(await h.call('get_status'));
  assert.equal(status.mode, 'read-only');
  assert.equal(status.version, '0.4.0');
  assert.equal(status.execution.busy, false);
  assert.equal(status.execution.confirmationRequired, true);
  assert.equal(h.calls.executions.length, 0);
});

test('只读模式不能通过直接调用隐藏工具绕过开关', async t => {
  const h = await harness(t);
  for (const name of [...writes, 'list_network_adapters']) {
    const result = await h.call(name, { ids: ['Git.Git'], confirm: true });
    assert.equal(result.isError, true, name);
  }
  assert.equal(h.calls.plans.length, 0);
  assert.equal(h.calls.executions.length, 0);
  assert.equal(h.calls.adapters, 0);
});

test('中文软件搜索和分页保留稳定 key、总数及下一页标志', async t => {
  const h = await harness(t);
  const chinese = decode(await h.call('search_apps', { query: '微信' }));
  assert.equal(chinese.total, 1);
  assert.equal(chinese.apps[0].key, 'WPFInstallwechat');
  const first = decode(await h.call('search_apps', { query: '', limit: 2, offset: 0 }));
  const last = decode(await h.call('search_apps', { query: '', limit: 2, offset: 2 }));
  assert.equal(first.total, 3);
  assert.equal(first.apps.length, 2);
  assert.equal(first.hasMore, true);
  assert.equal(last.apps.length, 1);
  assert.equal(last.hasMore, false);
  assert.equal(new Set([...first.apps, ...last.apps].map(app => app.key)).size, 3);
});

test('软件与优化查询拒绝负数、超大上限及错误输入类型', async t => {
  const h = await harness(t);
  for (const name of ['search_apps', 'list_tweaks']) {
    for (const args of [{ limit: -1 }, { limit: 0 }, { limit: 101 }, { limit: 1.5 }, { offset: -1 }, { offset: 1.5 }, { query: 123 }]) {
      const result = await h.call(name, { query: '', ...args });
      assert.equal(result.isError, true, `${name}: ${JSON.stringify(args)}`);
    }
  }
});

test('组合保留推荐子集与用途，DNS 包含恢复默认入口', async t => {
  const h = await harness(t);
  const bundles = decode(await h.call('list_bundles')).bundles;
  assert.equal(bundles.length, 1);
  assert.deepEqual(bundles[0].defaultApps, ['WPFInstallgit']);
  assert.deepEqual(bundles[0].purposes, fixtures().bundles.coding.purposes);
  const dns = decode(await h.call('list_dns')).dns;
  assert.ok(dns.some(item => item.name === 'Default'));
  assert.ok(dns.some(item => item.name === 'Cloudflare' && item.primary === '1.1.1.1'));
});

test('开启写入后增加修改工具及网卡查询，并保留风险属性', async t => {
  const h = await harness(t, { allowWrite: true });
  const { tools } = await h.client.listTools();
  assert.deepEqual(tools.map(tool => tool.name).sort(), [...reads, ...writes, 'list_network_adapters'].sort());
  for (const name of writes) {
    const tool = tools.find(tool => tool.name === name);
    assert.equal(tool.annotations?.readOnlyHint, false, name);
    assert.equal(tool.annotations?.destructiveHint, true, name);
  }
  assert.equal(decode(await h.call('get_status')).mode, 'write-enabled');
  const adapters = decode(await h.call('list_network_adapters')).adapters;
  assert.equal(adapters[0].id, adapterId);
});

for (const [operation, args] of [
  ['install_apps', { ids: ['Git.Git'] }],
  ['switch_mirror', { tool: 'npm', action: 'cn' }],
  ['apply_tweaks', { keys: ['WPFTweaksFixture'] }],
  ['set_dns', { provider: 'Cloudflare', adapterIds: [adapterId] }],
]) {
  test(`${operation} 默认预览，明确确认后执行且计划只能使用一次`, async t => {
    const h = await harness(t, { allowWrite: true });
    const preview = decode(await h.call(operation, args));
    assert.equal(preview.preview, true);
    assert.equal(preview.operation, operation);
    assert.equal(typeof preview.planId, 'string');
    assert.ok(preview.expiresAt);
    assert.equal(h.calls.executions.length, 0);
    const confirmed = await h.call(operation, { ...args, confirm: true, planId: preview.planId });
    assert.notEqual(confirmed.isError, true);
    assert.equal(h.calls.executions.length, 1);
    const replay = await h.call(operation, { ...args, confirm: true, planId: preview.planId });
    assert.equal(replay.isError, true);
    assert.equal(h.calls.executions.length, 1);
  });
}

test('没有预览计划时，confirm:true 无权直接执行任何修改', async t => {
  const h = await harness(t, { allowWrite: true });
  for (const [name, args] of [
    ['install_apps', { ids: ['Git.Git'] }], ['switch_mirror', { tool: 'npm', action: 'cn' }],
    ['apply_tweaks', { keys: ['WPFTweaksFixture'] }], ['set_dns', { provider: 'Cloudflare' }],
  ]) assert.equal((await h.call(name, { ...args, confirm: true })).isError, true, name);
  assert.equal(h.calls.executions.length, 0);
});

test('计划不能用于另一个操作、另一组参数或另一连接', async t => {
  const h = await harness(t, { allowWrite: true });
  const other = await harness(t, { allowWrite: true });
  const args = { ids: ['Git.Git'] };
  const { planId } = decode(await h.call('install_apps', args));
  assert.equal((await h.call('switch_mirror', { tool: 'npm', action: 'cn', confirm: true, planId })).isError, true);
  assert.equal((await h.call('install_apps', { ids: ['Microsoft.VisualStudioCode'], confirm: true, planId })).isError, true);
  assert.equal((await other.call('install_apps', { ...args, confirm: true, planId })).isError, true);
  assert.equal(h.calls.executions.length + other.calls.executions.length, 0);
});

test('预览满五分钟后过期，不能执行', async t => {
  let time = 1800000000000;
  const h = await harness(t, { allowWrite: true, now: () => time });
  const args = { ids: ['Git.Git'] };
  const { planId } = decode(await h.call('install_apps', args));
  time += 300001;
  const result = await h.call('install_apps', { ...args, confirm: true, planId });
  assert.equal(result.isError, true);
  assert.equal(h.calls.executions.length, 0);
});

test('预览后外部目录变化不能替换已经向用户展示的安装包', async t => {
  const data = fixtures();
  const h = await harness(t, { data, allowWrite: true, executor: { async plan(_operation, _args, catalog) {
    return { summary: '安装 Git', supported: true, blockers: [], details: { winget: catalog.apps.WPFInstallgit.winget } };
  } } });
  const args = { ids: ['WPFInstallgit'] };
  const preview = decode(await h.call('install_apps', args));
  assert.equal(preview.plan.details.winget, 'Git.Git');
  data.apps.WPFInstallgit.winget = 'Microsoft.VisualStudioCode';
  const result = await h.call('install_apps', { ...args, confirm: true, planId: preview.planId });
  assert.notEqual(result.isError, true);
  assert.equal(h.calls.executions.length, 1);
  assert.equal(h.calls.executions[0].plan.details.winget, 'Git.Git');
  const next = decode(await h.call('install_apps', args));
  assert.equal(next.plan.details.winget, 'Git.Git', '运行中的连接保持启动时的目录快照');
});

test('不支持的优化计划返回阻断原因且不颁发确认 token', async t => {
  const h = await harness(t, { allowWrite: true, executor: { async plan() {
    return { summary: '缺少桌面辅助上下文', details: [], supported: false, blockers: ['unsupported_script'] };
  } } });
  const result = await h.call('apply_tweaks', { keys: ['WPFTweaksScript'] });
  const payload = decode(result);
  assert.equal(result.isError, true);
  assert.equal(payload.status, 'blocked');
  assert.equal(payload.planId, undefined);
  assert.deepEqual(payload.plan.blockers, ['unsupported_script']);
  assert.equal(h.calls.executions.length, 0);
});

for (const status of ['failed', 'partial']) {
  test(`执行结果 ${status} 以 MCP isError 返回并保留逐项结果`, async t => {
    let count = 0;
    const h = await harness(t, { allowWrite: true, executor: { async execute() {
      count++;
      return { status, results: [{ id: 'Git.Git', status: 'failed', stderr: 'Access denied' }] };
    } } });
    const args = { ids: ['Git.Git'] };
    const { planId } = decode(await h.call('install_apps', args));
    const result = await h.call('install_apps', { ...args, confirm: true, planId });
    assert.equal(result.isError, true);
    const payload = decode(result);
    assert.equal(payload.status, status);
    assert.equal(payload.results[0].stderr, 'Access denied');
    const latest = decode(await h.call('get_status')).execution.lastResult;
    assert.equal(latest.operation, 'install_apps');
    assert.equal(latest.status, status);
    assert.equal(latest.results[0].stderr, 'Access denied');
    assert.ok(Number.isFinite(Date.parse(latest.finishedAt)));
    assert.equal((await h.call('install_apps', { ...args, confirm: true, planId })).isError, true);
    assert.equal(count, 1);
    assert.deepEqual(decode(await h.call('get_status')).execution.lastResult, latest, '计划拒绝不覆盖上一真实执行结果');
  });
}

test('执行器异常反馈为明确错误并释放忙状态', async t => {
  const details = { stderr: 'Fixture policy restriction', exitCode: 1 };
  const h = await harness(t, { allowWrite: true, executor: { async execute() { throw Object.assign(new Error('Fixture access denied'), { details }); } } });
  const args = { tool: 'npm', action: 'cn' };
  const { planId } = decode(await h.call('switch_mirror', args));
  const result = await h.call('switch_mirror', { ...args, confirm: true, planId });
  assert.equal(result.isError, true);
  const payload = decode(result);
  assert.equal(payload.status, 'error');
  assert.equal(typeof payload.code, 'string');
  assert.match(payload.message, /Fixture access denied/);
  assert.deepEqual(payload.details, details);
  const execution = decode(await h.call('get_status')).execution;
  assert.equal(execution.busy, false);
  assert.equal(execution.lastResult.operation, 'switch_mirror');
  assert.match(execution.lastResult.message, /Fixture access denied/);
  assert.equal(execution.lastResult.outcomeKnown, false);
  assert.deepEqual(execution.lastResult.details, details);
});

test('执行中的计划阻止并发修改，状态查询仍可用', { timeout: 10000 }, async t => {
  const entered = deferred(), release = deferred();
  let count = 0;
  const h = await harness(t, { allowWrite: true, executor: { async execute() {
    count++;
    entered.resolve();
    await release.promise;
    return { status: 'completed', results: [] };
  } } });
  const args = { ids: ['Git.Git'] };
  const first = decode(await h.call('install_apps', args));
  const second = decode(await h.call('switch_mirror', { tool: 'npm', action: 'cn' }));
  const running = h.call('install_apps', { ...args, confirm: true, planId: first.planId });
  await entered.promise;
  try {
    assert.equal(decode(await h.call('get_status')).execution.busy, true);
    const concurrent = await h.call('switch_mirror', { tool: 'npm', action: 'cn', confirm: true, planId: second.planId });
    assert.equal(concurrent.isError, true);
    assert.equal(count, 1);
  } finally { release.resolve(); await running; }
  assert.equal(decode(await h.call('get_status')).execution.busy, false);
});

test('客户端取消向执行器传递信号，直到执行器停止才解除互斥', { timeout: 10000 }, async t => {
  const entered = deferred(), release = deferred(), cancelled = deferred();
  const h = await harness(t, { allowWrite: true, executor: { async execute(_operation, _plan, { signal }) {
    signal.addEventListener('abort', () => cancelled.resolve(), { once: true });
    entered.resolve();
    await release.promise;
    return { status: 'partial', backupId: adapterId, backupStatus: 'confirmed',
      results: [{ key: 'fixture', status: 'completed' }], pending: { key: 'pending-fixture' }, outcomeKnown: false };
  } } });
  const args = { ids: ['Git.Git'] };
  const preview = decode(await h.call('install_apps', args));
  const abort = new AbortController();
  const running = h.call('install_apps', { ...args, confirm: true, planId: preview.planId }, { signal: abort.signal }).then(
    () => assert.fail('客户端取消应中止等待'),
    error => assert.match(String(error), /abort|cancel/i),
  );
  await entered.promise;
  try {
    abort.abort();
    await cancelled.promise;
    assert.equal(decode(await h.call('get_status')).execution.busy, true);
    assert.equal((await h.call('install_apps', { ...args, confirm: true, planId: preview.planId })).isError, true);
  } finally { release.resolve(); await running; }
  for (let attempt = 0; attempt < 20; attempt++) {
    const execution = decode(await h.call('get_status')).execution;
    if (!execution.busy) {
      assert.equal(execution.lastResult.operation, 'install_apps');
      assert.equal(execution.lastResult.status, 'partial');
      assert.equal(execution.lastResult.backupId, adapterId);
      assert.equal(execution.lastResult.backupStatus, 'confirmed');
      assert.equal(execution.lastResult.results[0].status, 'completed');
      assert.equal(execution.lastResult.pending.key, 'pending-fixture');
      assert.equal(execution.lastResult.outcomeKnown, false);
      return;
    }
    await new Promise(resolve => setImmediate(resolve));
  }
  assert.fail('执行器停止后忙状态仍未释放');
});
