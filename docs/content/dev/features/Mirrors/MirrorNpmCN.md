---
title: "npm 换 npmmirror"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorNpmCN; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorNpmCN`
- 当前分类：换源 · 换国内镜像
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

把 npm 源换成 npmmirror（淘宝）镜像，装 node 包更快。

## 配置定义

```json
{
  "WPFFeatureMirrorNpmCN": {
    "Content": "npm 换 npmmirror",
    "Description": "把 npm 源换成 npmmirror（淘宝）镜像，装 node 包更快。",
    "category": "换源 · 换国内镜像",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command npm -ErrorAction SilentlyContinue) { npm config set registry https://registry.npmmirror.com; Write-Host 'npm 已换 npmmirror 源' -ForegroundColor Green } else { Write-Host '未检测到 npm，请先安装 Node.js' -ForegroundColor Yellow }"
    ]
  }
}
```
