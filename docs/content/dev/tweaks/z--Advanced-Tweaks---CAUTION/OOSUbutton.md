---
title: "运行 O&O ShutUp10++（隐私工具）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFOOSUbutton; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFOOSUbutton`
- 当前分类：z__高级优化 - 谨慎
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFOOSUbutton": {
    "Content": "运行 O&O ShutUp10++（隐私工具）",
    "category": "z__高级优化 - 谨慎",
    "panel": "1",
    "Type": "Button",
    "link": "https://winutil.christitus.com/dev/tweaks/z--advanced-tweaks---caution/oosubutton"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFOOSU.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFOOSU {
    try {
        $ProgressPreference = 'SilentlyContinue'

        Invoke-WebRequest -Uri https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe -OutFile "$Env:Temp\ooshutup10.exe"
        Start-Process -FilePath "$Env:Temp\ooshutup10.exe"

        $ProgressPreference = 'Continue'
    } catch {
        Write-Error "Couldn't download O&O ShutUp10. Please make sure you have an active internet connection."
    }
}
```
