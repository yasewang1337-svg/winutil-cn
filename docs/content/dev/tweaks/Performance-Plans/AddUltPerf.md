---
title: "添加并启用“卓越性能”电源计划"
description: "当前源配置生成的开发参考"
generated: true
aliases:
  - "/dev/tweaks/performance-plans---not-for-laptops/addultperf/"
---

<!-- winutil-devdocs: tweaks/WPFAddUltPerf; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFAddUltPerf`
- 当前分类：性能计划 - 不适用于笔记本
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFAddUltPerf": {
    "Content": "添加并启用“卓越性能”电源计划",
    "category": "性能计划 - 不适用于笔记本",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "link": "https://winutil.christitus.com/dev/tweaks/performance-plans---not-for-laptops/addultperf"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFUltimatePerformance.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFUltimatePerformance ([switch]$Enable) {
    if ($Enable) {
        powercfg /setactive (powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Select-String -Pattern '[A-Fa-f0-9-]{36}').Matches.Value
        [System.Windows.MessageBox]::Show("卓越性能电源计划已安装并启用。","成功","OK","Information")
    } else {
        powercfg /restoredefaultschemes
        [System.Windows.MessageBox]::Show("电源计划已重置为默认。","成功","OK","Information")
    }
}
```
