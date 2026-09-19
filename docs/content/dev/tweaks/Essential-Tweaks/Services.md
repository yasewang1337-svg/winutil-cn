---
title: "调整服务启动方式（含禁用）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksServices; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksServices`
- 当前分类：z__高级设置 - 先了解影响
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

禁用离线文件、诊断跟踪和网络连接共享等服务，并将部分服务改为手动。可能影响企业离线文件、热点/共享和相关功能；不会默认勾选。注册表脚本的附加改动不在历史恢复范围内。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksServices": {
    "Content": "调整服务启动方式（含禁用）",
    "Description": "禁用离线文件、诊断跟踪和网络连接共享等服务，并将部分服务改为手动。可能影响企业离线文件、热点/共享和相关功能；不会默认勾选。注册表脚本的附加改动不在历史恢复范围内。",
    "category": "z__高级设置 - 先了解影响",
    "panel": "1",
    "service": [
      {
        "Name": "CscService",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      },
      {
        "Name": "DiagTrack",
        "StartupType": "Disabled",
        "OriginalType": "Automatic"
      },
      {
        "Name": "MapsBroker",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "StorSvc",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SharedAccess",
        "StartupType": "Disabled",
        "OriginalType": "Automatic"
      }
    ],
    "InvokeScript": [
      "\r\n      $Memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB\r\n      Set-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name SvcHostSplitThresholdInKB -Value $Memory\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/services"
  }
}
```
