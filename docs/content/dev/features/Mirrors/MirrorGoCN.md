---
title: "go 换 goproxy.cn"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorGoCN; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorGoCN`
- 当前分类：换源 · 换国内镜像
- 源配置：`config/feature.json`
- 源配置 SHA-256：`56ea30c4ec708287321e017ee42c1e6316d3d197cafba238138466e020d5d4f5`

把 Go 模块代理换成 goproxy.cn。

## 配置定义

```json
{
  "WPFFeatureMirrorGoCN": {
    "Content": "go 换 goproxy.cn",
    "Description": "把 Go 模块代理换成 goproxy.cn。",
    "category": "换源 · 换国内镜像",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command go -ErrorAction SilentlyContinue) { go env -w GOPROXY=https://goproxy.cn,direct; Write-Host 'go 已换 goproxy.cn' -ForegroundColor Green } else { Write-Host '未检测到 go' -ForegroundColor Yellow }"
    ]
  }
}
```
