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
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

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
