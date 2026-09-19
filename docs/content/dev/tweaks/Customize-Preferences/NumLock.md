---
title: "开机自动开启 NumLock"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFToggleNumLock; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFToggleNumLock`
- 当前分类：自定义偏好
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

控制开机后 NumLock 是否默认开启。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFToggleNumLock": {
    "Content": "开机自动开启 NumLock",
    "Description": "控制开机后 NumLock 是否默认开启。",
    "category": "自定义偏好",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKU:\\.Default\\Control Panel\\Keyboard",
        "Name": "InitialKeyboardIndicators",
        "Value": "2",
        "Type": "String",
        "OriginalValue": "0",
        "DefaultState": "false"
      },
      {
        "Path": "HKCU:\\Control Panel\\Keyboard",
        "Name": "InitialKeyboardIndicators",
        "Value": "2",
        "Type": "String",
        "OriginalValue": "0",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/customize-preferences/numlock"
  }
}
```
