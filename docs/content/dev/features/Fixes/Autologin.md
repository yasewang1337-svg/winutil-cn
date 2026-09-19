---
title: "自动登录（微软官方说明）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFPanelAutologin; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFPanelAutologin`
- 当前分类：修复
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

## 配置定义

```json
{
  "WPFPanelAutologin": {
    "Content": "自动登录（微软官方说明）",
    "category": "修复",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFPanelAutologin",
    "link": "https://winutil.christitus.com/dev/features/fixes/autologin"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFPanelAutologin.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFPanelAutologin {
    <#
    .SYNOPSIS
        Opens Microsoft's Autologon documentation and download page for review.
    #>
    Start-Process 'https://learn.microsoft.com/sysinternals/downloads/autologon' -ErrorAction Stop
}
```
