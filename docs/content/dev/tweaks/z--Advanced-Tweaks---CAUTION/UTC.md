---
title: "时间改为 UTC（双系统）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksUTC; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksUTC`
- 当前分类：z__高级优化 - 谨慎
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

把系统时钟按 UTC 存储，适合与 Linux 双系统共用硬件时钟，避免来回切换导致时间错乱。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksUTC": {
    "Content": "时间改为 UTC（双系统）",
    "Description": "把系统时钟按 UTC 存储，适合与 Linux 双系统共用硬件时钟，避免来回切换导致时间错乱。",
    "category": "z__高级优化 - 谨慎",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation",
        "Name": "RealTimeIsUniversal",
        "Value": "1",
        "Type": "QWord",
        "OriginalValue": "0"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/z--advanced-tweaks---caution/utc"
  }
}
```
