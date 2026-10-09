---
title: "恢复旧版开始菜单布局"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksRevertStartMenu; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksRevertStartMenu`
- 当前分类：z__高级设置 - 先了解影响
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`33f10e42b9f76c8fbd483caa30659ea97f92494332979089db2acdb6f1c63951`

从官方 GitHub 发布页下载 ViVeTool v0.3.4，核对固定 SHA256 后禁用 Windows 功能 47205210，尝试恢复旧版开始菜单布局。可能需要重启，较新 Windows 版本可能不再支持；此功能改动无法通过 WinUtil 操作历史完整恢复。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksRevertStartMenu": {
    "Content": "恢复旧版开始菜单布局",
    "Description": "从官方 GitHub 发布页下载 ViVeTool v0.3.4，核对固定 SHA256 后禁用 Windows 功能 47205210，尝试恢复旧版开始菜单布局。可能需要重启，较新 Windows 版本可能不再支持；此功能改动无法通过 WinUtil 操作历史完整恢复。",
    "category": "z__高级设置 - 先了解影响",
    "panel": "1",
    "InvokeScript": [
      "$null = Invoke-WinUtilVerifiedTool -Tool ViVeTool -Action Disable -ErrorAction Stop\r\nWrite-Host '已应用恢复旧版开始菜单设置，请重启电脑。部分较新 Windows 版本可能不支持此设置。'"
    ],
    "UndoScript": [
      "$null = Invoke-WinUtilVerifiedTool -Tool ViVeTool -Action Enable -ErrorAction Stop\r\nWrite-Host '已应用新版开始菜单设置，请重启电脑。'"
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/revertstartmenu"
  }
}
```
