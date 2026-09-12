---
title: "移除“设置”首页"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFToggleHideSettingsHome; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFToggleHideSettingsHome`
- 当前分类：自定义偏好
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

在 Windows 11 中移除“设置”应用的首页（Home）入口/内容。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFToggleHideSettingsHome": {
    "Content": "移除“设置”首页",
    "Description": "在 Windows 11 中移除“设置”应用的首页（Home）入口/内容。",
    "category": "自定义偏好",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer",
        "Name": "SettingsPageVisibility",
        "Value": "show:home",
        "Type": "String",
        "OriginalValue": "hide:home",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/customize-preferences/hidesettingshome"
  }
}
```
