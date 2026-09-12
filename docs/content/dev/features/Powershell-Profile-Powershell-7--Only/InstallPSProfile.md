---
title: "安装 CTT PowerShell 配置文件"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFWinUtilInstallPSProfile; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFWinUtilInstallPSProfile`
- 当前分类：PowerShell 配置文件(仅 7+)
- 源配置：`config/feature.json`
- 源配置 SHA-256：`9f9acba26432ca25eb2203ca70cec15563c7a3a4e0d5fa1dc795f149ac77c374`

## 配置定义

```json
{
  "WPFWinUtilInstallPSProfile": {
    "Content": "安装 CTT PowerShell 配置文件",
    "category": "PowerShell 配置文件(仅 7+)",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WinUtilInstallPSProfile",
    "link": "https://winutil.christitus.com/dev/features/powershell-profile-powershell-7--only/installpsprofile"
  }
}
```

## 入口函数

来源：`functions/private/Invoke-WinUtilInstallPSProfile.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WinUtilInstallPSProfile {
    if (-not (Get-Command wt)) {
        Write-Host "Windows Terminal not found installing..."
        Install-WinUtilWinget
        winget install Microsoft.WindowsTerminal --source winget --silent
    }

    if (-not (Get-Command pwsh)) {
        Write-Host "Powershell 7 not found installing..."
        Install-WinUtilWinget
        winget install Microsoft.PowerShell --source winget --silent
    }

    wt new-tab pwsh -NoExit -Command "irm https://github.com/ChrisTitusTech/powershell-profile/raw/main/setup.ps1 | iex"
}
```
