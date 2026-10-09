# WinUtil-CN MCP 服务器

供支持 MCP 的客户端查询软件、装机组合、系统设置和 DNS 方案。MCP 是独立的 Node.js 包，拥有自己的执行逻辑和发布流程；桌面版 EXE/PS1 的修复不会自动应用到 npm 包。

## 当前使用边界（2026-10-09）

npm 最新发布仍为 **0.3.0**，其内置快照包含旧版未校验的 ViVeTool 下载执行代码，未包含桌面版 30 的安全修复。仓库当前 MCP 执行层也尚未接入桌面版的设置历史、下载校验函数和逐项错误处理，存在失败仍报告完成等缺口。

目前建议只使用 `search_apps`、`list_bundles`、`list_tweaks`、`list_dns` 四个查询工具，无需管理员权限。**这是使用建议，现有版本仍暴露修改接口，并未在代码中强制禁用。** 客户端若支持工具白名单，应只启用这四项；注册服务器本身不会自动限制工具。

待完成的修复和包验收见 [2026-10 更新调查](../docs/UPDATE-AUDIT-2026-10.md)。本轮没有发布新的 npm 包，也没有对旧包执行弃用操作。

## 它能干什么

| 工具 | 作用 |
|---|---|
| `search_apps` | 在 213 条软件库（含微信/QQ/WPS 等国货）里按关键词搜，返回 winget ID |
| `list_bundles` | 列出策展的一键装机组合（国内办公/国际开发/影音…） |
| `install_apps` | 用 winget 静默安装（传 winget ID 或组合里的 app key） |
| `switch_mirror` | pip/npm/yarn/go 在国内镜像与官方源之间一键切换 |
| `list_tweaks` | 查询系统优化项（禁用遥测/瘦身/隐私/性能，66 项） |
| `apply_tweaks` | 应用优化项（注册表 + 服务 + 内置脚本）⚠️ 改系统，需管理员 |
| `list_dns` | 列出 DNS 方案（国际 Cloudflare/Google… + 国内 阿里/DNSPod/114/百度） |
| `set_dns` | 把已连接网卡的 DNS 设为指定提供商 ⚠️ 改系统，需管理员 |

> 当前不建议使用系统修改接口，也不要以管理员身份启动整个 AI 客户端来绕过权限错误。
>
> `install_apps`、`apply_tweaks`、`set_dns` 默认返回预览，`confirm: true` 才执行；该参数不能代替客户端向用户核对操作。`switch_mirror` 当前立即改源，没有确认参数，查询场景应禁用它。

**用法示例**（对 Claude 说）：
> 「查询适合日常办公的软件候选，并列出用途；只查询，不安装、不修改系统。」

## 安装

建议使用仍受支持的 [Node.js LTS](https://nodejs.org/en/about/previous-releases)。现有包的最低版本声明和发布工作流尚待更新，不应把旧的 Node 18/20 当作新环境的推荐版本。

```bash
git clone https://github.com/yasewang1337-svg/winutil-cn.git
cd winutil-cn/mcp
npm ci --ignore-scripts
```

## 接入 Claude Code

npm 上的 0.3.0 可通过以下命令注册，但注册后仍须在客户端限制为上述四个查询工具。包内快照可离线读取，不代表安装和换源操作能离线完成：

```bash
claude mcp add winutil-cn -- npx -y winutil-cn-mcp
```

或从本仓库运行：

```bash
claude mcp add winutil-cn -- node "绝对路径/winutil-cn/mcp/index.js"
```

或手动加进项目的 `.mcp.json`：

```json
{
  "mcpServers": {
    "winutil-cn": { "command": "node", "args": ["绝对路径/winutil-cn/mcp/index.js"] }
  }
}
```

## 接入 Claude Desktop

编辑 `%APPDATA%\Claude\claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "winutil-cn": { "command": "node", "args": ["绝对路径\\winutil-cn\\mcp\\index.js"] }
  }
}
```

重启 Claude Desktop 后即可用。

## 说明

- 数据加载顺序为包内 `data.json`、仓库源文件、GitHub raw 回退。源码目录中保留旧快照时，也会优先读取快照，并非始终读取最新配置。
- 数据主要来自 `config/applications.json`、`汉化/extra-apps.json`、`config/bundles.json`、`config/tweaks.json` 和 DNS 配置。0.3.0 快照不含后续组合的默认推荐字段。
- `apply_tweaks` 和 `set_dns` 已存在，但尚未达到桌面版的错误反馈与恢复能力。未来发布前需补充协议、打包内容、失败路径和修改接口的隔离测试；仅重新生成快照不能视为完成安全更新。

MIT · Holha1337
