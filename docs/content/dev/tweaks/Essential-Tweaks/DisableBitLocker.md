---
title: "关闭系统盘 BitLocker 加密（谨慎）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksDisableBitLocker; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksDisableBitLocker`
- 当前分类：z__高级设置 - 先了解影响
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

开始解密系统盘，降低设备遗失后的数据保护。解密过程需要时间；操作历史无法恢复加密状态。请先核对恢复密钥和使用需求。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksDisableBitLocker": {
    "Content": "关闭系统盘 BitLocker 加密（谨慎）",
    "Description": "开始解密系统盘，降低设备遗失后的数据保护。解密过程需要时间；操作历史无法恢复加密状态。请先核对恢复密钥和使用需求。",
    "category": "z__高级设置 - 先了解影响",
    "panel": "1",
    "InvokeScript": [
      "Disable-BitLocker -MountPoint $Env:SystemDrive"
    ],
    "UndoScript": [
      "Enable-BitLocker -MountPoint $Env:SystemDrive"
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/disablebitlocker"
  }
}
```
