---
title: "go 恢复官方"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorGoReset; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorGoReset`
- 当前分类：换源 · 恢复官方源
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

恢复 Go 官方模块代理。

## 配置定义

```json
{
  "WPFFeatureMirrorGoReset": {
    "Content": "go 恢复官方",
    "Description": "恢复 Go 官方模块代理。",
    "category": "换源 · 恢复官方源",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command go -ErrorAction SilentlyContinue) { go env -w GOPROXY=https://proxy.golang.org,direct; Write-Host 'go 已恢复官方代理' -ForegroundColor Green } else { Write-Host '未检测到 go' -ForegroundColor Yellow }"
    ]
  }
}
```
