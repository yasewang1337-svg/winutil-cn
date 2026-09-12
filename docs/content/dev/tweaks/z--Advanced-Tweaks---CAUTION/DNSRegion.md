---
title: "DNS 区域模式"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFDNSRegion; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFDNSRegion`
- 当前分类：z__高级优化 - 谨慎
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFDNSRegion": {
    "Content": "DNS 区域模式",
    "category": "z__高级优化 - 谨慎",
    "panel": "1",
    "Type": "Combobox",
    "ComboItems": "国际 国内",
    "LinkedCombo": "WPFchangedns",
    "LinkedData": "regiondns"
  }
}
```
