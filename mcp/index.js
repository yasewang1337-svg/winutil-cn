#!/usr/bin/env node
// WinUtil-CN MCP 服务器
// 让 AI 智能体(Claude 等)按意图驱动 WinUtil 中文汉化版:
//   搜索/安装软件、套用组合、一键换源、查询/应用优化项(tweaks)、配置 DNS。
// 数据源:winutil-cn 的 config/*.json + 汉化/extra-apps.json(国货);本地读不到时回落 GitHub raw。

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { readFile, writeFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { promisify } from 'node:util';
import { randomUUID } from 'node:crypto';

const execFileAsync = promisify(execFile);
const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_RAW = 'https://raw.githubusercontent.com/yasewang1337-svg/winutil-cn/main';

// 宽松 JSON 解析:修复 winutil 配置里字符串内的字面控制符(换行/回车/制表),使其成为合法 JSON。
function lenientParse(text) {
  let out = '', inStr = false, esc = false;
  for (const ch of text) {
    if (esc) { out += ch; esc = false; continue; }
    if (ch === '\\') { out += ch; esc = true; continue; }
    if (ch === '"') { inStr = !inStr; out += ch; continue; }
    if (inStr) {
      if (ch === '\n') { out += '\\n'; continue; }
      if (ch === '\r') { out += '\\r'; continue; }
      if (ch === '\t') { out += '\\t'; continue; }
    }
    out += ch;
  }
  return JSON.parse(out);
}

function mergeApps(apps, extra) {
  const merged = {};
  for (const [k, v] of Object.entries(apps || {})) if (v && typeof v === 'object' && v.content) merged[k] = v;
  for (const [k, v] of Object.entries(extra || {})) { if (k === '_meta' || !v || typeof v !== 'object') continue; merged[k] = v; }
  return merged;
}
const readLocal = async (p) => lenientParse(await readFile(join(__dirname, '..', p), 'utf8'));
const readRaw = async (p) => { const r = await fetch(`${REPO_RAW}/${p}`); if (!r.ok) throw new Error(`HTTP ${r.status}`); return lenientParse(await r.text()); };

async function loadData() {
  // 1) 打包快照(发布场景:离线自包含,零运行时网络依赖)
  try {
    const d = JSON.parse(await readFile(join(__dirname, 'data.json'), 'utf8'));
    return { source: 'bundled', apps: d.apps, bundles: d.bundles, tweaks: d.tweaks, dns: d.dns };
  } catch {}
  // 2) 本地仓库实时(从仓库运行:始终最新)
  try {
    const [apps, extra, bundles, tweaks, dns] = await Promise.all([
      readLocal('config/applications.json'), readLocal('汉化/extra-apps.json').catch(() => ({})),
      readLocal('config/bundles.json'), readLocal('config/tweaks.json'), readLocal('config/dns.json'),
    ]);
    return { source: 'local', apps: mergeApps(apps, extra), bundles, tweaks, dns };
  } catch {}
  // 3) GitHub raw(最后兜底:串行,避免并行请求撞限流)
  const apps = await readRaw('config/applications.json');
  const extra = await readRaw('汉化/extra-apps.json').catch(() => ({}));
  const bundles = await readRaw('config/bundles.json');
  const tweaks = await readRaw('config/tweaks.json');
  const dns = await readRaw('config/dns.json');
  return { source: 'raw', apps: mergeApps(apps, extra), bundles, tweaks, dns };
}

const DATA = await loadData();
const BUNDLES = DATA.bundles || {};
const TWEAKS = DATA.tweaks || {};
const DNS = DATA.dns || {};
const ALL_APPS = Object.entries(DATA.apps || {}).map(([key, v]) => ({
  key, name: v.content || key, category: v.category || '', winget: v.winget || '', choco: v.choco || '', description: v.description || '',
}));

const APP_BY_KEY = new Map();
for (const a of ALL_APPS) { APP_BY_KEY.set(a.key.toLowerCase(), a); APP_BY_KEY.set(('wpfinstall' + a.key).toLowerCase(), a); }

const MIRRORS = {
  pip:  { cn: ['pip', ['config', 'set', 'global.index-url', 'https://pypi.tuna.tsinghua.edu.cn/simple']], official: ['pip', ['config', 'unset', 'global.index-url']] },
  npm:  { cn: ['npm', ['config', 'set', 'registry', 'https://registry.npmmirror.com']], official: ['npm', ['config', 'set', 'registry', 'https://registry.npmjs.org']] },
  yarn: { cn: ['yarn', ['config', 'set', 'registry', 'https://registry.npmmirror.com']], official: ['yarn', ['config', 'set', 'registry', 'https://registry.yarnpkg.com']] },
  go:   { cn: ['go', ['env', '-w', 'GOPROXY=https://goproxy.cn,direct']], official: ['go', ['env', '-w', 'GOPROXY=https://proxy.golang.org,direct']] },
};

const ok = (obj) => ({ content: [{ type: 'text', text: JSON.stringify(obj, null, 2) }] });
const q1 = (s) => String(s).replace(/'/g, "''"); // 单引号 PS 字符串转义

// 在管理员权限下运行一段 PowerShell(写临时脚本再执行),返回输出
async function runPwsh(script) {
  const f = join(tmpdir(), `winutilcn-mcp-${randomUUID()}.ps1`);
  await writeFile(f, '﻿' + script, 'utf8'); // BOM 保中文
  try {
    const { stdout, stderr } = await execFileAsync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', f], { timeout: 120000, windowsHide: true });
    return { ok: true, output: (stdout || stderr || '').trim() };
  } catch (e) {
    return { ok: false, output: (e.stdout || '') + (e.stderr || e.message || '') };
  }
}

const server = new McpServer({ name: 'winutil-cn-mcp', version: '0.3.0' });

// ── 软件 ──────────────────────────────────────────────────────────────
server.registerTool('search_apps', {
  title: '搜索软件',
  description: '在 WinUtil 中文汉化版收录的软件库(含微信/QQ/WPS 等国货)里按关键词搜索,返回软件名、分类、winget 包 ID 和介绍。',
  inputSchema: { query: z.string().describe('关键词,中英文皆可'), limit: z.number().int().optional() },
}, async ({ query, limit = 20 }) => {
  const s = query.toLowerCase();
  const hits = ALL_APPS.filter(a => [a.name, a.description, a.category, a.winget, a.key].some(x => x.toLowerCase().includes(s)))
    .slice(0, limit).map(a => ({ name: a.name, category: a.category, winget: a.winget, description: a.description }));
  return ok({ count: hits.length, apps: hits });
});

server.registerTool('list_bundles', {
  title: '列出应用组合',
  description: '列出策展的一键装机组合(国内/国际 × 场景)。每个含名称、说明、软件 key。',
  inputSchema: {},
}, async () => {
  const out = [];
  for (const [id, b] of Object.entries(BUNDLES)) { if (id === '_meta' || !b?.apps) continue; out.push({ id, region: b.region, name: b.name, desc: b.desc, apps: b.apps }); }
  return ok({ count: out.length, bundles: out });
});

server.registerTool('install_apps', {
  title: '安装软件',
  description: '用 winget 静默安装软件。传入 winget 包 ID 或组合里的 app key(自动解析)。⚠️ 会改动系统:默认只预览将装什么,确认无误后加 confirm:true 再调一次才真装。部分软件需管理员权限。',
  inputSchema: { ids: z.array(z.string()), confirm: z.boolean().optional().describe('true=执行安装;省略或 false=只预览,不安装') },
}, async ({ ids, confirm }) => {
  if (!confirm) {
    const willInstall = ids.map(raw => { const app = APP_BY_KEY.get(raw.toLowerCase()); return app?.winget || raw; });
    return ok({ preview: true, willInstall, note: '这是预览,尚未安装任何东西。确认无误后,用相同参数加 confirm:true 再调一次即可安装。' });
  }
  const results = [];
  for (const raw of ids) {
    let wingetId = raw;
    const app = APP_BY_KEY.get(raw.toLowerCase());
    if (app?.winget) wingetId = app.winget;
    if (!wingetId || wingetId.includes(' ')) { results.push({ id: raw, status: 'skipped', reason: '无法解析为 winget ID' }); continue; }
    try {
      const { stdout } = await execFileAsync('winget', ['install', '--id', wingetId, '-e', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'], { timeout: 300000, windowsHide: true });
      results.push({ id: wingetId, status: /Successfully installed|已成功安装|already installed|已安装/i.test(stdout) ? 'installed' : 'ran' });
    } catch (e) { results.push({ id: wingetId, status: 'error', reason: (e.stderr || e.message || '').toString().split('\n').slice(-2).join(' ') }); }
  }
  return ok({ results });
});

// ── 换源 ──────────────────────────────────────────────────────────────
server.registerTool('switch_mirror', {
  title: '换源(国内镜像)',
  description: '把 pip/npm/yarn/go 的包源在国内镜像与官方源之间切换。',
  inputSchema: { tool: z.enum(['pip', 'npm', 'yarn', 'go']), action: z.enum(['cn', 'official']) },
}, async ({ tool, action }) => {
  const spec = MIRRORS[tool]?.[action];
  if (!spec) return ok({ status: 'error', reason: '不支持的组合' });
  try { const { stdout, stderr } = await execFileAsync(spec[0], spec[1], { timeout: 30000, windowsHide: true }); return ok({ tool, action, status: 'done', output: (stdout || stderr || '').trim() }); }
  catch (e) { return ok({ tool, action, status: 'error', reason: `未检测到 ${tool} 或执行失败` }); }
});

// ── 优化项(tweaks) ───────────────────────────────────────────────────
server.registerTool('list_tweaks', {
  title: '查询优化项',
  description: '搜索 WinUtil 的系统优化项(禁用遥测/瘦身/隐私/性能等),返回优化项 key、名称、说明、分类。key 可传给 apply_tweaks。',
  inputSchema: { query: z.string().optional().describe('关键词,如「遥测」「隐私」「telemetry」;留空返回全部(截断)'), limit: z.number().int().optional() },
}, async ({ query = '', limit = 30 }) => {
  const s = query.toLowerCase();
  const out = [];
  for (const [key, t] of Object.entries(TWEAKS)) {
    if (!t || typeof t !== 'object' || !t.Content) continue;
    const hay = [t.Content, t.Description || '', t.category || '', key].join(' ').toLowerCase();
    if (s && !hay.includes(s)) continue;
    out.push({ key, name: t.Content, category: t.category || '', description: t.Description || '' });
    if (out.length >= limit) break;
  }
  return ok({ count: out.length, tweaks: out });
});

server.registerTool('apply_tweaks', {
  title: '应用优化项',
  description: '应用一个或多个优化项(执行其注册表改动 + 服务设置 + 内置脚本)。⚠️ 会修改系统:默认只预览将改什么,确认后加 confirm:true 再调一次才真改。需管理员权限(在管理员终端启动 MCP 宿主)。',
  inputSchema: { keys: z.array(z.string()).describe('优化项 key,如 WPFTweaksTelemetry'), confirm: z.boolean().optional().describe('true=执行;省略或 false=只预览') },
}, async ({ keys, confirm }) => {
  if (!confirm) {
    const plan = keys.map(k => { const t = TWEAKS[k]; return t ? { key: k, name: t.Content, 注册表改动: (t.registry || []).length, 服务设置: (t.service || []).length, 脚本: (t.InvokeScript || []).length } : { key: k, status: '未找到' }; });
    return ok({ preview: true, willApply: plan, note: '这是预览,尚未改动系统。确认后用相同 keys 加 confirm:true 再调一次即可应用。需管理员权限。' });
  }
  const results = [];
  for (const key of keys) {
    const t = TWEAKS[key];
    if (!t) { results.push({ key, status: 'not_found' }); continue; }
    const lines = [`$ErrorActionPreference='Continue'`];
    for (const r of (t.registry || [])) {
      lines.push(`if(-not (Test-Path '${q1(r.Path)}')){New-Item -Path '${q1(r.Path)}' -Force | Out-Null}`);
      lines.push(`New-ItemProperty -Path '${q1(r.Path)}' -Name '${q1(r.Name)}' -PropertyType ${r.Type || 'String'} -Value '${q1(r.Value)}' -Force | Out-Null`);
    }
    for (const sv of (t.service || [])) lines.push(`Set-Service -Name '${q1(sv.Name)}' -StartupType ${sv.StartupType} -ErrorAction SilentlyContinue`);
    for (const scr of (t.InvokeScript || [])) lines.push(scr);
    lines.push(`Write-Output '__TWEAK_DONE__'`);
    const res = await runPwsh(lines.join("\n"));
    results.push({ key, name: t.Content, status: res.output.includes('__TWEAK_DONE__') ? 'applied' : 'ran', note: res.ok ? undefined : res.output.split('\n').slice(-2).join(' ') });
  }
  return ok({ results, warning: '优化项已尝试应用;部分改动需重启或重新登录生效。若报权限错误,请在管理员终端启动 MCP 宿主。' });
});

// ── DNS ───────────────────────────────────────────────────────────────
server.registerTool('list_dns', {
  title: '列出 DNS 方案',
  description: '列出可用的 DNS 提供商(国际:Cloudflare/Google/Quad9/AdGuard;国内:阿里/DNSPod/114/百度)及其地址。名称可传给 set_dns。',
  inputSchema: {},
}, async () => {
  const out = Object.entries(DNS).map(([name, v]) => ({ name, primary: v.Primary, secondary: v.Secondary, primary6: v.Primary6 || '', secondary6: v.Secondary6 || '' }));
  out.unshift({ name: 'Default', primary: '(恢复系统默认/DHCP)', secondary: '' });
  return ok({ count: out.length, dns: out });
});

server.registerTool('set_dns', {
  title: '设置 DNS',
  description: '把所有「已连接」网卡的 DNS 设为指定提供商(用 list_dns 里的名称;Default=恢复默认)。⚠️ 修改系统网络设置:默认只预览,确认后加 confirm:true 才真改。需管理员权限。',
  inputSchema: { provider: z.string().describe('DNS 提供商名称,如 AliDNS / Cloudflare / Default'), confirm: z.boolean().optional().describe('true=执行;省略或 false=只预览') },
}, async ({ provider, confirm }) => {
  let script;
  if (provider === 'Default' || provider === 'DHCP') {
    if (!confirm) return ok({ preview: true, willSet: '恢复系统默认 / DHCP', note: '预览,尚未修改网络。确认后加 confirm:true 再调。需管理员权限。' });
    script = `Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses }; Write-Output 'DNS 已恢复默认'`;
  } else {
    const d = DNS[provider];
    if (!d) return ok({ status: 'not_found', reason: `未知 DNS 提供商: ${provider}`, hint: '用 list_dns 查看可用名称' });
    if (!confirm) return ok({ preview: true, willSet: provider, addresses: { ipv4: [d.Primary, d.Secondary], ipv6: d.Primary6 ? [d.Primary6, d.Secondary6] : '无' }, note: '预览,尚未修改网络。确认后加 confirm:true 再调。需管理员权限。' });
    const v4 = `'${q1(d.Primary)}','${q1(d.Secondary)}'`;
    const v6line = d.Primary6 ? `Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses '${q1(d.Primary6)}','${q1(d.Secondary6)}';` : '';
    script = `Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ${v4}; ${v6line} }; Write-Output 'DNS 已设为 ${q1(provider)}'`;
  }
  const res = await runPwsh(script);
  return ok({ provider, status: res.ok ? 'done' : 'error', output: res.output.split('\n').slice(-3).join(' ') });
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[winutil-cn-mcp v0.3] 已启动(${DATA.source}) · 软件 ${ALL_APPS.length} · 组合 ${Object.keys(BUNDLES).filter(k => k !== '_meta').length} · 优化项 ${Object.keys(TWEAKS).length} · DNS ${Object.keys(DNS).length}`);
