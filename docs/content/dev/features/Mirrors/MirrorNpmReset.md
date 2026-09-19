---
title: "npm 恢复官方"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorNpmReset; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorNpmReset`
- 当前分类：换源 · 恢复官方源
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

恢复 npm 官方源 registry.npmjs.org。

## 配置定义

```json
{
  "WPFFeatureMirrorNpmReset": {
    "Content": "npm 恢复官方",
    "Description": "恢复 npm 官方源 registry.npmjs.org。",
    "category": "换源 · 恢复官方源",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command npm -ErrorAction SilentlyContinue) { npm config set registry https://registry.npmjs.org; Write-Host 'npm 已恢复官方源' -ForegroundColor Green } else { Write-Host '未检测到 npm' -ForegroundColor Yellow }"
    ]
  }
}
```
