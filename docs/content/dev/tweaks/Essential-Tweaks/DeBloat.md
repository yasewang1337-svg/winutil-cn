---
title: "批量卸载内置应用（谨慎）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksDeBloat; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksDeBloat`
- 当前分类：z__高级设置 - 先了解影响
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

移除配置清单中的画图、便笺、录音机、天气、新版 Outlook、Teams 等应用及部分预装包。可能影响其他用户；应用和数据不能通过“恢复所选设置”还原，请先确认确实不需要。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksDeBloat": {
    "Content": "批量卸载内置应用（谨慎）",
    "Description": "移除配置清单中的画图、便笺、录音机、天气、新版 Outlook、Teams 等应用及部分预装包。可能影响其他用户；应用和数据不能通过“恢复所选设置”还原，请先确认确实不需要。",
    "category": "z__高级设置 - 先了解影响",
    "panel": "1",
    "appx": [
      "Microsoft.WindowsFeedbackHub",
      "Microsoft.BingNews",
      "Microsoft.BingSearch",
      "Microsoft.BingWeather",
      "Clipchamp.Clipchamp",
      "Microsoft.Todos",
      "Microsoft.PowerAutomateDesktop",
      "Microsoft.MicrosoftSolitaireCollection",
      "Microsoft.WindowsSoundRecorder",
      "Microsoft.MicrosoftStickyNotes",
      "Microsoft.Windows.DevHome",
      "Microsoft.Paint",
      "Microsoft.OutlookForWindows",
      "Microsoft.WindowsAlarms",
      "Microsoft.StartExperiencesApp",
      "Microsoft.GetHelp",
      "Microsoft.ZuneMusic",
      "MicrosoftCorporationII.QuickAssist",
      "MSTeams"
    ],
    "InvokeScript": [
      "\r\n      $TeamsPath = \"$Env:LocalAppData\\Microsoft\\Teams\\Update.exe\"\r\n\r\n      if (Test-Path $TeamsPath) {\r\n        Write-Host \"Uninstalling Teams\"\r\n        Start-Process $TeamsPath -ArgumentList -uninstall -wait\r\n\r\n        Write-Host \"Deleting Teams directory\"\r\n        Remove-Item $TeamsPath -Recurse -Force\r\n      }\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/debloat"
  }
}
```
