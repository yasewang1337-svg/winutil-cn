import assert from 'node:assert/strict';
import { test } from 'node:test';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { windowsEnvironment } from './integration/windows-environment.mjs';

test('真实 stdio 保留 Windows Path 覆盖，避免继承 PATH 抢先选择全局工具', { timeout: 10000 }, async t => {
  const expectedPath = 'WINUTIL_MCP_ISOLATED_EXECUTABLE_PATH';
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: ['-e', 'process.stdout.write(JSON.stringify({jsonrpc:"2.0",method:"test/environment",params:{path:process.env.PATH,pathKeys:Object.keys(process.env).filter(k=>k.toLowerCase()==="path"),venv:process.env.VIRTUAL_ENV}})+"\\n")'],
    env: windowsEnvironment({ Path: expectedPath, Virtual_Env: 'isolated-python-venv' }),
    stderr: 'pipe',
  });
  t.after(() => transport.close());
  const message = new Promise((resolve, reject) => { transport.onmessage = resolve; transport.onerror = reject; });
  await transport.start();
  const result = await message;
  assert.equal(result.method, 'test/environment');
  assert.equal(result.params.path, expectedPath);
  assert.deepEqual(result.params.pathKeys, ['PATH']);
  assert.equal(result.params.venv, 'isolated-python-venv');
});
