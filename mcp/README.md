# WinUtil CN MCP

让支持 MCP 的客户端查询软件、组合、系统设置与 DNS，并按明确选择执行受支持的操作。**0.4.1 默认只读**，不会注册安装、换源或系统修改工具。它是独立的 Node.js 包，不会控制已打开的 WinUtil 窗口，桌面版更新也不会自动更新 npm 包。

**分发方式：** [MCP 0.4.1 GitHub 安装包](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/mcp-v0.4.1)提供安装包、SHA256 和源码证据。npm 发布认证尚待处理，registry 仍为 0.3.0；下方使用固定版本的 GitHub 包地址。暂不要使用 `winutil-cn-mcp@0.4.1` 从 npm 安装。

需要 Node.js 22 或 24 LTS。查询可跨平台使用；修改功能仅支持 Windows，并遵循当前用户权限和 PowerShell 执行策略，不自动提权或绕过策略。

## 接入

通用 MCP 客户端配置：

```json
{
  "mcpServers": {
    "winutil-cn": {
      "command": "npx",
      "args": ["-y", "https://github.com/yasewang1337-svg/winutil-cn/releases/download/mcp-v0.4.1/winutil-cn-mcp-0.4.1.tgz"]
    }
  }
}
```

Claude Code 也可注册：

```bash
claude mcp add winutil-cn -- npx -y https://github.com/yasewang1337-svg/winutil-cn/releases/download/mcp-v0.4.1/winutil-cn-mcp-0.4.1.tgz
```

如果客户端在 Windows 无法启动 `npx`，使用 Node 的绝对路径运行本地源码入口：

```powershell
git clone https://github.com/yasewang1337-svg/winutil-cn.git
cd winutil-cn/mcp
npm ci --ignore-scripts
```

```json
{
  "mcpServers": {
    "winutil-cn": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": ["W:\\winutil-cn\\mcp\\index.js"]
    }
  }
}
```

路径按实际安装位置填写。重启/重新连接服务器后调用 `get_status`，确认版本、模式、数据来源和源码提交。首次使用 `npx` 需联网取得包与依赖；包安装完成后的目录查询无需联网，软件安装和工具访问仍可能联网。

## 查询工具

| 工具 | 内容 |
|---|---|
| `get_status` | 包版本、运行模式、数据来源/生成信息、目录数量、忙状态和最近一次执行结果 |
| `search_apps` | 软件 key、名称、用途、分类与 winget ID；按关键词查找，支持分页 |
| `list_bundles` | 组合候选、`defaultApps` 默认推荐与 `purposes` 用途；不会把整个组合当成必装清单 |
| `list_tweaks` | 优化项目录和 `execution.supported` 执行边界、不支持原因 |
| `list_dns` | DNS 地址及 Default 恢复默认选项 |

软件与优化查询接受 `query`、`limit`（1–100，默认 20）、`offset`；返回 `total`、`hasMore`。当前目录含 213 条软件、10 个组合、66 项优化和 12 个 DNS 提供商，其中 16 项声明式优化支持 MCP 执行；其余项目会返回具体的不支持原因。实际支持数量可从 `get_status` 查看。

示例：让客户端“查询日常办公软件，说明推荐用途和可选项，只查询不安装”。

## 显式启用修改

确实需要修改时，在服务器启动参数末尾加入 `--allow-write`，例如：

```json
{
  "command": "npx",
  "args": ["-y", "https://github.com/yasewang1337-svg/winutil-cn/releases/download/mcp-v0.4.1/winutil-cn-mcp-0.4.1.tgz", "--allow-write"]
}
```

这会额外注册 `list_network_adapters` 和下面四个修改工具。客户端仍应保留逐次审批。**planId 证明调用与预览一致，不能代替向用户核对操作。** 不建议为了权限错误把整个 AI 客户端以管理员运行。

| 工具 | 预览参数 | 执行与恢复范围 |
|---|---|---|
| `install_apps` | `ids`：软件 key、WPFInstall key 或 winget ID | 检查工具后逐项安装，保留退出码与输出；安装器效果不能自动回滚，可通过 Windows 已安装应用卸载 |
| `switch_mirror` | `tool`：pip/npm/yarn/go；`action`：cn/official | 先读当前配置再切换，返回原值；Yarn 仅支持 Classic 1.x |
| `apply_tweaks` | `keys`：优化项 key | 仅支持受控注册表/服务启动类型修改；修改前备份原值。含脚本或其他不支持动作时，整份计划拒绝执行 |
| `set_dns` | `provider`、`adapterIds` | 先用 `list_network_adapters` 取得网卡 GUID，再明确选择；执行前复核身份，只改选中网卡，保存原 DNS 配置 |

例如，先请求预览：

```json
{"ids":["Git.Git"]}
```

核对返回的 `plan` 后，才用 **相同工具、相同参数** 确认：

```json
{"ids":["Git.Git"],"confirm":true,"planId":"这里填写刚返回的计划ID"}
```

确认计划仅在当前服务器连接中有效，五分钟过期，使用一次后失效。更改软件、优化项或网卡必须重新预览。同一服务器一次只运行一个修改任务；忙时拒绝第二项执行。客户端取消后，执行器会停止后续项目，区分已确认完成和无法确认的范围；取消不等于回滚，也不能保证第三方安装器派生进程立即退出。

客户端可能不再接收被取消请求的返回值。此时调用 `get_status`，待 `execution.busy` 为 `false` 后读取 `execution.lastResult`，取得完成情况与恢复编号。它仅保留当前连接最近一次执行结果，服务器退出后不保留；受控系统备份另存在 `%ProgramData%\WinUtil-CN-MCP`。

## 结果、错误与恢复

- 执行结果区分 `completed`、`partial`、`failed` 和取消，保留逐项结果、退出码及错误输出。失败、部分完成和不支持计划会设置 MCP `isError`。
- 注册表/服务/DNS 修改前会保存受控备份，并在结果中给出 `backupId`。需要恢复时，在具备相应权限的本地终端运行包内静态 worker：

```powershell
powershell.exe -NoProfile -File "W:\winutil-cn\mcp\powershell\worker.ps1" -RestoreBackupId "结果中的备份GUID"
```

- 恢复入口只接受备份 ID，不接受任意备份文件路径；只恢复本次受支持的值、服务启动类型和 DNS。系统后续已被其他程序修改时，请先核对是否仍要恢复旧状态。备份不包含第三方安装、删除文件或任意优化脚本的效果。
- 中断结果的 `results` 只列出已确认项目；`pending` 和 `outcomeKnown:false` 表示尚无法确定最终状态。`backupStatus:unconfirmed` 表示尚未确认备份创建成功，不能把编号存在当成备份可用，也不要自动重试修改。
- 换源结果保留修改前的值，可用相应工具自身的配置命令恢复。不要把返回的值直接拼成 shell 命令。
- 权限不足、策略阻止、缺少工具或网卡身份变化会明确失败。不要把失败当成已完成，也不要关闭防护来消除错误。

旧 0.3.0 的任意 `InvokeScript` 执行路径已经移除。需要 ViVeTool、卸载组件或其他复杂脚本的优化项仍可查询，但 MCP 会标明不支持并指引使用桌面版，不会下载并执行旧包中的未校验代码。

## 数据与离线打包

源码目录默认读当前仓库配置，不会被旧 `data.json` 覆盖；npm 安装环境读包内快照。可用 `--data-mode source` 或 `--data-mode bundled` 明确指定；缺失/损坏会停止并报错，不会静默回落到 GitHub raw 执行另一版配置。

快照包含 schema、包版本、源码提交、生成时间和来源文件哈希。查询 `get_status` 可查看溯源；工作区有未提交改动会标记，不伪称干净发布提交。构建产物 `data.json` 不入库。

每次连接使用启动时读取的目录快照。修改源码配置后需重启服务器，已预览的计划不会偷偷换成新配置；重启也会使旧计划失效。

```bash
npm ci --ignore-scripts
npm test
npm run test:pack
npm pack
```

`prepack` 自动生成数据；离线包测试把实际 tarball 放入无源码目录，禁止运行时网络及系统子进程，再验证协议查询。发布工作流先运行 Windows Node 22/24 与 Linux Node 24 专项测试及一次性 Windows 实际修改测试，再构建、验证同一份包，附 SHA256 和源码版本证据。版本来自 package.json，标签和 lock 必须一致。默认只生成安装包，npm 上传需维护者手动明确启用。

普通测试覆盖真实 MCP 握手、查询、预览、一次性确认、拒绝错误输入、失败与并发路径，以及执行器/PowerShell 无害夹具。另有[实际修改与恢复测试](test/integration/README.md)：在 GitHub 托管的一次性 Windows 测试机上执行注册表/服务、独立环回网卡 DNS、包源及软件安装卸载，并核对恢复结果；禁止在日常电脑运行。这些结果不代表所有桌面 Windows 版本、全部优化项或任意第三方安装程序都已验收。

[版本变更](https://github.com/yasewang1337-svg/winutil-cn/blob/main/mcp/CHANGELOG.md) · [项目主页](https://github.com/yasewang1337-svg/winutil-cn) · MIT
