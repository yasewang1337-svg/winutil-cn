---
title: "启用 WSL（Linux 子系统）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeaturewsl; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeaturewsl`
- 当前分类：功能
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

启用 WSL，让你在 Windows 上运行 Linux 发行版（开发/命令行工具常用）。

## 配置定义

```json
{
  "WPFFeaturewsl": {
    "Content": "启用 WSL（Linux 子系统）",
    "Description": "启用 WSL，让你在 Windows 上运行 Linux 发行版（开发/命令行工具常用）。",
    "category": "功能",
    "panel": "1",
    "feature": [
      "VirtualMachinePlatform",
      "Microsoft-Windows-Subsystem-Linux"
    ],
    "InvokeScript": [],
    "link": "https://winutil.christitus.com/dev/features/features/wsl"
  }
}
```
