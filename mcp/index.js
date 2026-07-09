#!/usr/bin/env node
// WinUtil-CN MCP 服务器
// 让 AI 智能体(Claude 等)按意图驱动 WinUtil 中文汉化版:搜索/安装软件、套用组合、一键换源。
// 数据源:winutil-cn 的 config/applications.json + 汉化/extra-apps.json(国货) + config/bundles.json。

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { readFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_RAW = 'https://raw.githubusercontent.com/yasewang1337-svg/winutil-cn/main';

// ── 配置加载:优先本地仓库,回落 GitHub raw ──────────────────────────────
async function loadJson(subpath) {
  try {
    return JSON.parse(await readFile(join(__dirname, '..', subpath), 'utf8'));
  } catch {
    const r = await fetch(`${REPO_RAW}/${subpath}`);
    if (!r.ok) throw new Error(`无法加载 ${subpath}: HTTP ${r.status}`);
    return JSON.parse(await r.text());
  }
}

// 合并 applications.json 与 extra-apps.json(国货),统一成 {key,name,category,winget,choco,description}
async function loadApps() {
  const [apps, extra] = await Promise.all([
    loadJson('config/applications.json'),
    loadJson('汉化/extra-apps.json').catch(() => ({})),
  ]);
  const merged = {};
  for (const [k, v] of Object.entries(apps)) {
    if (v && typeof v === 'object' && v.content) merged[k] = v;
  }
  for (const [k, v] of Object.entries(extra)) {
    if (k === '_meta' || !v || typeof v !== 'object') continue;
    merged[k] = v;
  }
  return Object.entries(merged).map(([key, v]) => ({
    key,
    name: v.content || key,
    category: v.category || '',
    winget: v.winget || '',
    choco: v.choco || '',
    description: v.description || '',
  }));
}

const [ALL_APPS, BUNDLES] = await Promise.all([
  loadApps(),
  loadJson('config/bundles.json').catch(() => ({})),
]);

// key(带或不带 WPFInstall 前缀)→ app
const APP_BY_KEY = new Map();
for (const a of ALL_APPS) {
  APP_BY_KEY.set(a.key.toLowerCase(), a);
  APP_BY_KEY.set(('wpfinstall' + a.key).toLowerCase(), a);
}

// ── 换源命令表 ────────────────────────────────────────────────────────
const MIRRORS = {
  pip:   { cn: ['pip', ['config', 'set', 'global.index-url', 'https://pypi.tuna.tsinghua.edu.cn/simple']],
           official: ['pip', ['config', 'unset', 'global.index-url']] },
  npm:   { cn: ['npm', ['config', 'set', 'registry', 'https://registry.npmmirror.com']],
           official: ['npm', ['config', 'set', 'registry', 'https://registry.npmjs.org']] },
  yarn:  { cn: ['yarn', ['config', 'set', 'registry', 'https://registry.npmmirror.com']],
           official: ['yarn', ['config', 'set', 'registry', 'https://registry.yarnpkg.com']] },
  go:    { cn: ['go', ['env', '-w', 'GOPROXY=https://goproxy.cn,direct']],
           official: ['go', ['env', '-w', 'GOPROXY=https://proxy.golang.org,direct']] },
};

const ok = (obj) => ({ content: [{ type: 'text', text: JSON.stringify(obj, null, 2) }] });

// ── MCP 服务器 ────────────────────────────────────────────────────────
const server = new McpServer({ name: 'winutil-cn-mcp', version: '0.1.0' });

server.registerTool('search_apps', {
  title: '搜索软件',
  description: '在 WinUtil 中文汉化版收录的软件库(含微信/QQ/WPS 等国货)里按关键词搜索,返回软件名、分类、winget 包 ID 和介绍。用于按意图找要装的软件。',
  inputSchema: { query: z.string().describe('搜索关键词,可中英文,如「浏览器」「微信」「vscode」「docker」'), limit: z.number().int().optional().describe('最多返回条数,默认 20') },
}, async ({ query, limit = 20 }) => {
  const q = query.toLowerCase();
  const hits = ALL_APPS.filter(a =>
    a.name.toLowerCase().includes(q) || a.description.toLowerCase().includes(q) ||
    a.category.toLowerCase().includes(q) || a.winget.toLowerCase().includes(q) || a.key.toLowerCase().includes(q)
  ).slice(0, limit).map(a => ({ name: a.name, category: a.category, winget: a.winget, description: a.description }));
  return ok({ count: hits.length, apps: hits });
});

server.registerTool('list_bundles', {
  title: '列出应用组合',
  description: '列出策展的「一键装机组合」,按 国内/国际 × 场景(办公/开发/影音/隐私安全等)分组。每个组合含名称、说明和其包含的软件 key(可直接传给 install_apps)。',
  inputSchema: {},
}, async () => {
  const out = [];
  for (const [id, b] of Object.entries(BUNDLES)) {
    if (id === '_meta' || !b || typeof b !== 'object' || !b.apps) continue;
    out.push({ id, region: b.region, name: b.name, desc: b.desc, apps: b.apps });
  }
  return ok({ count: out.length, bundles: out });
});

server.registerTool('install_apps', {
  title: '安装软件',
  description: '用 winget 静默安装软件。传入 winget 包 ID 数组(从 search_apps 或 list_bundles 获取;bundles 里的 WPFInstall<key> 会自动解析成 winget ID)。逐个安装并返回结果。注意:部分软件安装需管理员权限。',
  inputSchema: { ids: z.array(z.string()).describe('winget 包 ID(如 Tencent.WeChat)或组合里的 app key(如 WPFInstallwechat)数组') },
}, async ({ ids }) => {
  const results = [];
  for (const raw of ids) {
    // 解析:若是 app key(WPFInstall<key> 或 <key>)→ winget id;否则当作 winget id
    let wingetId = raw;
    const app = APP_BY_KEY.get(raw.toLowerCase());
    if (app && app.winget) wingetId = app.winget;
    if (!wingetId || wingetId.includes(' ')) { results.push({ id: raw, status: 'skipped', reason: '无法解析为 winget ID' }); continue; }
    try {
      const { stdout } = await execFileAsync('winget', ['install', '--id', wingetId, '-e', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'], { timeout: 300000, windowsHide: true });
      const done = /Successfully installed|已成功安装|already installed|已安装/i.test(stdout);
      results.push({ id: wingetId, status: done ? 'installed' : 'ran', tail: stdout.trim().split('\n').slice(-2).join(' ') });
    } catch (e) {
      results.push({ id: wingetId, status: 'error', reason: (e.stderr || e.message || '').toString().split('\n').slice(-2).join(' ') });
    }
  }
  return ok({ results });
});

server.registerTool('switch_mirror', {
  title: '换源(国内镜像)',
  description: '把开发工具的包管理源在「国内镜像」和「官方源」之间切换,国内装包飞快。支持 pip(清华)/npm/yarn(npmmirror)/go(goproxy.cn)。',
  inputSchema: {
    tool: z.enum(['pip', 'npm', 'yarn', 'go']).describe('要换源的工具'),
    action: z.enum(['cn', 'official']).describe('cn=换国内镜像, official=恢复官方源'),
  },
}, async ({ tool, action }) => {
  const spec = MIRRORS[tool]?.[action];
  if (!spec) return ok({ status: 'error', reason: '不支持的组合' });
  try {
    const { stdout, stderr } = await execFileAsync(spec[0], spec[1], { timeout: 30000, windowsHide: true });
    return ok({ tool, action, status: 'done', output: (stdout || stderr || '').trim() });
  } catch (e) {
    return ok({ tool, action, status: 'error', reason: `未检测到 ${tool} 或执行失败: ${(e.message || '').split('\n')[0]}` });
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error('[winutil-cn-mcp] 已启动 · 软件库 ' + ALL_APPS.length + ' 条 · 组合 ' + Object.keys(BUNDLES).filter(k => k !== '_meta').length + ' 个');
