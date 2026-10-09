---
title: "启用传统 F8 启动恢复菜单"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureEnableLegacyRecovery; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureEnableLegacyRecovery`
- 当前分类：功能
- 源配置：`config/feature.json`
- 源配置 SHA-256：`56ea30c4ec708287321e017ee42c1e6316d3d197cafba238138466e020d5d4f5`

启用传统“按 F8 进入高级启动选项”的恢复菜单（对排障更方便）。

## 配置定义

```json
{
  "WPFFeatureEnableLegacyRecovery": {
    "Content": "启用传统 F8 启动恢复菜单",
    "Description": "启用传统“按 F8 进入高级启动选项”的恢复菜单（对排障更方便）。",
    "category": "功能",
    "panel": "1",
    "feature": [],
    "InvokeScript": [
      "bcdedit /set bootmenupolicy legacy"
    ],
    "link": "https://winutil.christitus.com/dev/features/features/enablelegacyrecovery"
  }
}
```
