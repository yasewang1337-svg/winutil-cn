---
title: "查看 CTT PowerShell 配置指南"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFWinUtilInstallPSProfile; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFWinUtilInstallPSProfile`
- 当前分类：PowerShell 配置文件(仅 7+)
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

打开 CTT PowerShell 配置文件的官方项目指南，请阅读说明后按需安装。

## 配置定义

```json
{
  "WPFWinUtilInstallPSProfile": {
    "Content": "查看 CTT PowerShell 配置指南",
    "Description": "打开 CTT PowerShell 配置文件的官方项目指南，请阅读说明后按需安装。",
    "category": "PowerShell 配置文件(仅 7+)",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WinUtilInstallPSProfile",
    "link": "https://github.com/ChrisTitusTech/powershell-profile"
  }
}
```

## 入口函数

来源：`functions/private/Invoke-WinUtilInstallPSProfile.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WinUtilInstallPSProfile {
    $guideUrl = 'https://github.com/ChrisTitusTech/powershell-profile'
    try {
        Start-Process -FilePath $guideUrl -ErrorAction Stop
    } catch {
        throw "无法打开 PowerShell 配置指南，请手动访问 $guideUrl 。$($_.Exception.Message)"
    }
}
```
