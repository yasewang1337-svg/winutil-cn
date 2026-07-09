#!/usr/bin/env node
// 从仓库配置生成打包快照 data.json(随 npm 包发布,让 MCP 离线自包含、不依赖运行时网络)。
// 发布前自动跑(prepublishOnly)。
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

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
const rd = async (p) => lenientParse(await readFile(join(__dirname, '..', p), 'utf8'));

const [apps, extra, bundles, tweaks, dns] = await Promise.all([
  rd('config/applications.json'), rd('汉化/extra-apps.json'),
  rd('config/bundles.json'), rd('config/tweaks.json'), rd('config/dns.json'),
]);

const merged = {};
for (const [k, v] of Object.entries(apps)) if (v && typeof v === 'object' && v.content) merged[k] = v;
for (const [k, v] of Object.entries(extra)) { if (k === '_meta' || !v || typeof v !== 'object') continue; merged[k] = v; }

const data = { apps: merged, bundles, tweaks, dns };
await writeFile(join(__dirname, 'data.json'), JSON.stringify(data), 'utf8');
console.log(`data.json 生成: 软件 ${Object.keys(merged).length} · 组合 ${Object.keys(bundles).filter(k => k !== '_meta').length} · 优化项 ${Object.keys(tweaks).length} · DNS ${Object.keys(dns).length}`);
