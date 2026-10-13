---
title: MCP 接入指南
description: 安装 winutil-cn-mcp，连接支持 MCP 的客户端，默认只读查询软件、装机组合与系统设置；了解写操作确认、执行结果和恢复范围。
weight: 3
toc: true
---

WinUtil CN MCP 是独立的 Node.js 包，让支持 MCP 的 AI 客户端查询软件、装机组合、系统设置和 DNS。**默认只读**，不会注册安装、换源或系统修改工具，也不会控制已打开的 WinUtil 桌面窗口。

[npm 包](https://www.npmjs.com/package/winutil-cn-mcp) · [版本记录](https://github.com/yasewang1337-svg/winutil-cn/blob/main/mcp/CHANGELOG.md) · [完整技术说明](https://github.com/yasewang1337-svg/winutil-cn/blob/main/mcp/README.md)

## 先准备什么

- Node.js 22 或 24 LTS，以及支持通过标准输入输出连接 MCP 的客户端。
- 首次通过 `npx` 安装需要联网；安装完成后，包内目录查询无需联网。
- 查询可跨平台使用，修改只支持 Windows，并遵循当前用户权限与 PowerShell 执行策略。

本页配置固定使用 **0.4.2**，便于确认实际版本。桌面版和 MCP 分别发布，更新其中一个不会自动更新另一个。

## 接入并确认状态

在客户端的 MCP 配置中添加：

```json
{
  "mcpServers": {
    "winutil-cn": {
      "command": "npx",
      "args": ["-y", "winutil-cn-mcp@0.4.2"]
    }
  }
}
```

不同客户端的配置文件位置和外层字段可能不同，按客户端提供的 MCP 配置入口填写。Claude Code 可通过以下命令注册：

```bash
claude mcp add winutil-cn -- npx -y winutil-cn-mcp@0.4.2
```

重新连接后，先让客户端调用 `get_status`，核对版本、只读模式、数据来源和源码提交，再尝试：

> 查询日常办公软件，说明推荐用途和可选项，只查询不安装。

| 查询工具 | 用途 |
| --- | --- |
| `get_status` | 查看版本、模式、目录来源、忙状态和本连接最近一次执行结果 |
| `search_apps` | 按软件名称、用途或 ID 查找，支持分页 |
| `list_bundles` | 查看装机组合、推荐用途和默认候选，不把整组当成必装清单 |
| `list_tweaks` | 查询设置说明、是否支持 MCP 执行及不支持的原因 |
| `list_dns` | 查询 DNS 提供商和恢复默认的选项 |

包内软件目录不是本机已安装软件列表。目录数量和支持范围以 `get_status` 及查询结果为准。

## Windows 客户端无法启动 npx

可把包安装到自己选定的持久目录，用 Node 的绝对路径启动。以下命令只在当前目录安装包，不需要克隆源码，也不做全局安装：

```powershell
npm install --prefix .\winutil-cn-mcp-local --save-exact --ignore-scripts winutil-cn-mcp@0.4.2
(Resolve-Path .\winutil-cn-mcp-local\node_modules\winutil-cn-mcp\index.js).Path.Replace('\', '/')
```

然后按实际路径填写；下面是需要替换路径的配置模板：

```json
{
  "mcpServers": {
    "winutil-cn": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": ["C:/替换为实际目录/winutil-cn-mcp-local/node_modules/winutil-cn-mcp/index.js"]
    }
  }
}
```

`args` 使用上一步输出的完整路径，`command` 使用本机 Node 的真实路径。保留安装目录，以便以后定位恢复脚本。

## 确实需要修改时

在启动参数末尾增加 `--allow-write` 才会额外启用受控操作：

```json
{
  "command": "npx",
  "args": ["-y", "winutil-cn-mcp@0.4.2", "--allow-write"]
}
```

客户端仍应逐次向用户确认。开启写模式不会自动修改系统，也不会自动提权。

| 操作 | 执行边界 |
| --- | --- |
| `install_apps` | 逐项安装所选软件，保留退出码与输出；不自动回滚第三方安装器效果 |
| `switch_mirror` | 切换支持的 pip、npm、Yarn Classic 1.x 或 Go 来源，先读取并返回原值 |
| `apply_tweaks` | 只执行支持的声明式注册表及服务启动配置变更；含不支持动作的计划整份拒绝 |
| `set_dns` | 先查询网卡，再明确选择 GUID；复核身份后仅修改选中网卡 |

写操作先生成预览，核对后使用**同一工具、同一参数**，带 `confirm: true` 和返回的 `planId` 执行。计划只在当前连接有效，五分钟过期且只能使用一次。`planId` 校验请求与预览一致，不能代替用户同意。

同一连接同时只运行一个修改任务。取消会停止后续项目，但不等于回滚，第三方安装器也可能仍在完成操作。无法确认的结果会标记 `pending` 或 `outcomeKnown: false`，不应直接自动重试。

## 查看结果与恢复

执行结果区分完成、部分完成、失败和取消。请求取消后若客户端没有收到结果，可调用 `get_status`，在 `execution.busy` 为 `false` 后查看 `execution.lastResult`。此结果只保留到当前服务器连接结束。

受支持的注册表、服务启动配置与 DNS 修改会在 `%ProgramData%\WinUtil-CN-MCP` 保存受控备份，结果给出 `backupId`。`backupStatus: unconfirmed` 表示备份尚未确认，不可只凭编号就视为可恢复。

需要恢复时，使用上面的持久安装方式定位 worker。回到包含 `winutil-cn-mcp-local` 的目录，在具备相应权限的本地终端操作：

```powershell
$packageDirectory = (Resolve-Path .\winutil-cn-mcp-local\node_modules\winutil-cn-mcp).Path
$worker = Join-Path $packageDirectory 'powershell\worker.ps1'
powershell.exe -NoProfile -File $worker -RestoreBackupId "结果中的备份GUID"
```

前两行只定位文件；最后一行才执行恢复。只用过 `npx` 的用户可以先按上文安装到持久目录，无需寻找临时缓存。恢复只接受备份 ID，不接受任意文件路径；系统后来已有其他修改时，先确认是否仍需恢复原值。

第三方安装、删除的文件、任意优化脚本和服务当时的运行状态不在完整恢复范围。换源操作返回原值，可通过相应工具自身的配置命令恢复；不要把返回内容直接拼入 shell 命令。

## 更新与排错

升级时修改客户端配置中的固定版本，重新连接并用 `get_status` 确认。GitHub 安装包作为另一入口，可用对应版本的 `.tgz` URL；切换前核对版本、校验和及[发布记录](https://github.com/yasewang1337-svg/winutil-cn/releases)。

权限不足、策略拦截、缺少工具或网卡身份变化会明确失败。不建议为解决单项权限错误把整个 AI 客户端以管理员运行，也不要通过关闭防护或降低策略规避失败。

需要反馈时，提供包版本、客户端名称、Node 版本、`get_status` 和相关错误；先删去私人路径及无关信息，再提交到[本项目 Issues](https://github.com/yasewang1337-svg/winutil-cn/issues)。实际修改与恢复的自动化测试在一次性 GitHub Windows 测试机进行，不能视作所有桌面环境均已验收。
