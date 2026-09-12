# WinUtil-CN 维护状态

更新：2026-09-12

## 目标与范围

用户要求优化项目并处理 GitHub 待办。工作区原为空，已克隆官方中文仓库；基线 main 为 `7ca2ed8`，维护分支为 `maintenance/reliability-20260912`。

本轮优先：启动注册表读取故障（Issue #6）、构建与测试门禁、中文反馈入口和依赖维护。完整上游迁移需单独验证，不把选择性修复描述为同步完成。

## 已确认

- 已发布版本 `cn-2026.07.10-26` 的第 637 行在 `Get-WinUtilToggleStatus`：读取整个注册表键，可受无关损坏值影响，且查询时创建缺失键。
- 编译脚本未检查 PowerShell 语法；汉化构建吞掉读取错误；函数测试在 Discovery 阶段枚举 BeforeAll 才赋值的变量；CI 没有用失败退出码阻止发布。
- GitHub 待办：Issues #5（上游同步）、#6（启动错误）；PR #1 checkout v7、#2 cache v6、#4 setup-node v7。
- 上游最新稳定版 `26.08.19`，相对共同祖先 `58a81b1` 涉及 170 个提交、362 个文件，包含 UI/配置/文档体系变化。已拉取为 `upstream/release-26.08.19` 供比较。
- 用户已明确批准 GitHub CLI 完整权限并在 Chrome 完成官方设备授权；CLI 当前为仓库所有者账号，维护权限已核对。凭据由系统 keyring 保存，不在仓库内。

## 已实现与已验证

- 修复只读开关探测、异常降级与详细日志、中文提权入口及路径转义。
- 编译基于脚本目录、明确 UTF-8 BOM、校验 JSON/XML/PowerShell 后原子替换；错误不再吞掉。
- 62 条运行时翻译路径改为相对路径，修复跨电脑构建静默跳过问题。
- 修复测试发现与配置检查，补构建失败/注册表/汉化/XAML 回归；CI 同时测试 PS 5.1/7，并作为发布前置。
- 已在本地合并 PR #1、#2、#4 的原始提交；更新中文反馈模板、CODEOWNERS、维护者指令权限、发布扫描状态与 SHA256 清单。
- 2026-09-12：PowerShell 7.6.5 和 Windows PowerShell 5.1.26100.9444 各 94 项测试全通过，零跳过。日志位于 `.artifacts/tests-pwsh.log`、`.artifacts/tests-powershell.log`。
- 全汉化构建与双版本产物语法/BOM 校验通过；actionlint 全工作流通过；MCP 快照生成成功（213 软件 / 10 组合 / 66 优化项 / 12 DNS）。
- 实际 Windows 上只读检查 23 个开关成功（204 ms）。未执行系统优化或安装软件。
- EXE 使用隔离的 .NET SDK 8.0.425 编译，0 警告 / 0 错误；嵌入脚本 SHA256 与构建的 PS1 完全一致。根目录 `winutil-cn.ps1` 和 `WinUtil-CN.exe` 可交付；校验和见 `.artifacts/SHA256SUMS.txt`。

## 待交付

1. 本地实现提交 `fdfa4cf`；推送维护分支、创建并核对 PR 的远端 CI，通过后合并；核验 3 个依赖 PR 状态与新发布。
2. Issue #6 说明故障链与版本，待原报告环境确认；Issue #5 保留开放，说明上游迁移范围（`docs/MAINTENANCE.md`）。

验证时只调用构建和隔离测试，不运行系统优化、软件安装或系统设置操作。
