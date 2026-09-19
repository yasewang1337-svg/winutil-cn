---
title: "yarn 换 npmmirror"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorYarnCN; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorYarnCN`
- 当前分类：换源 · 换国内镜像
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

把 yarn 源换成 npmmirror 镜像。

## 配置定义

```json
{
  "WPFFeatureMirrorYarnCN": {
    "Content": "yarn 换 npmmirror",
    "Description": "把 yarn 源换成 npmmirror 镜像。",
    "category": "换源 · 换国内镜像",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command yarn -ErrorAction SilentlyContinue) { yarn config set registry https://registry.npmmirror.com; Write-Host 'yarn 已换 npmmirror 源' -ForegroundColor Green } else { Write-Host '未检测到 yarn' -ForegroundColor Yellow }"
    ]
  }
}
```
