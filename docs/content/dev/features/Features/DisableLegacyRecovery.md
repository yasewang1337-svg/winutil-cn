---
title: "禁用传统 F8 启动恢复菜单"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureDisableLegacyRecovery; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureDisableLegacyRecovery`
- 当前分类：功能
- 源配置：`config/feature.json`
- 源配置 SHA-256：`956400006e36b3841c7816500199907bb57de94c98a0f05b1e9ee4737a8ab03c`

关闭传统 F8 恢复菜单，恢复为默认快速启动行为。

## 配置定义

```json
{
  "WPFFeatureDisableLegacyRecovery": {
    "Content": "禁用传统 F8 启动恢复菜单",
    "Description": "关闭传统 F8 恢复菜单，恢复为默认快速启动行为。",
    "category": "功能",
    "panel": "1",
    "feature": [],
    "InvokeScript": [
      "bcdedit /set bootmenupolicy standard"
    ],
    "link": "https://winutil.christitus.com/dev/features/features/disablelegacyrecovery"
  }
}
```
