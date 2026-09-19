---
title: "配置 NTP 时间服务器"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFixesNTPPool; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFixesNTPPool`
- 当前分类：修复
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

将 Windows 默认时间服务器（time.windows.com）替换为 pool.ntp.org，以提高校时准确性和稳定性。

## 配置定义

```json
{
  "WPFFixesNTPPool": {
    "Content": "配置 NTP 时间服务器",
    "Description": "将 Windows 默认时间服务器（time.windows.com）替换为 pool.ntp.org，以提高校时准确性和稳定性。",
    "category": "修复",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFixesNTPPool",
    "link": "https://winutil.christitus.com/dev/features/fixes/ntppool"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFFixesNTPPool.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFFixesNTPPool {
    <#
    .SYNOPSIS
        Configures Windows to use pool.ntp.org for NTP synchronization

    .DESCRIPTION
        Replaces the default Windows NTP server (time.windows.com) with
        pool.ntp.org for improved time synchronization accuracy and reliability.
    #>

    Start-Service w32time
    w32tm /config /update /manualpeerlist:"pool.ntp.org,0x8" /syncfromflags:MANUAL

    Restart-Service w32time
    w32tm /resync

    Write-Host "================================="
    Write-Host "-- NTP Configuration Complete ---"
    Write-Host "================================="
}
```
