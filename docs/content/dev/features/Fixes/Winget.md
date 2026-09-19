---
title: "重新安装/修复 WinGet"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFixesWinget; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFixesWinget`
- 当前分类：修复
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

## 配置定义

```json
{
  "WPFFixesWinget": {
    "Content": "重新安装/修复 WinGet",
    "category": "修复",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFixesWinget",
    "link": "https://winutil.christitus.com/dev/features/fixes/winget"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFFixesWinget.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFFixesWinget {

    <#

    .SYNOPSIS
        Fixes WinGet by running `choco install winget`
    .DESCRIPTION
        BravoNorris for the fantastic idea of a button to reinstall WinGet
    #>
    # Install Choco if not already present
    try {
        Set-WinUtilTaskbaritem -state "Indeterminate" -overlay "logo"
        Write-Host "==> Starting WinGet Repair"
        Install-WinUtilWinget
    } catch {
        Write-Error "Failed to install WinGet: $_"
        Set-WinUtilTaskbaritem -state "Error" -overlay "warning"
    } finally {
        Write-Host "==> Finished WinGet Repair"
        Set-WinUtilTaskbaritem -state "None" -overlay "checkmark"
    }

}
```
