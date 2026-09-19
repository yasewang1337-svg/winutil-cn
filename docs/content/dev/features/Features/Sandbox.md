---
title: "启用 Windows Sandbox（沙盒）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeaturesSandbox; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeaturesSandbox`
- 当前分类：功能
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

启用 Windows 沙盒：一次性、隔离的临时系统环境，适合测试不可信程序（退出即清空）。

## 配置定义

```json
{
  "WPFFeaturesSandbox": {
    "Content": "启用 Windows Sandbox（沙盒）",
    "Description": "启用 Windows 沙盒：一次性、隔离的临时系统环境，适合测试不可信程序（退出即清空）。",
    "category": "功能",
    "panel": "1",
    "feature": [
      "Containers-DisposableClientVM"
    ],
    "link": "https://winutil.christitus.com/dev/features/features/sandbox"
  }
}
```
