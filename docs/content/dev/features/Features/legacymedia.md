---
title: "启用旧媒体组件（WMP/DirectPlay）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureslegacymedia; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureslegacymedia`
- 当前分类：功能
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

启用旧版媒体相关组件（Windows Media Player、DirectPlay 等），用于兼容老游戏/老播放器。

## 配置定义

```json
{
  "WPFFeatureslegacymedia": {
    "Content": "启用旧媒体组件（WMP/DirectPlay）",
    "Description": "启用旧版媒体相关组件（Windows Media Player、DirectPlay 等），用于兼容老游戏/老播放器。",
    "category": "功能",
    "panel": "1",
    "feature": [
      "WindowsMediaPlayer",
      "MediaPlayback",
      "DirectPlay",
      "LegacyComponents"
    ],
    "InvokeScript": [],
    "link": "https://winutil.christitus.com/dev/features/features/legacymedia"
  }
}
```
