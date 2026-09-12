---
title: "conda 换清华源"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorCondaCN; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorCondaCN`
- 当前分类：换源 · 换国内镜像
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

给 conda 添加清华 anaconda 镜像频道并显示来源。

## 配置定义

```json
{
  "WPFFeatureMirrorCondaCN": {
    "Content": "conda 换清华源",
    "Description": "给 conda 添加清华 anaconda 镜像频道并显示来源。",
    "category": "换源 · 换国内镜像",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "if (Get-Command conda -ErrorAction SilentlyContinue) { conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/; conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/; conda config --set show_channel_urls yes; Write-Host 'conda 已加清华源' -ForegroundColor Green } else { Write-Host '未检测到 conda' -ForegroundColor Yellow }"
    ]
  }
}
```
