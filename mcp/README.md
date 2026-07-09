# WinUtil-CN MCP 服务器

让 **AI 智能体（Claude 等）按意图驱动 WinUtil 中文汉化版**——你说需求，AI 帮你搜软件、装软件、套用组合、换源。这是 winutil-cn 的「AI 原生配置层」，也是它区别于普通汉化版的护城河。

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

> ⚠️ `apply_tweaks` / `set_dns` / 部分 `install_apps` 会修改系统，需管理员权限——在**管理员终端**里启动 Claude / MCP 宿主。

**用法示例**（对 Claude 说）：
> 「帮我把这台机器配成国内开发环境」→ AI 调 `list_bundles` 找到「国际·开发环境」+ 国货，`install_apps` 装 VSCode/Git/Node/Python/微信/WPS，再 `switch_mirror` 把 pip/npm 换国内源。

## 安装

需要 [Node.js](https://nodejs.org) 18+。

```bash
git clone https://github.com/yasewang1337-svg/winutil-cn.git
cd winutil-cn/mcp
npm install
```

## 接入 Claude Code

发布到 npm 后，一行接入（无需 clone，数据已打包进包内，离线可用）：

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

- 软件数据来自本仓库 `config/applications.json` + `汉化/extra-apps.json`（国货）+ `config/bundles.json`；本地读不到时自动回落 GitHub raw。
- `install_apps` / `switch_mirror` 会真实执行 winget / 换源命令；部分软件安装需管理员权限（在管理员终端启动 Claude / MCP 宿主）。
- 优化项（tweaks）、DNS 的意图应用在路线图上，后续加入。

MIT · Holha1337
