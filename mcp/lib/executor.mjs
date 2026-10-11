import { execFile } from 'node:child_process';
import { mkdtemp, writeFile, rm, lstat } from 'node:fs/promises';
import { join, resolve, relative, basename, isAbsolute } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { createHash, randomUUID } from 'node:crypto';
import { isIP } from 'node:net';

const WORKER = fileURLToPath(new URL('../powershell/worker.ps1', import.meta.url));
const PACKAGE_ID = /^[A-Za-z0-9][A-Za-z0-9+_.-]{0,199}$/;
const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const META_FIELDS = new Set(['Content', 'Description', 'category', 'panel', 'link', 'Checked', 'Type', 'ButtonWidth']);
const MIRRORS = Object.freeze({
  pip: { command: 'pip', cn: ['config', 'set', 'global.index-url', 'https://pypi.tuna.tsinghua.edu.cn/simple'], official: ['config', 'unset', 'global.index-url'], read: ['config', 'get', 'global.index-url'] },
  npm: { command: 'npm', cn: ['config', 'set', 'registry', 'https://registry.npmmirror.com'], official: ['config', 'set', 'registry', 'https://registry.npmjs.org'], read: ['config', 'get', 'registry'] },
  yarn: { command: 'yarn', cn: ['config', 'set', 'registry', 'https://registry.npmmirror.com'], official: ['config', 'set', 'registry', 'https://registry.yarnpkg.com'], read: ['config', 'get', 'registry'] },
  go: { command: 'go', cn: ['env', '-w', 'GOPROXY=https://goproxy.cn,direct'], official: ['env', '-w', 'GOPROXY=https://proxy.golang.org,direct'], read: ['env', 'GOPROXY'] },
});

const fault = (code, message, details) => Object.assign(new Error(message), { code, ...(details ? { details } : {}) });
const deepFreeze = value => { if (value && typeof value === 'object') { Object.values(value).forEach(deepFreeze); Object.freeze(value); } return value; };
const cancelled = signal => { if (signal?.aborted) throw fault('CANCELLED', '操作已取消；请核对已完成项目。'); };
const list = (value, name, max = 50) => {
  if (!Array.isArray(value) || value.length < 1 || value.length > max || value.some(v => typeof v !== 'string' || !v.trim() || v.length > 250)) throw fault('INVALID_ARGUMENT', `${name} 必须包含 1–${max} 个非空字符串。`);
  return [...new Set(value.map(v => v.trim()))];
};
const hasPayload = value => value !== undefined && value !== null && !(Array.isArray(value) && value.length === 0);

/** Deliberately accepts declarative settings only. It never evaluates catalog scripts. */
export function describeTweak(tweak) {
  const reasons = [];
  if (!tweak || typeof tweak !== 'object' || Array.isArray(tweak)) return { supported: false, reason: '未找到优化项', reasons: ['未找到优化项'] };
  for (const [key, value] of Object.entries(tweak)) {
    if (!META_FIELDS.has(key) && !['registry', 'service'].includes(key) && hasPayload(value)) reasons.push(`包含尚未接入的 ${key} 动作`);
  }
  if (tweak.Type && !['CheckBox', 'ToggleButton'].includes(tweak.Type)) reasons.push(`不支持 ${tweak.Type} 交互类型`);
  const registry = [], services = [];
  if (tweak.registry !== undefined && !Array.isArray(tweak.registry)) reasons.push('registry 不是数组');
  if (tweak.service !== undefined && !Array.isArray(tweak.service)) reasons.push('service 不是数组');
  for (const r of Array.isArray(tweak.registry) ? tweak.registry : []) {
    if (!r || Object.keys(r).some(k => !['Path', 'Name', 'Value', 'Type', 'OriginalValue'].includes(k)) ||
      typeof r.Path !== 'string' || !/^HK(?:LM|CU):\\[^\x00-\x1f*?]+$/i.test(r.Path) || r.Path.split('\\').some(p => p === '..' || p === '.') ||
      typeof r.Name !== 'string' || !r.Name || /[\x00-\x1f\\]/.test(r.Name) || !['String', 'DWord', 'QWord'].includes(r.Type)) {
      reasons.push('包含不支持的注册表路径、字段或类型'); continue;
    }
    const value = r.Value;
    if (r.Type === 'String' ? typeof value !== 'string' || /[\x00]/.test(value) || /^<.*>$/.test(value) :
      !/^(0|[1-9][0-9]*)$/.test(String(value)) || BigInt(value) > (r.Type === 'DWord' ? 4294967295n : 9223372036854775807n)) {
      reasons.push('包含占位符或不支持的注册表值'); continue;
    }
    registry.push({ path: r.Path, name: r.Name === '(default)' ? '' : r.Name, type: r.Type, value: String(value) });
  }
  for (const s of Array.isArray(tweak.service) ? tweak.service : []) {
    const startupType = s?.StartupType === 'Disable' ? 'Disabled' : s?.StartupType;
    if (!s || Object.keys(s).some(k => !['Name', 'StartupType', 'OriginalType'].includes(k)) || typeof s.Name !== 'string' || !/^[A-Za-z0-9_.-]{1,128}$/.test(s.Name) || !['Automatic', 'Manual', 'Disabled'].includes(startupType)) {
      reasons.push('包含不支持的服务操作'); continue;
    }
    services.push({ name: s.Name, startupType });
  }
  if (!registry.length && !services.length) reasons.push('没有可受控执行的注册表或服务改动');
  return { supported: reasons.length === 0, ...(reasons.length ? { reason: [...new Set(reasons)].join('；') } : {}), reasons: [...new Set(reasons)], registry, services };
}

/** Fixed mirror arguments only; user input is never passed to cmd.exe. */
export function toolCommand(tool, args, platform = process.platform) {
  if (platform === 'win32' && ['npm', 'yarn'].includes(tool)) {
    if (args.some(arg => !/^[A-Za-z0-9_.:/=,+-]+$/.test(arg))) throw fault('INVALID_COMMAND', '命令参数不在固定允许范围内。');
    return { command: join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'cmd.exe'), args: ['/d', '/s', '/c', `${tool}.cmd ${args.join(' ')}`], windowsVerbatimArguments: true };
  }
  return { command: tool, args };
}

export function defaultRunner(command, args, options = {}) {
  return new Promise(resolve => {
    let result, closed = false;
    const child = execFile(command, args, { timeout: 120000, maxBuffer: 2 * 1024 * 1024, windowsHide: true, encoding: 'utf8', ...options }, (error, stdout, stderr) => {
      result = { exitCode: error ? (Number.isInteger(error.code) ? error.code : null) : 0, stdout: stdout || '', stderr: stderr || '',
        ...(error ? { error: error.message, code: error.code, signal: error.signal, killed: Boolean(error.killed) } : {}) };
      if (closed) resolve(result);
    });
    // Abort can report an error before the process closes. Keep the server's mutation lock until close.
    child.once('close', () => { closed = true; if (result) resolve(result); });
  });
}

export function createExecutor(options = {}) {
  const runner = options.runner || defaultRunner;
  const platform = options.platform || process.platform;
  const temporaryRoot = options.tempDirectory || tmpdir();
  const powershell = options.powershell || join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
  const issued = new WeakSet();
  const run = async (command, args, settings = {}) => {
    cancelled(settings.signal);
    try {
      const result = await runner(command, args, { windowsHide: true, timeout: 120000, ...settings });
      return { ...result, exitCode: Number.isInteger(result.exitCode) ? result.exitCode : null, stdout: String(result.stdout || ''), stderr: String(result.stderr || '') };
    } catch (error) {
      return { exitCode: Number.isInteger(error.code) ? error.code : null, stdout: String(error.stdout || ''), stderr: String(error.stderr || ''), code: error.code, error: error.message };
    }
  };
  const invokeTool = async (tool, args, settings) => {
    const command = toolCommand(tool, args, platform);
    return run(command.command, command.args, { ...settings, ...(command.windowsVerbatimArguments ? { windowsVerbatimArguments: true } : {}) });
  };
  const worker = async (request, { signal } = {}) => {
    if (platform !== 'win32') throw fault('WINDOWS_REQUIRED', '此操作需要 Windows。');
    cancelled(signal);
    let directory;
    try {
      directory = await mkdtemp(join(temporaryRoot, 'winutil-cn-mcp-'));
      const path = join(directory, 'request.json');
      const backupId = request.operation === 'list_adapters' ? undefined : randomUUID();
      const body = JSON.stringify({ schemaVersion: 1, ...request, ...(backupId ? { backupId } : {}) });
      await writeFile(path, body, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
      const hash = createHash('sha256').update(body).digest('hex');
      const processResult = await run(powershell, ['-NoLogo', '-NoProfile', '-NonInteractive', '-File', WORKER, '-InputPath', path, '-ExpectedSha256', hash], { signal });
      const { code: processCode, ...processDetails } = processResult;
      if (processCode !== undefined) processDetails.processCode = processCode;
      let response, checkpoint;
      for (const line of processResult.stdout.replace(/^\uFEFF/, '').trim().split(/\r?\n/)) {
        try {
          const item = JSON.parse(line);
          if (item.schemaVersion === 1 && item.checkpoint === true && item.backupId === backupId && Array.isArray(item.results)) checkpoint = item;
          else if (item.checkpoint !== true) response = item;
        } catch { /* No marker or completion text is accepted as proof. */ }
      }
      if (!response || response.schemaVersion !== 1 || !['completed', 'partial', 'failed'].includes(response.status) || !Array.isArray(response.results)) {
        const results = checkpoint?.results || [];
        const policyBlocked = !checkpoint && /PSSecurityException|AuthorizationManager|running scripts is disabled|not digitally signed|execution polic(?:y|ies)|执行策略|禁止运行脚本/i.test(`${processResult.stderr}\n${processResult.stdout}`);
        const unavailable = !checkpoint && processCode === 'ENOENT';
        const code = signal?.aborted ? 'CANCELLED' : policyBlocked ? 'POLICY_BLOCKED' : checkpoint || processResult.killed || processResult.signal ? 'WORKER_INTERRUPTED' : unavailable || processResult.exitCode !== 0 ? 'WORKER_START_FAILED' : 'WORKER_PROTOCOL_ERROR';
        const readOnly = request.operation === 'list_adapters';
        const message = policyBlocked ? `PowerShell 执行策略阻止${readOnly ? '网卡查询脚本' : '脚本'}运行，未修改系统。MCP 不会更改执行策略；原始原因保留在 stderr。` :
          unavailable ? '未找到 Windows PowerShell，未执行操作；原始错误保留在进程详情中。' :
          readOnly ? 'PowerShell 未返回有效的网卡查询结果，未修改系统；请查看 stderr 和退出码。' :
          'PowerShell 未返回最终结果。results 仅含已确认完成项目；pending 可能已部分修改，请核对后使用 backupId 恢复，不要自动重试。备份 unconfirmed 时可能尚未创建。';
        return { ...processDetails, status: results.length ? 'partial' : signal?.aborted ? 'cancelled' : 'failed', code, results,
          ...(backupId && !policyBlocked && !unavailable ? { backupId, backupStatus: checkpoint ? 'confirmed' : 'unconfirmed', pending: checkpoint?.pending || null } : {}),
          outcomeKnown: readOnly || policyBlocked || unavailable, message };
      }
      const failedItems = response.results.some(r => r?.status !== 'completed');
      if (response.status === 'completed' && (failedItems || (request.operation !== 'list_adapters' && response.results.length === 0))) {
        response.status = response.results.some(r => r?.status === 'completed') ? 'partial' : 'failed';
        response.code = 'INCONSISTENT_WORKER_RESULT';
      }
      if (processResult.exitCode !== 0 || processResult.stderr.trim()) {
        if (response.status === 'completed') response.status = response.results.some(r => r.status === 'completed') ? 'partial' : 'failed';
      }
      if (backupId) {
        const reportedBackup = response.backupId;
        response.backupId = backupId;
        response.backupStatus = reportedBackup === backupId || checkpoint ? 'confirmed' : 'unconfirmed';
        if (response.status === 'completed' && response.backupStatus !== 'confirmed') {
          response.status = response.results.length ? 'partial' : 'failed';
          response.code = 'BACKUP_NOT_CONFIRMED';
        }
        if (!response.results.length && checkpoint?.results.length) {
          response.results = checkpoint.results;
          response.pending = checkpoint.pending;
          response.status = 'partial';
          response.outcomeKnown = false;
        }
      }
      return { ...processDetails, ...response, ...(signal?.aborted ? { status: response.results.some(r => r.status === 'completed') ? 'partial' : 'cancelled', code: 'CANCELLED' } : {}) };
    } finally {
      if (directory) {
        const target = resolve(directory), root = resolve(temporaryRoot), within = relative(root, target);
        if (!within || within.startsWith('..') || isAbsolute(within) || !basename(target).startsWith('winutil-cn-mcp-')) throw fault('UNSAFE_TEMP_PATH', '临时目录不在本次工作范围内，未删除。');
        const info = await lstat(target);
        if (info.isSymbolicLink() || !info.isDirectory()) throw fault('UNSAFE_TEMP_PATH', '临时目录被替换，未递归删除。');
        await rm(target, { recursive: true, force: true });
      }
    }
  };
  const listNetworkAdapters = async (settings = {}) => {
    const result = await worker({ operation: 'list_adapters' }, settings);
    if (result.status !== 'completed') throw fault(result.code || 'ADAPTER_QUERY_FAILED', result.message || '无法读取网卡列表。', result);
    return result.results;
  };

  async function plan(operation, args, data, settings = {}) {
    cancelled(settings.signal);
    const blockers = [];
    const p = { operation, supported: true, summary: '', details: [], blockers, requiresAdministrator: ['apply_tweaks', 'set_dns'].includes(operation) };
    if (operation === 'install_apps') {
      const ids = list(args.ids, 'ids');
      const byKey = new Map();
      for (const [key, app] of Object.entries(data.apps || {})) {
        const normalized = key.toLowerCase(), short = normalized.replace(/^wpfinstall/, '');
        byKey.set(normalized, app); byKey.set(short, app); byKey.set(`wpfinstall${short}`, app);
      }
      const packages = [];
      for (const raw of ids) {
        const app = byKey.get(raw.toLowerCase());
        const id = app ? app.winget : raw;
        if (!id || !PACKAGE_ID.test(id)) blockers.push({ id: raw, reason: '未找到有效 winget 包 ID；不能传入命令选项或多个包。' });
        else if (!packages.some(p => p.id.toLowerCase() === id.toLowerCase())) packages.push({ id, name: app?.content || id });
      }
      p.packages = packages; p.details = packages; p.summary = `安装 ${packages.length} 个软件包`;
      p.agreements = '执行即交由 winget 接受对应的软件包及源协议；请在客户端确认具体软件后执行。';
      p.recovery = '安装器的影响不能由 MCP 自动回滚；可在 Windows「已安装的应用」中卸载。';
    } else if (operation === 'switch_mirror') {
      const spec = MIRRORS[args.tool];
      if (!spec || !['cn', 'official'].includes(args.action)) throw fault('INVALID_ARGUMENT', '不支持的工具或源。');
      p.tool = args.tool; p.action = args.action;
      p.summary = `切换 ${args.tool} 到${args.action === 'cn' ? '国内镜像' : '官方默认源'}`;
      p.details = [{ tool: args.tool, arguments: [...spec[args.action]] }];
      p.scope = '修改当前用户的工具配置；项目配置或环境变量可能覆盖该设置。';
      p.recovery = '执行结果保留修改前的配置值；可用对应工具的 config/env 命令恢复。yarn 仅支持 Classic 1.x。';
    } else if (operation === 'apply_tweaks') {
      p.tweaks = list(args.keys, 'keys').map(key => {
        const t = data.tweaks?.[key];
        const description = describeTweak(t);
        if (!description.supported) blockers.push({ key, reason: description.reason });
        return { key, name: t?.Content || key, ...description };
      });
      p.details = p.tweaks; p.summary = `应用 ${p.tweaks.length} 项声明式系统设置`;
      p.recovery = '执行前保存原注册表值和服务启动类型；结果中的 backupId 可交给 worker.ps1 -RestoreBackupId 恢复。';
    } else if (operation === 'set_dns') {
      p.provider = ['Default', 'DHCP'].includes(args.provider) ? 'Default' : args.provider;
      const d = data.dns?.[p.provider];
      if (p.provider !== 'Default' && !d) throw fault('UNKNOWN_DNS', '未知 DNS 提供商；请先调用 list_dns。');
      p.addresses = p.provider === 'Default' ? [] : [d.Primary, d.Secondary, d.Primary6, d.Secondary6].filter(Boolean);
      if (p.addresses.some(ip => !isIP(ip))) throw fault('INVALID_DNS', 'DNS 配置包含无效 IP 地址。');
      if (!args.adapterIds?.length) throw fault('ADAPTER_SELECTION_REQUIRED', '请先调用 list_network_adapters，再明确传入 adapterIds（网卡 GUID）。');
      const ids = list(args.adapterIds, 'adapterIds', 10).map(id => id.replace(/^\{|\}$/g, '').toLowerCase());
      if (ids.some(id => !GUID.test(id))) throw fault('INVALID_ADAPTER_ID', 'adapterIds 必须是 list_network_adapters 返回的 GUID。');
      const adapters = await listNetworkAdapters(settings);
      p.adapters = [...new Set(ids)].map(id => {
        const adapter = adapters.find(a => a.id.toLowerCase() === id);
        if (!adapter) throw fault('ADAPTER_NOT_FOUND', `网卡 ${id} 已不存在。`);
        return { id, interfaceIndex: adapter.interfaceIndex, name: adapter.name, macAddress: adapter.macAddress, description: adapter.description };
      });
      p.summary = `将 ${p.adapters.length} 张指定网卡的 DNS 设为 ${p.provider}`;
      p.details = p.adapters.map(adapter => ({ ...adapter, addresses: [...p.addresses], resetToDhcp: p.provider === 'Default' }));
      p.addressFamilyBehavior = p.provider === 'Default' ? 'IPv4/IPv6 均恢复自动获取' : '只修改提供商已提供地址的协议族；其他协议族保持原设置';
      p.recovery = '执行前按 IPv4/IPv6 保存静态地址及自动获取状态；结果 backupId 可用 worker.ps1 -RestoreBackupId 恢复。';
    } else throw fault('UNKNOWN_OPERATION', '未知操作。');
    if (platform !== 'win32') blockers.push({ reason: '执行功能仅支持 Windows；当前环境仍可查询软件和设置目录。' });
    p.supported = blockers.length === 0;
    deepFreeze(p); issued.add(p);
    return p;
  }

  async function execute(operation, p, { signal } = {}) {
    cancelled(signal);
    if (!p || !issued.has(p) || p.operation !== operation) throw fault('INVALID_PLAN', '需要由当前执行器生成的原始预览计划。');
    if (!p.supported) throw fault('UNSUPPORTED_PLAN', '计划含未支持项目，未执行任何改动。', p.blockers);
    issued.delete(p);
    if (operation === 'apply_tweaks') return worker({ operation, tweaks: p.tweaks.map(t => ({ key: t.key, name: t.name, registry: t.registry, services: t.services })) }, { signal });
    if (operation === 'set_dns') return worker({ operation, provider: p.provider, addresses: p.addresses, adapters: p.adapters }, { signal });
    const tool = operation === 'install_apps' ? 'winget' : p.tool;
    const probe = await invokeTool(tool, [tool === 'go' ? 'version' : '--version'], { signal, timeout: 15000 });
    if (probe.exitCode !== 0) return { status: signal?.aborted ? 'cancelled' : 'failed', code: signal?.aborted ? 'CANCELLED' : 'TOOL_UNAVAILABLE', results: [], preflight: probe, message: `${tool} 不可用或执行失败，未开始修改。` };
    if (tool === 'yarn' && !/^1\./.test(probe.stdout.trim())) return { status: 'failed', code: 'UNSUPPORTED_YARN', results: [], message: '当前只支持 Yarn Classic 1.x；没有修改配置。' };
    const results = [];
    if (operation === 'install_apps') {
      for (const pkg of p.packages) {
        if (signal?.aborted) break;
        const result = await invokeTool('winget', ['install', '--id', pkg.id, '--exact', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'], { signal, timeout: 300000 });
        results.push({ ...pkg, status: result.exitCode === 0 && !signal?.aborted ? 'completed' : signal?.aborted ? 'cancelled' : 'failed', ...result });
      }
    } else {
      const spec = MIRRORS[tool];
      const before = await invokeTool(tool, spec.read, { signal, timeout: 15000 });
      // pip returns 1 when the specific setting is absent. Other errors must not be treated as an empty setting.
      const unsetPip = tool === 'pip' && before.exitCode === 1 && /No such key\s*[-:]?\s*global\.index-url/i.test(before.stderr || before.stdout);
      if (before.exitCode !== 0 && !unsetPip) return { status: signal?.aborted ? 'cancelled' : 'failed', code: 'CONFIG_READ_FAILED', results: [], preflight: before, message: '无法读取修改前的源配置，已停止。' };
      cancelled(signal);
      const result = unsetPip && p.action === 'official' ? { exitCode: 0, stdout: '该配置未设置，无需修改。', stderr: '' } : await invokeTool(tool, spec[p.action], { signal, timeout: 30000 });
      results.push({ tool, action: p.action, status: result.exitCode === 0 && !signal?.aborted ? 'completed' : signal?.aborted ? 'cancelled' : 'failed', ...result,
        before: { value: unsetPip ? null : before.stdout.trim(), unset: unsetPip }, recovery: { tool, setting: tool === 'go' ? 'GOPROXY' : tool === 'pip' ? 'global.index-url' : 'registry', previousValue: unsetPip ? null : before.stdout.trim(), note: '请使用工具自身的 config set / env -w 恢复此值；原值为空时移除覆盖。不要把值拼接为 shell 命令。' } });
    }
    const completed = results.filter(r => r.status === 'completed').length;
    return { status: signal?.aborted ? (completed ? 'partial' : 'cancelled') : completed === results.length ? 'completed' : completed ? 'partial' : 'failed',
      results, ...(signal?.aborted ? { code: 'CANCELLED', message: '后续项目已停止；已完成的修改仍然保留，安装器子进程可能需要在任务管理器中确认。' } : {}) };
  }
  return { plan, execute, listNetworkAdapters };
}
