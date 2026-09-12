---
title: "卸载 Microsoft Edge"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksRemoveEdge; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksRemoveEdge`
- 当前分类：z__高级优化 - 谨慎
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

解除 Edge 的卸载限制后，调用其卸载程序移除 Edge。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksRemoveEdge": {
    "Content": "卸载 Microsoft Edge",
    "Description": "解除 Edge 的卸载限制后，调用其卸载程序移除 Edge。",
    "category": "z__高级优化 - 谨慎",
    "panel": "1",
    "InvokeScript": [
      "Invoke-WinUtilRemoveEdge"
    ],
    "UndoScript": [
      "\r\n      Write-Host 'Installing Microsoft Edge...'\r\n      winget install Microsoft.Edge --source winget\r\n      "
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/z--advanced-tweaks---caution/removeedge"
  }
}
```
