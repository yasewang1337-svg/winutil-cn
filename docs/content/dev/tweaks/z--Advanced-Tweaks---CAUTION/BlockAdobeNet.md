---
title: "屏蔽 Adobe 联网（激活/遥测）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksBlockAdobeNet; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksBlockAdobeNet`
- 当前分类：z__高级优化 - 谨慎
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

通过 hosts 阻断部分 Adobe 激活/遥测域名，减少弹窗与联网请求（可能影响正版激活/更新，慎用）。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksBlockAdobeNet": {
    "Content": "屏蔽 Adobe 联网（激活/遥测）",
    "Description": "通过 hosts 阻断部分 Adobe 激活/遥测域名，减少弹窗与联网请求（可能影响正版激活/更新，慎用）。",
    "category": "z__高级优化 - 谨慎",
    "panel": "1",
    "InvokeScript": [
      "\r\n      $hostsUrl = Invoke-RestMethod -Uri https://github.com/Ruddernation-Designs/Adobe-URL-Block-List/raw/refs/heads/master/hosts\r\n      Add-Content -Path \"$Env:SystemRoot\\System32\\drivers\\etc\\hosts\" -Value $hostsUrl\r\n\r\n      ipconfig /flushdns\r\n      Write-Host 'Added Adobe url block list from host file'\r\n      "
    ],
    "UndoScript": [
      "\r\n      Set-Content \"$Env:SystemRoot\\System32\\drivers\\etc\\hosts\" (\r\n          (Get-Content \"$Env:SystemRoot\\System32\\drivers\\etc\\hosts\") -join \"`n\" -replace '(?s)#New Ver.*', ''\r\n      )\r\n\r\n      ipconfig /flushdns\r\n      Write-Host 'Removed Adobe url block list from host file'\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/z--advanced-tweaks---caution/blockadobenet"
  }
}
```
