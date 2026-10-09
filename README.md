# WinUtil CN

Windows 11 上的软件管理与系统维护工具，提供中文界面、软件操作清单、设置历史，以及 Windows 10 / 11 安装镜像制作。

基于 [Chris Titus Tech Windows Utility](https://github.com/ChrisTitusTech/winutil)，由 [Holha1337](https://github.com/yasewang1337-svg) 汉化与维护。

<p align="center">
  <a href="https://github.com/yasewang1337-svg/winutil-cn/releases/latest"><img src="https://img.shields.io/github/v/release/yasewang1337-svg/winutil-cn?style=flat-square&amp;label=release&amp;color=16877c" alt="最新版本"></a>
  <a href="https://github.com/yasewang1337-svg/winutil-cn/actions/workflows/unittests.yaml"><img src="https://img.shields.io/github/actions/workflow/status/yasewang1337-svg/winutil-cn/unittests.yaml?branch=main&amp;style=flat-square&amp;label=tests" alt="main 分支测试状态"></a>
  <img src="https://img.shields.io/badge/Windows-11-3178c6?style=flat-square" alt="Windows 11">
  <img src="https://img.shields.io/badge/PowerShell-5.1%20%7C%207-526c91?style=flat-square" alt="PowerShell 5.1 或 7">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-526c91?style=flat-square" alt="MIT 许可证"></a>
</p>

**[下载 WinUtil-CN.exe](https://github.com/yasewang1337-svg/winutil-cn/releases/latest/download/WinUtil-CN.exe)** · [发布说明与 SHA256 校验文件](https://github.com/yasewang1337-svg/winutil-cn/releases/latest)

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#界面预览">界面预览</a> ·
  <a href="docs/content/userguide/getting-started/_index.md">使用指南</a> ·
  <a href="https://github.com/yasewang1337-svg/winutil-cn/releases/latest">更新记录</a> ·
  <a href="https://github.com/yasewang1337-svg/winutil-cn/issues/new/choose">反馈问题</a>
</p>

## 功能

| 页面 | 可以做什么 |
| :--- | :--- |
| **软件管理** | 按名称、用途或软件包 ID 搜索；预览组合、加入清单，通过 WinGet 或 Chocolatey 安装、升级、卸载。结果逐项显示，失败项可单独重试。 |
| **系统优化** | 查看基础设置、标准与高级方案，核对后执行；按历史记录恢复支持的注册表与服务启动配置。 |
| **系统配置** | 打开 Windows 管理工具，运行系统功能与维护入口。 |
| **Windows 更新** | 查看恢复、延迟与禁用三种配置的范围，调整工具涉及的更新策略。 |
| **Windows 镜像** | 从官方 Windows 10 / 11 x64 ISO 读取版本，修改后导出 ISO 或写入 U 盘。制作目标与本工具的运行环境是两回事。 |
| **清单与历史** | 导出软件与设置选择，下次导入核对；查看当前会话的软件结果和有记录的设置变更。 |

## 界面预览

![软件管理：左侧导航、用途摘要、筛选和操作清单](docs/assets/images/screenshots/software-cn.png)

名称下直接显示用途摘要；悬停在名称、勾选框或行内留白，都能读到完整介绍。右键或 `Shift + F10` 打开单项操作，安装和卸载前仍会核对范围。

<details>
<summary><b>更多页面：Windows 更新、镜像制作与首页</b></summary>

### Windows 更新

![Windows 更新：纵向排列的恢复、延迟与禁用设置](docs/assets/images/screenshots/updates-cn.png)

### Windows 镜像

![Windows 镜像：选择官方 Windows 10 或 11 ISO，读取版本后制作](docs/assets/images/screenshots/windows-iso-cn.png)

### 首页与浅色主题

![WinUtil CN 深色首页](docs/assets/images/screenshots/home-cn.png)

![WinUtil CN 浅色首页](docs/assets/images/screenshots/home-light-cn.png)

</details>

<sub>预览由本仓库的实际 WPF 界面渲染；下载版本与变更以发布页为准。镜像制作界面预览不代表已完成所有目标系统的启动与安装验证。</sub>

## 快速开始

1. **下载中文版** → [WinUtil-CN.exe](https://github.com/yasewang1337-svg/winutil-cn/releases/latest/download/WinUtil-CN.exe)，或到[发布页](https://github.com/yasewang1337-svg/winutil-cn/releases/latest)查看版本说明与 SHA256 校验文件。
2. **双击打开** → 按 Windows 提示授予管理员权限，从首页选择用途。
3. **核对后执行** → 调整软件或设置清单，查看操作范围，执行后检查每项结果。

> **使用环境**：Windows 11。EXE 内嵌本版本脚本，使用系统自带的 PowerShell 5.1，无需另装 PowerShell 7。准备包管理器、下载安装软件和更新仍需联网。

<details>
<summary><b>习惯命令行？使用 PowerShell 启动</b></summary>

从同一[发布页](https://github.com/yasewang1337-svg/winutil-cn/releases/latest)下载 `winutil-cn.ps1` 与 `SHA256SUMS.txt`，先计算哈希并核对清单：

```powershell
Get-FileHash .\winutil-cn.ps1 -Algorithm SHA256
```

核对来源、内容和哈希后，在管理员 PowerShell 中运行 `& .\winutil-cn.ps1`。执行策略或杀软拦截的处理见[安全告警说明](docs/SECURITY.md)；不要通过关闭防护或添加排除项启动。

</details>

## 使用边界

- **选择之后再执行。** 确认软件组合只加入清单；图形界面导入清单只替换勾选，不自动安装或修改系统。组合中的安装状态来自会话缓存，“尚未确认”不等于未安装。
- **恢复有范围。** 设置历史可恢复有记录的注册表值和服务启动配置；已删除应用、清理文件及脚本的其他改动不在完整恢复范围内，也不能替代个人文件备份。
- **全部升级有区别。** “查看全部升级操作”覆盖包管理器可识别的软件，只提供整批结果与日志；不提供逐软件待更新清单或软件版本回退。
- **优先使用默认 WinGet。** 如果改用 Chocolatey，请先按其官方说明完成安装；本工具不再下载并直接执行 Chocolatey 初始化脚本。自动登录与 PowerShell 配置安装入口改为打开官方指南。
- **镜像制作与宿主系统分开。** 本工具运行环境仍为 Windows 11；Windows 镜像页用于制作 Windows 10 / 11 x64 安装介质，写入 U 盘会擦除所选磁盘。步骤见[镜像制作指南](docs/content/userguide/win11Creator/_index.md)。

具体步骤和边界见[中文上手指南](docs/content/userguide/getting-started/_index.md)。

## 文档导航

| 我想…… | 从这里开始 |
| :--- | :--- |
| 第一次使用，了解每步怎么做 | [快速上手](docs/content/userguide/getting-started/_index.md) · [软件组合推荐](docs/content/userguide/recommendations/_index.md) |
| 查找设置、修复和更新功能 | [用户指南](docs/content/userguide/_index.md) · [常见问题](docs/content/faq.md) · [已知问题](docs/content/KnownIssues.md) |
| 调整 Windows 更新、制作安装介质 | [Windows 更新](docs/content/userguide/updates/_index.md) · [Windows 10 / 11 镜像](docs/content/userguide/win11Creator/_index.md) |
| 通过 AI 客户端查询或操作 | [MCP 服务器](mcp/README.md) |
| 修改翻译、参与开发 | [汉化层说明](汉化/README.md) · [架构与设计](docs/content/dev/architecture.md) · [贡献指南](.github/CONTRIBUTING.md) |
| 了解构建方式与上游同步 | [EXE 启动器](tools/launcher/README.md) · [维护说明](docs/MAINTENANCE.md) · [2026-10 更新调查](docs/UPDATE-AUDIT-2026-10.md) · [上游同步进度 #5](https://github.com/yasewang1337-svg/winutil-cn/issues/5) |

## 遇到问题

出现杀毒告警或“Windows 已保护你的电脑”时，先按[安全告警说明](docs/SECURITY.md)区分检测类型、核对文件哈希并保留告警记录。开源、数字签名或单次扫描通过都不能保证没有问题。

先查看软件结果窗口中的原因，通过 **打开日志文件夹** 获取详细记录，再到[本项目 Issues](https://github.com/yasewang1337-svg/winutil-cn/issues/new/choose)反馈。请附上 **项目版本、Windows 版本、启动方式、复现步骤和相关错误段落**。

<details>
<summary><b>展开查看日志位置</b></summary>

| 内容 | 默认位置 |
| :--- | :--- |
| 软件任务结果与日志 | `%LOCALAPPDATA%\WinUtil-CN\Logs\Packages` |
| 系统设置历史 | `%LOCALAPPDATA%\WinUtil\TweakHistory` |
| 一般运行日志 | `%LOCALAPPDATA%\winutil\logs` |
| 启动错误 | `%TEMP%\winutil-cn-error.log` |

</details>

## 开发与自动化

<details>
<summary><b>从源码构建中文版</b></summary>

```powershell
git clone https://github.com/yasewang1337-svg/winutil-cn.git
cd winutil-cn
pwsh -File 汉化\run-all.ps1
pwsh -File tools\Test-Build.ps1
powershell -NoProfile -File tools\Test-Build.ps1
```

构建产物为中文版 `winutil.ps1`。完整回归测试需要 Pester 5.7.1；EXE 构建方法见[启动器说明](tools/launcher/README.md)。

翻译数据集中在汉化层，中文组合、主题和可靠性改进另行维护。同步上游时需核对配置、控件 key、功能与翻译兼容性；当前基线及迁移差异见[维护说明](docs/MAINTENANCE.md)。

</details>

<details>
<summary><b>命令行预设、配置清单与 MCP</b></summary>

图形界面选择方案只勾选项目；命令行 `-Preset` / `-Config` 是**自动执行入口**，使用前必须核对配置内容。

| 设置方案 | 当前内容 |
| :--- | :--- |
| `Minimal`（基础设置） | 减少推荐应用、增加任务栏结束任务入口 |
| `Standard`（标准） | 基础设置，加活动历史策略和更新对等传输设置 |
| `Advanced`（高级，仅图形界面） | 标准方案，加创建还原点和经典右键菜单 |

自动模式仅支持软件操作及可记录的基础注册表设置（含受支持的开关）；脚本、服务、预装应用移除（Appx）、DNS 和系统功能等复杂操作需要在图形界面核对。具体项目见 [config/preset.json](config/preset.json)。

[MCP 服务器](mcp/README.md)可供支持 MCP 的客户端查询软件、组合和系统设置。截至 2026-10-09，npm 发布仍为独立的 0.3.0，未包含桌面版 30 的工具下载安全修复；其系统修改接口还有错误反馈和恢复缺口，当前建议只使用查询工具。GitHub EXE/PS1 的更新不会自动更新 npm 包，详情见 [MCP 使用边界](mcp/README.md)。

</details>

## 致谢与许可

感谢 [Chris Titus Tech 与上游贡献者](https://github.com/ChrisTitusTech/winutil)提供 Windows Utility，感谢 [constansino/WinUtil_CN](https://github.com/constansino/WinUtil_CN) 提供借用层翻译。本项目是独立维护的中文本地化分支，沿用 [MIT 许可证](LICENSE)。中文版本的下载、构建与反馈均使用本仓库入口。
