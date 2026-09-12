---
title: "删除临时文件"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksDeleteTempFiles; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksDeleteTempFiles`
- 当前分类：常用设置（按需选择）
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

删除用户临时目录与系统临时目录中的文件，用于快速释放空间（可能删掉某些软件的临时缓存）。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksDeleteTempFiles": {
    "Content": "删除临时文件",
    "Description": "删除用户临时目录与系统临时目录中的文件，用于快速释放空间（可能删掉某些软件的临时缓存）。",
    "category": "常用设置（按需选择）",
    "panel": "1",
    "InvokeScript": [
      "\r\n      Remove-Item -Path \"$Env:Temp\\*\" -Recurse -Force\r\n      Remove-Item -Path \"$Env:SystemRoot\\Temp\\*\" -Recurse -Force\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/deletetempfiles"
  }
}
```
