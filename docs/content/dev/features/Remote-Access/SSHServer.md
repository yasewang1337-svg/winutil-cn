---
title: "启用 OpenSSH Server"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFWinUtilSSHServer; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFWinUtilSSHServer`
- 当前分类：远程访问
- 源配置：`config/feature.json`
- 源配置 SHA-256：`ac97f75eddfb3fc5f085b8dd9b8faa5467671ba7e138c2d4785df4b54416e7fd`

## 配置定义

```json
{
  "WPFWinUtilSSHServer": {
    "Content": "启用 OpenSSH Server",
    "category": "远程访问",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFSSHServer",
    "link": "https://winutil.christitus.com/dev/features/remote-access/sshserver"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFSSHServer.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFSSHServer {
    <#

    .SYNOPSIS
        Invokes the OpenSSH Server install in a runspace

  #>

    Invoke-WPFRunspace -ScriptBlock {

        Invoke-WinUtilSSHServer

        Write-Host "======================================="
        Write-Host "--     OpenSSH Server installed!    ---"
        Write-Host "======================================="
    }
}
```
