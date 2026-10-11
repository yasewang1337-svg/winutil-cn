#!/usr/bin/env node
import { randomUUID } from 'node:crypto';
import { rename, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadData } from './lib/data.mjs';

// npm pack and npm publish both execute prepack. No network access is needed.
const packageDir = dirname(fileURLToPath(import.meta.url));
const data = await loadData();
if (process.env.WINUTIL_MCP_REQUIRE_CLEAN === '1'
  && (data.source !== 'source' || !data.metadata.sourceCommit || data.metadata.sourceDirty !== false)) {
  throw new Error('发布构建需要干净的 Git 源码检出；请提交或移开修改后重试。');
}
if (data.source === 'source') {
  const temporary = join(packageDir, `.data-${randomUUID()}.tmp`);
  try {
    const { source, ...snapshot } = data;
    await writeFile(temporary, JSON.stringify(snapshot), 'utf8');
    await rename(temporary, join(packageDir, 'data.json'));
  } finally { await rm(temporary, { force: true }); }
}
console.log(`data.json 已验证 (${data.source}): 软件 ${Object.keys(data.apps).length} · 组合 ${Object.keys(data.bundles).filter(k => k !== '_meta').length} · 优化项 ${Object.keys(data.tweaks).length} · DNS ${Object.keys(data.dns).length}`);
