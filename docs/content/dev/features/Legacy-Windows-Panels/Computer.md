---
title: "计算机管理"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFPanelComputer; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFPanelComputer`
- 当前分类：传统 Windows 面板
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

## 配置定义

```json
{
  "WPFPanelComputer": {
    "Content": "计算机管理",
    "category": "传统 Windows 面板",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "compmgmt.msc"
    ],
    "link": "https://winutil.christitus.com/dev/features/legacy-windows-panels/computer"
  }
}
```
