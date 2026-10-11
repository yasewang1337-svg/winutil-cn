import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { readFileSync } from 'node:fs';
import { createPlanStore, PlanError } from './plans.mjs';
import { describeTweak } from './executor.mjs';

const reply = (value, isError = false) => ({ content: [{ type: 'text', text: JSON.stringify(value, null, 2) }], ...(isError ? { isError: true } : {}) });
const errorValue = error => ({ status: 'error', code: error.code || 'OPERATION_FAILED', message: error.message || String(error), ...(error.details ? { details: error.details } : {}) });
const errorReply = error => reply(errorValue(error), true);
const readAnnotations = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };
const pageSchema = { limit: z.number().int().min(1).max(100).default(20), offset: z.number().int().min(0).max(100000).default(0) };
const querySchema = z.string().trim().max(256).default('');
const idsSchema = z.array(z.string().trim().min(1).max(200)).min(1).max(40);
const confirmationSchema = { confirm: z.boolean().default(false), planId: z.string().uuid().optional() };
const { version: packageVersion } = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

export function createWinutilServer({ data, version = packageVersion, allowWrite = false, executor, now = Date.now, planTtlMs = 300000 }) {
  // A connection uses one catalog snapshot. External object/file changes must
  // not silently replace the action the user has already previewed.
  data = structuredClone(data);
  const server = new McpServer({ name: 'winutil-cn-mcp', version });
  const plans = createPlanStore({ now, ttlMs: planTtlMs });
  let busy = false;
  let lastResult = null;
  const apps = Object.entries(data.apps).map(([key, v]) => ({ key, name: v.content || key, category: v.category || '', winget: v.winget || '', choco: v.choco || '', description: v.description || '' }));
  const bundles = Object.entries(data.bundles).filter(([key, v]) => key !== '_meta' && Array.isArray(v?.apps)).map(([id, b]) => ({ id, region: b.region, name: b.name, desc: b.desc, apps: b.apps, defaultApps: b.defaultApps || [], purposes: b.purposes || {} }));
  const tweaks = Object.entries(data.tweaks).filter(([, t]) => t?.Content).map(([key, t]) => ({ key, name: t.Content, description: t.Description || '', category: t.category || '', execution: describeTweak(t) }));
  const dns = [{ name: 'Default', primary: '(恢复系统默认/DHCP)', secondary: '' }, ...Object.entries(data.dns).map(([name, d]) => ({ name, primary: d.Primary, secondary: d.Secondary, primary6: d.Primary6 || '', secondary6: d.Secondary6 || '' }))];
  const paged = (all, key, limit, offset) => ({ count: all.slice(offset, offset + limit).length, total: all.length, offset, hasMore: offset + limit < all.length, [key]: all.slice(offset, offset + limit) });
  const registerRead = (name, title, description, inputSchema, handler) => server.registerTool(name, { title, description, inputSchema, annotations: readAnnotations }, async args => {
    try { return reply(await handler(args)); } catch (error) { return errorReply(error); }
  });

  registerRead('get_status', '查看 MCP 状态', '查看版本、只读/修改模式、数据来源和执行状态，不修改系统。', {}, () => ({
    version, mode: allowWrite ? 'write-enabled' : 'read-only',
    data: { source: data.source, metadata: data.metadata, counts: { apps: apps.length, bundles: bundles.length, tweaks: tweaks.length, supportedTweaks: tweaks.filter(t => t.execution.supported).length, dns: dns.length } },
    execution: { busy, lastResult, confirmationRequired: true, note: '修改模式须由启动参数 --allow-write 显式启用；planId 不能代替客户端向用户确认。取消后可在 busy=false 时查看 lastResult；仅保留当前连接最近一次执行结果。' },
  }));
  registerRead('search_apps', '搜索软件', '按名称、用途、分类、包 ID 或 key 查询软件；支持分页，不安装。', { query: querySchema, ...pageSchema }, ({ query, limit, offset }) => {
    const q = query.toLowerCase();
    return paged(apps.filter(a => [a.key, a.name, a.description, a.category, a.winget].some(v => v.toLowerCase().includes(q))), 'apps', limit, offset);
  });
  registerRead('list_bundles', '列出应用组合', '列出候选、默认推荐与每项用途。组合不是全部安装清单。', {}, () => ({ count: bundles.length, bundles }));
  registerRead('list_tweaks', '查询优化项', '查询优化项目录及 MCP 执行支持范围。含复杂脚本的项目请使用桌面版。', { query: querySchema, ...pageSchema }, ({ query, limit, offset }) => {
    const q = query.toLowerCase();
    return paged(tweaks.filter(t => [t.key, t.name, t.description, t.category].some(v => v.toLowerCase().includes(q))), 'tweaks', limit, offset);
  });
  registerRead('list_dns', '列出 DNS 方案', '列出 DNS 提供商及地址，不修改网卡。', {}, () => ({ count: dns.length, dns }));

  if (allowWrite) {
    if (!executor) throw new Error('修改模式缺少执行器。');
    registerRead('list_network_adapters', '列出可选网卡', '读取网卡身份和状态，供 DNS 预览显式选择，不修改网络。', {}, async () => ({ adapters: await executor.listNetworkAdapters() }));
    const registerWrite = (operation, title, description, inputSchema, openWorldHint) => server.registerTool(operation, {
      title, description: `${description} 默认只预览；先向用户核对，再用相同参数、返回的 planId 和 confirm:true 执行。计划仅当前连接内一次有效，5 分钟过期。`,
      inputSchema: { ...inputSchema, ...confirmationSchema },
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint },
    }, async ({ confirm, planId, ...args }, extra) => {
      try {
        if (extra?.signal?.aborted) throw new PlanError('CANCELLED', '请求已取消。');
        if (!confirm) {
          const plan = await executor.plan(operation, args, data, { signal: extra?.signal });
          if (plan.supported === false || plan.blockers?.length) return reply({ preview: true, status: 'blocked', operation, plan }, true);
          return reply({ preview: true, operation, ...plans.add(operation, args, plan), plan });
        }
        if (!planId) throw new PlanError('PLAN_REQUIRED', '缺少确认计划。请先省略 confirm 生成预览。');
        if (busy) throw new PlanError('BUSY', '另一个修改任务正在执行，请等待完成后再试。');
        const plan = plans.consume(planId, operation, args);
        busy = true;
        try {
          const result = await executor.execute(operation, plan, { signal: extra?.signal });
          // An MCP client discards a cancelled request's eventual response. Keep
          // its recovery information available to a subsequent status query.
          lastResult = { ...structuredClone(result), operation, finishedAt: new Date(now()).toISOString() };
          return reply(result, result.status !== 'completed');
        } catch (error) {
          lastResult = { ...errorValue(error), operation, finishedAt: new Date(now()).toISOString(), status: 'failed', outcomeKnown: false };
          throw error;
        } finally { busy = false; }
      } catch (error) { return errorReply(error); }
    });
    registerWrite('install_apps', '安装软件', '用 winget 安装明确选择的软件，不会自动安装整个组合。', { ids: idsSchema }, true);
    registerWrite('switch_mirror', '切换开发工具源', '在国内镜像与官方源之间切换固定工具配置。', { tool: z.enum(['pip', 'npm', 'yarn', 'go']), action: z.enum(['cn', 'official']) }, true);
    registerWrite('apply_tweaks', '应用受支持的优化项', '仅执行已支持的注册表和服务配置。遇到复杂脚本或不支持项，整份计划拒绝执行。', { keys: idsSchema }, false);
    registerWrite('set_dns', '设置选定网卡 DNS', '只修改明确选中的网卡。先用 list_network_adapters 获取 adapterIds；执行前复核网卡身份。', { provider: z.string().trim().min(1).max(100), adapterIds: z.array(z.string().trim().min(1).max(100)).min(1).max(10).optional() }, false);
  }
  return server;
}
