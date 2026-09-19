---
title: "运行磁盘清理"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksDiskCleanup; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksDiskCleanup`
- 当前分类：常用设置（按需选择）
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

运行系统磁盘清理并清理旧组件/更新缓存，释放空间（可能需要较长时间）。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksDiskCleanup": {
    "Content": "运行磁盘清理",
    "Description": "运行系统磁盘清理并清理旧组件/更新缓存，释放空间（可能需要较长时间）。",
    "category": "常用设置（按需选择）",
    "panel": "1",
    "InvokeScript": [
      "\r\n      cleanmgr.exe /d C: /VERYLOWDISK\r\n      Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/diskcleanup"
  }
}
```
