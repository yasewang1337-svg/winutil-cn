---
title: "打印机设置"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFPanelPrinter; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFPanelPrinter`
- 当前分类：传统 Windows 面板
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

## 配置定义

```json
{
  "WPFPanelPrinter": {
    "Content": "打印机设置",
    "category": "传统 Windows 面板",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "Start-Process 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}'"
    ],
    "link": "https://winutil.christitus.com/dev/features/legacy-windows-panels/printer"
  }
}
```
