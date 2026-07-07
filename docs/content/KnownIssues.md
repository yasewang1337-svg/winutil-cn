---
title: 已知问题
toc: true
---

### 下载不成功

如果你运行 WinUtil 时遇到类似这样的报错：

`< : The term '<' is not recognized as the name of a cmdlet, function, script file, or operable program.`

请尝试使用 **VPN**；如果还是不行，就把问题反馈到 https://github.com/ChrisTitusTech/winutil/issues

### 脚本无法运行

如果你运行 WinUtil 时遇到这个报错：

`"WinUtil is unable to run on your system. PowerShell execution is restricted by security policies"`

这说明你的 PowerShell 会话处于**受限语言模式（Constrained Language Mode）**，它会阻止 WinUtil 运行。

### 卓越性能电源计划不生效

「卓越性能（Ultimate Performance）」电源计划在某些不完全支持它的笔记本上可能无法生效。

这种情况下电源计划会套用失败，这是不受支持硬件上的正常表现。

### 恢复旧版开始菜单的优化项失效

从 **Windows 11 更新 KB5089573**（2026 年 5 月发布）开始，恢复旧版开始菜单的优化项不再起作用。

在这次更新中，微软已经把旧版开始菜单的代码从 Windows 里彻底移除，所以我们没办法再把它找回来。
