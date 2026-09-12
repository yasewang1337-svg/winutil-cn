---
title: "创建系统还原点"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksRestorePoint; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksRestorePoint`
- 当前分类：常用设置（按需选择）
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

先创建并核对新的 Windows 系统还原点；创建失败会停止本次其他修改。推荐通过中文版 EXE 使用，系统还原需在 Windows 中操作。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksRestorePoint": {
    "Content": "创建系统还原点",
    "Description": "先创建并核对新的 Windows 系统还原点；创建失败会停止本次其他修改。推荐通过中文版 EXE 使用，系统还原需在 Windows 中操作。",
    "category": "常用设置（按需选择）",
    "panel": "1",
    "Checked": "False",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore",
        "Name": "SystemRestorePointCreationFrequency",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1440"
      }
    ],
    "InvokeScript": [
      "New-WinUtilTweakRestorePoint"
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/restorepoint"
  }
}
```
