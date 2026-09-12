---
title: "conda 恢复官方"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorCondaReset; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorCondaReset`
- 当前分类：换源 · 恢复官方源
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

清除 conda 自定义频道，恢复默认。

## 配置定义

```json
{
  "WPFFeatureMirrorCondaReset": {
    "Content": "conda 恢复官方",
    "Description": "清除 conda 自定义频道，恢复默认。",
    "category": "换源 · 恢复官方源",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command conda -ErrorAction SilentlyContinue) { conda config --remove-key channels 2>$null; Write-Host 'conda 已恢复默认频道' -ForegroundColor Green } else { Write-Host '未检测到 conda' -ForegroundColor Yellow }"
    ]
  }
}
```
