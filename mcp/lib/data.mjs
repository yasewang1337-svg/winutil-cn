import { createHash } from 'node:crypto';
import { execFile } from 'node:child_process';
import { readFile, stat } from 'node:fs/promises';
import { isIP } from 'node:net';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const DEFAULT_PACKAGE_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const DATA_SCHEMA_VERSION = 1;
export const SOURCE_FILES = [
  'config/applications.json', '汉化/extra-apps.json', 'config/bundles.json',
  'config/tweaks.json', 'config/dns.json',
];
const ID = /^[a-zA-Z0-9][a-zA-Z0-9_.+-]{0,255}$/;
const REGISTRY_TYPES = new Set(['String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord', 'None']);
const SERVICE_TYPES = new Set(['Automatic', 'Manual', 'Disabled', 'AutomaticDelayedStart']);

function fail(path, message) { throw new Error(`MCP 数据无效 (${path}): ${message}`); }
function record(value, path) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(path, '应为对象');
  return value;
}
function text(value, path, { empty = false } = {}) {
  if (typeof value !== 'string' || (!empty && !value.trim()) || value.includes('\0')) fail(path, '应为有效字符串');
  return value;
}
function identifier(value, path) {
  if (typeof value !== 'string' || !ID.test(value)) fail(path, '标识符包含不支持的字符');
}
function strings(value, path) {
  if (!Array.isArray(value)) fail(path, '应为字符串数组');
  value.forEach((item, index) => text(item, `${path}[${index}]`));
}
function rejectUnsafeKeys(value, path = 'data') {
  if (!value || typeof value !== 'object') return;
  for (const [key, item] of Object.entries(value)) {
    if (['__proto__', 'prototype', 'constructor'].includes(key)) fail(`${path}.${key}`, '不允许的对象键');
    rejectUnsafeKeys(item, `${path}.${key}`);
  }
}

// Upstream JSON contains literal line breaks in strings. Repair only these
// control characters, preserving escaping and rejecting other syntax errors.
export function parseConfig(textValue) {
  let output = '', inString = false, escaped = false;
  for (const char of textValue.replace(/^\uFEFF/, '')) {
    if (inString && escaped) { output += char; escaped = false; continue; }
    if (inString && char === '\\') { output += char; escaped = true; continue; }
    if (char === '"') { inString = !inString; output += char; continue; }
    if (inString && ['\n', '\r', '\t'].includes(char)) {
      output += char === '\n' ? '\\n' : char === '\r' ? '\\r' : '\\t';
    } else output += char;
  }
  return JSON.parse(output);
}

function mergeApps(apps, extra) {
  const merged = {};
  for (const [label, source] of [['applications', apps], ['extra-apps', extra]]) {
    record(source, label);
    for (const [key, value] of Object.entries(source)) {
      if (key === '_meta') continue;
      record(value, `${label}.${key}`);
      merged[key] = value;
    }
  }
  return merged;
}

/** Validate command-argument fields and catalog relationships; scripts remain trusted source code. */
export function validateData(data) {
  record(data, 'data');
  rejectUnsafeKeys(data);
  const apps = record(data.apps, 'apps');
  if (!Object.keys(apps).length) fail('apps', '软件目录不能为空');
  const appKeys = new Set();
  for (const [key, app] of Object.entries(apps)) {
    identifier(key, `apps.${key}`);
    if (appKeys.has(key.toLowerCase())) fail(`apps.${key}`, '重复的软件键（不区分大小写）');
    appKeys.add(key.toLowerCase());
    record(app, `apps.${key}`);
    text(app.content, `apps.${key}.content`);
    for (const field of ['category', 'description', 'link']) {
      if (app[field] !== undefined) text(app[field], `apps.${key}.${field}`, { empty: true });
    }
    if (app.winget !== undefined && app.winget !== '') identifier(app.winget, `apps.${key}.winget`);
    if (app.choco !== undefined && app.choco !== '') {
      text(app.choco, `apps.${key}.choco`);
      // Desktop catalog supports multiple Chocolatey IDs separated by semicolons.
      for (const id of app.choco.split(';')) identifier(id, `apps.${key}.choco`);
    }
    if (app.foss !== undefined && typeof app.foss !== 'boolean') fail(`apps.${key}.foss`, '应为布尔值');
  }
  for (const [key, bundle] of Object.entries(record(data.bundles, 'bundles'))) {
    if (key === '_meta') continue;
    identifier(key, `bundles.${key}`);
    record(bundle, `bundles.${key}`);
    for (const field of ['name', 'region', 'desc']) text(bundle[field], `bundles.${key}.${field}`);
    strings(bundle.apps, `bundles.${key}.apps`);
    const refs = new Set();
    for (const ref of bundle.apps) {
      if (!/^WPFInstall/i.test(ref) || !appKeys.has(ref.slice(10).toLowerCase())) fail(`bundles.${key}.apps`, `未知软件引用 ${ref}`);
      if (refs.has(ref.toLowerCase())) fail(`bundles.${key}.apps`, `重复软件引用 ${ref}`);
      refs.add(ref.toLowerCase());
    }
    if (bundle.defaultApps !== undefined) {
      strings(bundle.defaultApps, `bundles.${key}.defaultApps`);
      for (const ref of bundle.defaultApps) if (!refs.has(ref.toLowerCase())) fail(`bundles.${key}.defaultApps`, `推荐项不在候选清单中: ${ref}`);
    }
    if (bundle.purposes !== undefined) {
      record(bundle.purposes, `bundles.${key}.purposes`);
      for (const [ref, purpose] of Object.entries(bundle.purposes)) {
        if (!refs.has(ref.toLowerCase())) fail(`bundles.${key}.purposes`, `用途引用未知软件 ${ref}`);
        text(purpose, `bundles.${key}.purposes.${ref}`);
      }
    }
  }
  for (const [key, tweak] of Object.entries(record(data.tweaks, 'tweaks'))) {
    identifier(key, `tweaks.${key}`);
    record(tweak, `tweaks.${key}`);
    text(tweak.Content, `tweaks.${key}.Content`);
    for (const field of ['Description', 'category']) if (tweak[field] !== undefined) text(tweak[field], `tweaks.${key}.${field}`, { empty: true });
    for (const field of ['InvokeScript', 'UndoScript', 'appx']) if (tweak[field] !== undefined) strings(tweak[field], `tweaks.${key}.${field}`);
    if (tweak.registry !== undefined) {
      if (!Array.isArray(tweak.registry)) fail(`tweaks.${key}.registry`, '应为数组');
      for (const [index, item] of tweak.registry.entries()) {
        const path = `tweaks.${key}.registry[${index}]`;
        record(item, path);
        text(item.Path, `${path}.Path`);
        if (!/^(HKLM|HKCU|HKU|HKCR|HKCC):\\[^\r\n\0]+$/i.test(item.Path)) fail(`${path}.Path`, '应为 Windows 注册表路径');
        text(item.Name, `${path}.Name`, { empty: true });
        if (!REGISTRY_TYPES.has(item.Type)) fail(`${path}.Type`, '不支持的注册表类型');
        for (const field of ['Value', 'OriginalValue']) {
          if (item[field] === undefined && field === 'OriginalValue') continue;
          if (!(typeof item[field] === 'string' || typeof item[field] === 'number' || (Array.isArray(item[field]) && item[field].every(x => typeof x === 'string' || typeof x === 'number')))) fail(`${path}.${field}`, '不支持的注册表值');
        }
      }
    }
    if (tweak.service !== undefined) {
      if (!Array.isArray(tweak.service)) fail(`tweaks.${key}.service`, '应为数组');
      for (const [index, item] of tweak.service.entries()) {
        const path = `tweaks.${key}.service[${index}]`;
        record(item, path);
        identifier(item.Name, `${path}.Name`);
        for (const field of ['StartupType', 'OriginalType']) {
          if (item[field] === undefined && field === 'OriginalType') continue;
          // Historical source uses an unambiguous PowerShell enum abbreviation.
          if (item[field] === 'Disable') item[field] = 'Disabled';
          if (!SERVICE_TYPES.has(item[field])) fail(`${path}.${field}`, '不支持的服务启动类型');
        }
      }
    }
  }
  for (const [key, dns] of Object.entries(record(data.dns, 'dns'))) {
    identifier(key, `dns.${key}`);
    record(dns, `dns.${key}`);
    for (const field of ['Primary', 'Secondary']) if (isIP(dns[field]) !== 4) fail(`dns.${key}.${field}`, '应为 IPv4 地址');
    for (const field of ['Primary6', 'Secondary6']) if (dns[field] !== undefined && dns[field] !== '' && isIP(dns[field]) !== 6) fail(`dns.${key}.${field}`, '应为 IPv6 地址');
  }
  return data;
}

function validateMetadata(metadata, version) {
  record(metadata, 'metadata');
  if (metadata.schemaVersion !== DATA_SCHEMA_VERSION) fail('metadata.schemaVersion', '快照格式不兼容，请重新构建');
  if (metadata.packageVersion !== version) fail('metadata.packageVersion', '快照版本与 MCP 包版本不一致，请重新构建');
  if (metadata.sourceCommit !== null && !/^[a-f0-9]{40}$/i.test(metadata.sourceCommit)) fail('metadata.sourceCommit', '应为完整 Git SHA 或 null');
  if (metadata.sourceDirty !== null && typeof metadata.sourceDirty !== 'boolean') fail('metadata.sourceDirty', '应为布尔值或 null');
  if (typeof metadata.generatedAt !== 'string' || !Number.isFinite(Date.parse(metadata.generatedAt))) fail('metadata.generatedAt', '缺少有效生成时间');
  record(metadata.sourceFiles, 'metadata.sourceFiles');
  for (const file of SOURCE_FILES) if (!/^[a-f0-9]{64}$/i.test(metadata.sourceFiles[file])) fail(`metadata.sourceFiles.${file}`, '缺少源文件 SHA256');
}

async function exists(path) {
  try { await stat(path); return true; } catch (error) { if (error.code === 'ENOENT') return false; throw error; }
}
async function isSourceTree(packageDir, repoRoot) {
  // A random neighboring config/ folder must not override an installed package.
  return resolve(repoRoot, 'mcp') === resolve(packageDir)
    && await exists(join(repoRoot, '.git'))
    && await exists(join(repoRoot, 'Compile.ps1'))
    && await exists(join(repoRoot, 'scripts', 'main.ps1'));
}
async function provenance(repoRoot) {
  try {
    const { stdout: commit } = await execFileAsync('git', ['-C', repoRoot, 'rev-parse', 'HEAD'], { windowsHide: true, timeout: 5000 });
    const { stdout: dirty } = await execFileAsync('git', ['-C', repoRoot, 'status', '--porcelain', '--untracked-files=normal'], { windowsHide: true, timeout: 5000 });
    return { sourceCommit: commit.trim(), sourceDirty: Boolean(dirty.trim()) };
  } catch { return { sourceCommit: null, sourceDirty: null }; }
}

export async function loadData({ mode = 'auto', packageDir = DEFAULT_PACKAGE_DIR, repoRoot = resolve(packageDir, '..'), bundledPath = join(packageDir, 'data.json') } = {}) {
  if (!['auto', 'source', 'bundled'].includes(mode)) throw new Error(`未知 MCP 数据模式: ${mode}`);
  const packageInfo = JSON.parse(await readFile(join(packageDir, 'package.json'), 'utf8'));
  if (packageInfo.name !== 'winutil-cn-mcp' || !/^\d+\.\d+\.\d+(?:-[\w.-]+)?$/.test(packageInfo.version)) throw new Error('MCP package.json 名称或版本无效');
  const source = mode === 'source' || (mode === 'auto' && await isSourceTree(packageDir, repoRoot));
  if (source) {
    const sourceFiles = {};
    const documents = await Promise.all(SOURCE_FILES.map(async file => {
      try {
        const bytes = await readFile(join(repoRoot, file));
        sourceFiles[file] = createHash('sha256').update(bytes).digest('hex');
        return parseConfig(bytes.toString('utf8'));
      } catch (error) { throw new Error(`无法读取 MCP 源配置 ${file}: ${error.message}`, { cause: error }); }
    }));
    documents.forEach((document, i) => rejectUnsafeKeys(document, SOURCE_FILES[i]));
    const [apps, extra, bundles, tweaks, dns] = documents;
    const metadata = { schemaVersion: DATA_SCHEMA_VERSION, packageVersion: packageInfo.version,
      ...await provenance(repoRoot), generatedAt: new Date().toISOString(), sourceFiles };
    return { source: 'source', metadata, ...validateData({ apps: mergeApps(apps, extra), bundles, tweaks, dns }) };
  }
  try {
    const data = JSON.parse((await readFile(bundledPath, 'utf8')).replace(/^\uFEFF/, ''));
    validateData(data);
    validateMetadata(data.metadata, packageInfo.version);
    return { source: 'bundled', metadata: data.metadata, apps: data.apps, bundles: data.bundles, tweaks: data.tweaks, dns: data.dns };
  } catch (error) {
    throw new Error(`无法加载 MCP 打包数据 ${bundledPath}: ${error.message}。源码检出可运行 npm run build；安装包请重新安装有效版本。`, { cause: error });
  }
}
