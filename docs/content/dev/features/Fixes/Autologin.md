---
title: "设置自动登录"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFPanelAutologin; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFPanelAutologin`
- 当前分类：修复
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

## 配置定义

```json
{
  "WPFPanelAutologin": {
    "Content": "设置自动登录",
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
    Invoke-WebRequest -Uri https://live.sysinternals.com/Autologon.exe -OutFile "$Env:Temp\autologin.exe"
    Start-Process -FilePath "$Env:Temp\autologin.exe" -ArgumentList /accepteula
}
```
