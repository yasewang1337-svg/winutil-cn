---
title: "pip 换清华源"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorPipCN; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorPipCN`
- 当前分类：换源 · 换国内镜像
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

把 Python pip 默认源换成清华 TUNA 镜像，国内装包飞快。

## 配置定义

```json
{
  "WPFFeatureMirrorPipCN": {
    "Content": "pip 换清华源",
    "Description": "把 Python pip 默认源换成清华 TUNA 镜像，国内装包飞快。",
    "category": "换源 · 换国内镜像",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command pip -ErrorAction SilentlyContinue) { pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple; pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn; Write-Host 'pip 已换清华源' -ForegroundColor Green } else { Write-Host '未检测到 pip，请先安装 Python' -ForegroundColor Yellow }"
    ]
  }
}
```
