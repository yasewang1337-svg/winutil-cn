---
title: "卸载 CTT PowerShell 配置文件"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFWinUtilUninstallPSProfile; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFWinUtilUninstallPSProfile`
- 当前分类：PowerShell 配置文件(仅 7+)
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

## 配置定义

```json
{
  "WPFWinUtilUninstallPSProfile": {
    "Content": "卸载 CTT PowerShell 配置文件",
    "category": "PowerShell 配置文件(仅 7+)",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WinUtilUninstallPSProfile",
    "link": "https://winutil.christitus.com/dev/features/powershell-profile-powershell-7--only/uninstallpsprofile"
  }
}
```

## 入口函数

来源：`functions/private/Invoke-WinUtilUninstallPSProfile.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WinUtilUninstallPSProfile {

    if (Test-Path ($Profile + ".bak")) {
        Move-Item -Path ($Profile + ".bak") -Destination $Profile
    } else {
        Remove-Item -Path $Profile
    }

    Write-Host "Successfully uninstalled CTT PowerShell Profile." -ForegroundColor Green
}
```
