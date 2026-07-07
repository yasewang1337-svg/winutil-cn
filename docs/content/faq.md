---
title: 常见问题
toc: true
---

## 通用问题

### 还支持 Windows 10 吗？
不支持。Winutil 已不再支持 Windows 10，因为它已于 **2025 年 10 月 14 日**结束支持。Winutil 专注于 Windows 11。

### 怎么卸载 Winutil？
你不需要卸载 Winutil。因为它以 PowerShell 脚本的形式运行，只在打开时被加载进内存。一旦关闭，它就从内存中移除，不会在你的系统上留下安装痕迹。

### Winutil 用起来安全吗？
安全。Winutil 是开源的，代码公开在 GitHub 上，每天有成千上万的用户在使用。不过，就像任何系统修改工具一样，你应该：
- 以管理员身份运行（必需）
- 在做重大改动前创建系统还原点
- 弄清楚你正在套用的是什么优化项
- 只从[官方来源](https://github.com/ChrisTitusTech/winutil/)运行

### 我需要一直开着 Winutil 吗？
不需要。一旦你套用了优化项或安装了应用，就可以关闭 Winutil。改动在关闭后依然生效。只有当你想再做改动或撤销优化项时，才需要重新运行 Winutil。

### Winutil 需要联网吗？
- **下载软件时**：需要，安装应用需要联网
- **套用优化项时**：不需要，大多数优化项可离线工作
- **首次运行时**：需要，用于拉取最新脚本

### Winutil 多久更新一次？
Winutil 处于活跃维护中，更新频繁。新功能、Bug 修复和新增应用都会定期发布。每次运行时，脚本都会自动下载最新版本。

## 安装与运行

### 怎么运行 Winutil？
1. 以管理员身份打开 PowerShell
2. 运行：`irm "https://christitus.com/win" | iex`
3. 等待图形界面出现

### 为什么需要管理员权限？
Winutil 会进行系统级改动（注册表编辑、服务修改、软件安装），这些都需要提升权限。没有管理员权限，大多数功能都无法工作。

### 脚本下载不下来，怎么办？
按顺序尝试以下方案：

1. **使用 GitHub 直链**：
   ```powershell
   irm https://github.com/ChrisTitusTech/Winutil/releases/latest/download/Winutil.ps1 | iex
   ```

2. **强制启用 TLS 1.2**：
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   irm "https://christitus.com/win" | iex
   ```

   > [!NOTE]
   > 在 Windows 11 上，你通常不需要 TLS 1.2 那条命令。只有当你遇到下载或安全协议错误时才用它。

3. **更换 DNS** 到 Cloudflare（1.1.1.1）或 Google（8.8.8.8）

4. 如果 GitHub 在你所在地区被封锁，**使用 VPN**

### 我遇到了「Execution Policy（执行策略）」错误，怎么修？
先运行这条命令来允许脚本执行：
```powershell
Set-ExecutionPolicy Unrestricted -Scope Process -Force
irm "https://christitus.com/win" | iex
```

这只影响当前 PowerShell 会话，是安全的。

## 优化项与修改

### 我套用了一个优化项，结果某个功能坏了，怎么办？
如果你套用某个优化项后弄坏了某样东西，可以把它撤销：
1. 再次打开 Winutil
2. 进入 **Tweaks（优化）** 标签页
3. 选中你之前套用的同一个优化项
4. 点击 **Undo Selected Tweaks（撤销所选优化项）**
5. 系统会恢复到之前的状态

或者，如果你之前创建过系统还原点，也可以用「系统还原」。

### 哪些优化项套用起来是安全的？
**人人适用（基础优化项 Essential Tweaks）**：
- 禁用遥测（Telemetry）
- 禁用活动历史记录（Activity History）
- 禁用位置追踪（Location Tracking）
- 删除临时文件
- 运行磁盘清理
- 创建系统还原点

**高级优化项（Advanced Tweaks）** 只应由高级用户运行。

### 优化项能在 Windows 更新后依然生效吗？
大多数优化项能挺过更新，但有些可能会被 Windows 的重大功能更新重置。之后你可能需要重新套用某些优化项。

### 我能创建自己的优化项预设吗？
目前，Winutil 使用预定义的预设（Standard、Minimal）。图形界面暂不直接支持自定义预设，但你可以用脚本来实现你偏好的配置。

### 基础优化项和高级优化项有什么区别？
- **基础优化项（Essential Tweaks）**：对大多数用户安全，以极小的风险改善性能/隐私
- **高级优化项（Advanced Tweaks）**：更激进的改动，可能破坏功能或兼容性。请谨慎使用。

## 应用安装

### Winutil 是怎么安装应用的？
Winutil 使用 Windows 包管理器（WinGet）和 Chocolatey 来自动化安装。它从官方来源下载应用，并静默安装，不带任何捆绑软件。

### 我能一次安装多个应用吗？
可以！勾选你想要的所有应用，然后点击「Install Selected（安装所选）」。它们会依次安装。

### WinGet 不工作，怎么修？
1. 进入 **Config（配置）** 标签页
2. 找到 **Fixes（修复）** 区域
3. 点击 **WinGet Reinstall（重装 WinGet）**
4. 等待完成
5. 再次尝试安装应用

### 安装的应用里有捆绑软件或广告软件吗？
没有。WinGet 和 Chocolatey 安装的是应用的纯净版本，不带任何捆绑推广、工具栏或广告软件。

### 我能通过 Winutil 卸载应用吗？
Winutil 主要专注于安装和管理应用，并没有提供一个能卸载每个程序的完整图形界面。要移除应用，你可以：
- 用 Windows 设置 > 应用 > 已安装的应用 来卸载程序。
- 在 PowerShell 里用包管理器命令（例如 `winget uninstall <package>` 或 `choco uninstall <package>`）。
- 由 Winutil 安装的部分包（AppX/MSIX）自带移除助手；查看对应应用条目，或在可用时使用 Winutil 的移除助手。

### 安装的应用会自动更新吗？
自带更新机制的应用会自动更新。你也可以通过 WinGet/Chocolatey 命令，或通过 Winutil 的「Upgrade Selected（升级所选）」功能来更新它们。

## 更新与维护

### 我应该禁用 Windows 更新吗？
一般来说，**不应该**。安全更新很重要。不过，你可以：
- 使用「仅安全更新」来避开功能更新
- 为求稳定，临时暂停更新
- 仅在关键工作期间禁用

### 禁用更新后，怎么重新启用？
1. 打开 Winutil
2. 进入 **Updates（更新）** 标签页
3. 点击 **Default Updates（默认更新）**
4. 更新将恢复正常

### 「仅安全更新」和「禁用更新」有什么区别？
- **仅安全更新（Security Updates Only）**：安装关键安全补丁，屏蔽功能更新（大版本）
- **禁用更新（Disable Updates）**：屏蔽所有更新，包括安全更新（不推荐）

## 故障排查

### 运行命令后 Winutil 打不开
可能的原因：
1. **杀毒软件拦截**：为 PowerShell 添加例外
2. **没以管理员身份运行**：以管理员身份重新打开 PowerShell
3. **下载损坏**：关闭 PowerShell，重新打开，再试一次
4. **Windows Defender**：放行该脚本

### 我的杀毒软件把 Winutil 标记为恶意
这是误报。Winutil 会进行系统改动，杀毒程序可能因此将其标记。代码是开源且经过审计的。如有需要，添加一个例外即可。

### 某个应用安装失败
故障排查步骤：
1. 检查你的网络连接
2. 试着只安装那一个应用
3. 查看输出面板里的错误信息
4. 检查是不是杀毒软件在拦截
5. 试试 WinGet Reinstall（重装 WinGet）修复

### 网络优化项把我的网络连接搞坏了
1. 打开 Winutil
2. 进入 **Config（配置）** > **Fixes（修复）**
3. 点击 **Reset Network（重置网络）**
4. 重启电脑
5. 连接应当恢复

### 套用优化项后，我访问不了某些 Windows 功能
撤销可能影响到这些功能的优化项：
1. 重新打开 Winutil
2. 选中你之前套用的优化项
3. 点击 **Undo Selected Tweaks（撤销所选优化项）**

如果这样还不行，就用「系统还原」回退到之前的状态。

## 进阶话题

### 我能在 Windows Server 上运行 Winutil 吗？
可以，Winutil 能在 Windows Server 版本上运行，不过某些功能可能不适用，或表现有所不同。

### Winutil 支持 Windows LTSC 吗？
支持，Winutil 能在 Windows 10/11 LTSC 版本上运行。取决于你的配置，某些应用可能不可用。

### 我能在企业/公司环境里用 Winutil 吗？
可以，但请先查看你所在组织的策略。某些优化项可能与组策略（Group Policy）或其他公司要求冲突。

### 怎么给多台电脑批量自动化运行 Winutil？
详见[自动化指南](/userguide/automation/)，其中介绍了：
- 配置文件
- PowerShell 参数
- 批量部署
- 静默安装

### 我能为 Winutil 做贡献吗？
当然！欢迎贡献：
- 在 GitHub Issues 上报告 Bug
- 提交修复/功能的 Pull Request
- 改进文档
- 在 Discord 上帮助他人

详见[贡献指南](/contributing/)。

## 隐私与安全

### Winutil 会收集任何数据吗？
不会，Winutil 本身不收集或传输任何用户数据。它是一个本地运行的 PowerShell 脚本。

### 「禁用遥测」优化项屏蔽了哪些遥测？
它会禁用：
- Windows 诊断数据收集
- 活动历史记录追踪
- 反馈请求
- 使用统计
- 错误报告（可选）

### 移除 Microsoft Store 会影响安全更新吗？
不会，Windows 安全更新与 Microsoft Store 相互独立。

## 性能

### Winutil 能让我的电脑变快吗？
优化项可以通过以下方式改善性能：
- 减少后台进程
- 禁用不必要的服务
- 清理临时文件
- 优化开机启动项

具体效果因系统而异。

### 打游戏用哪个预设最好？
使用 **Desktop（桌面）** 预设，然后额外套用：
- 禁用 GameDVR
- 卓越性能（Ultimate Performance）电源计划
- 禁用全屏优化（高级）
- 将显示设置为性能优先（高级）

### Winutil 占用多少内存？
Winutil 运行时本身占用约 50-100 MB 内存。一旦关闭，就会从内存中移除。

## 错误信息

### 「Access Denied（拒绝访问）」错误
- 确认 PowerShell 是以管理员身份运行的
- 检查是不是杀毒软件在拦截改动
- 确认你对相关文件/注册表项拥有所有权

## 还是需要帮助？

找不到你要的答案？试试这些资源：

- **[已知问题](/knownissues/)** —— 看看是不是已知的问题
- **[用户指南](/userguide/)** —— 完整文档
- **[Discord 社区](https://discord.gg/RUbZUZyByQ)** —— 从其他用户那里获得帮助
- **[GitHub Issues](https://github.com/ChrisTitusTech/winutil/issues)** —— 报告 Bug
- **[YouTube 教程](https://www.youtube.com/watch?v=6UQZ5oQg8XA)** —— 视频讲解
