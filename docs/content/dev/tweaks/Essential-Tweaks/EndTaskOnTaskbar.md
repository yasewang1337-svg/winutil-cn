---
title: "右键任务栏启用“结束任务”"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksEndTaskOnTaskbar; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksEndTaskOnTaskbar`
- 当前分类：常用设置（按需选择）
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

在支持的 Windows 11 版本中，为任务栏程序右键菜单增加“结束任务”。强制结束应用可能丢失未保存内容；此项仅显示入口，不会自动结束程序。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksEndTaskOnTaskbar": {
    "Content": "右键任务栏启用“结束任务”",
    "Description": "在支持的 Windows 11 版本中，为任务栏程序右键菜单增加“结束任务”。强制结束应用可能丢失未保存内容；此项仅显示入口，不会自动结束程序。",
    "category": "常用设置（按需选择）",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced\\TaskbarDeveloperSettings",
        "Name": "TaskbarEndTask",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/endtaskontaskbar"
  }
}
```
