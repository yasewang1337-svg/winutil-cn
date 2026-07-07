---
title: 自动化
weight: 7
prev: /userguide/updates/
next: /userguide/win11creator/
---

用「自动化（Automation）」功能，你可以基于一份导出的配置文件来运行 Winutil。

Winutil 支持预定义的预设，可自动套用常见配置：

- `Standard`（标准）
- `Minimal`（精简）
- `Advanced`（高级）

示例：

```powershell
& ([ScriptBlock]::Create((irm "https://christitus.com/win"))) -Preset Standard
```

想看每个预设具体做了什么，请见：
https://github.com/ChrisTitusTech/winutil/blob/main/config/preset.json

创建你自己的配置文件：

1. 打开 Winutil。
2. 点击右上角的齿轮图标。
3. 选择 **Export（导出）**。
4. 保存导出的 JSON 文件。

导出配置后，用下面这条命令带着它启动 Winutil：
```powershell
& ([ScriptBlock]::Create((irm "https://christitus.com/win"))) -Config "C:\Path\To\Config.json"
```

这在以下场景很有用：

- 在多台 Windows 11 电脑上套用同一份 Winutil 配置
- 重装 Windows 后，复用一份已知可靠的基线配置
- 为实验室、工作站或个人环境标准化部署

> [!NOTE]
> 请在提升权限的 PowerShell 会话中运行该命令，这样 Winutil 才能进行系统级改动。
