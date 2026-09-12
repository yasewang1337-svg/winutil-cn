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
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

把 25H2 新版开始菜单恢复为逐步推送前的旧布局。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksRevertStartMenu": {
    "Content": "恢复旧版开始菜单布局",
    "Description": "把 25H2 新版开始菜单恢复为逐步推送前的旧布局。",
    "category": "z__高级设置 - 先了解影响",
    "panel": "1",
    "InvokeScript": [
      "\r\n      Invoke-WebRequest https://github.com/thebookisclosed/ViVe/releases/download/v0.3.4/ViVeTool-v0.3.4-IntelAmd.zip -OutFile ViVeTool.zip\r\n\r\n      Expand-Archive ViVeTool.zip\r\n      Remove-Item ViVeTool.zip\r\n\r\n      Start-Process 'ViVeTool\\ViVeTool.exe' -ArgumentList '/disable /id:47205210' -Wait -NoNewWindow\r\n\r\n      Remove-Item ViVeTool -Recurse\r\n\r\n      Write-Host 'Old start menu reverted. Please restart your computer to take effect.'\r\n      Write-Host 'On newer versions of windows !!THIS TWEAK WILL NOT WORK!!.'\r\n      "
    ],
    "UndoScript": [
      "\r\n      Invoke-WebRequest https://github.com/thebookisclosed/ViVe/releases/download/v0.3.4/ViVeTool-v0.3.4-IntelAmd.zip -OutFile ViVeTool.zip\r\n\r\n      Expand-Archive ViVeTool.zip\r\n      Remove-Item ViVeTool.zip\r\n\r\n      Start-Process 'ViVeTool\\ViVeTool.exe' -ArgumentList '/enable /id:47205210' -Wait -NoNewWindow\r\n\r\n      Remove-Item ViVeTool -Recurse\r\n\r\n      Write-Host 'New start menu reverted. Please restart your computer to take effect.'\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/revertstartmenu"
  }
}
```
