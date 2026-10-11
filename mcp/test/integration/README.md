# Windows 实际修改与恢复验证

此目录包含会真正修改 Windows 的集成测试，仅允许在仓库的 [MCP disposable Windows integration](../../../.github/workflows/mcp-integration.yaml) 工作流中运行。三组任务分别使用 GitHub 托管的一次性 Windows 虚拟机；不连接维护者的电脑，也不使用自托管 runner。

**不要在日常电脑上设置环境标志来绕过入口限制。** 普通 `npm test` 只运行上级目录的协议和无害夹具测试，不会运行本目录的实际修改。

| 任务 | 实际验证内容 | 恢复与隔离 |
| --- | --- | --- |
| worker | 系统 PowerShell 5.1 和 PowerShell 7 分别写入 HKCU/HKLM，创建受保护备份；覆盖空/单元素数组、数值边界、默认值、权限拒绝、部分失败、服务启动类型 | 只使用随机命名的注册表键及新建且不启动的测试服务；调用生产 `-RestoreBackupId` 并独立读取原值 |
| worker 中的 MCP 流程 | 真实 stdio 预览、确认、参数不匹配拒绝；实际写入后取消，从 `get_status` 找回备份并恢复 | 使用测试目录中的专用注册表目标，执行器与 worker 为生产代码；不是对日常优化项进行系统修改 |
| dns | 创建 Windows 内置环回网卡，实际切换 IPv4/IPv6 DNS，恢复自动与原静态地址；拒绝错误网卡身份 | 只对新设备操作；每次 worker 调用后核对已有网卡 DNS 不变，最后移除测试设备 |
| tools | 通过正式 MCP CLI 切换 npm/pip/Yarn/Go 镜像、读回配置；WinGet 安装并运行 hexyl，再卸载 | 镜像使用临时配置/真实 Python venv；按返回的恢复信息运行原生恢复命令，并比对配置 SHA256。软件用原生 WinGet 卸载，MCP 不承诺通用安装回滚 |

测试会保留原始请求、worker 输出、备份和 JSON 报告，随工作流上传为 `mcp-real-worker-*`、`mcp-real-dns-*`、`mcp-real-tools-*`，保存 30 天。报告中的源码提交和 runner 镜像标识用于定位验证版本。失败或环境不支持均返回非零，不会记作通过。

PR 中相关代码更新会触发测试，合入默认分支后也可从 Actions 手动运行。测试需要托管 runner 已有管理员权限；不会请求提权、重启机器或修改执行策略。本地可以做语法检查和普通 `npm test`。

通过这些测试能证明对应 Windows runner 环境中的受控修改和恢复链路；不等同于所有桌面 Windows 版本、所有优化项或任意第三方安装程序都已验证。

2026-10-11 实测：[运行 38103578536](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/38103578536) 的三组任务全部通过，使用 Windows Server 2025 / `win25-vs2026`。PowerShell 5.1/7 的注册表类型、服务普通/延迟启动、真实权限失败后恢复，以及 DNS、包源、安装卸载和写入后取消恢复均保留原始证据。实测发现并修复了跨 PowerShell 引擎继承模块路径导致的备份/恢复加载失败。
