#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { loadData } from './lib/data.mjs';
import { createExecutor } from './lib/executor.mjs';
import { createWinutilServer } from './lib/server.mjs';

function parseArguments(args) {
  let allowWrite = false;
  let mode = 'auto';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--allow-write') allowWrite = true;
    else if (args[i] === '--data-mode' && ['auto', 'source', 'bundled'].includes(args[i + 1])) mode = args[++i];
    else if (args[i] === '--help') return { help: true };
    else throw new Error(`未知参数或无效值：${args[i]}。使用 --help 查看帮助。`);
  }
  return { allowWrite, mode };
}

try {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    console.log('winutil-cn-mcp [--allow-write] [--data-mode auto|source|bundled]\n默认只提供查询。启用修改后，每次修改仍须先预览，再用同一参数和 planId 确认。');
  } else {
    const { version } = JSON.parse(await readFile(new URL('./package.json', import.meta.url), 'utf8'));
    const data = await loadData({ mode: options.mode });
    const server = createWinutilServer({ data, version, allowWrite: options.allowWrite, executor: createExecutor() });
    await server.connect(new StdioServerTransport());
    console.error(`[winutil-cn-mcp ${version}] ${options.allowWrite ? '已启用修改；须逐项确认计划' : '只读模式'} · 数据来源 ${data.source}`);
  }
} catch (error) {
  console.error(`[winutil-cn-mcp] 启动失败：${error.message}`);
  process.exitCode = 1;
}
