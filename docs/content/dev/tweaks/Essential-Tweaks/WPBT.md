---
title: "禁用 WPBT（平台二进制表）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksWPBT; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksWPBT`
- 当前分类：z__高级设置 - 先了解影响
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

阻止系统执行 OEM 写入的 WPBT 内容，降低厂商预装/持久化程序带来的风险（高级选项）。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksWPBT": {
    "Content": "禁用 WPBT（平台二进制表）",
    "Description": "阻止系统执行 OEM 写入的 WPBT 内容，降低厂商预装/持久化程序带来的风险（高级选项）。",
    "category": "z__高级设置 - 先了解影响",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager",
        "Name": "DisableWpbtExecution",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/wpbt"
  }
}
```
