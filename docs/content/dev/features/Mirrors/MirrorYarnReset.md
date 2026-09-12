---
title: "yarn 恢复官方"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorYarnReset; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorYarnReset`
- 当前分类：换源 · 恢复官方源
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

恢复 yarn 官方源。

## 配置定义

```json
{
  "WPFFeatureMirrorYarnReset": {
    "Content": "yarn 恢复官方",
    "Description": "恢复 yarn 官方源。",
    "category": "换源 · 恢复官方源",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command yarn -ErrorAction SilentlyContinue) { yarn config set registry https://registry.yarnpkg.com; Write-Host 'yarn 已恢复官方源' -ForegroundColor Green } else { Write-Host '未检测到 yarn' -ForegroundColor Yellow }"
    ]
  }
}
```
