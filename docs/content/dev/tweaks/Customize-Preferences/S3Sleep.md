---
title: "S3 睡眠（传统睡眠）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFToggleS3Sleep; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFToggleS3Sleep`
- 当前分类：自定义偏好
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

切换到传统 S3 睡眠（若硬件/BIOS 支持）。有助于解决某些“睡眠唤醒异常”。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFToggleS3Sleep": {
    "Content": "S3 睡眠（传统睡眠）",
    "Description": "切换到传统 S3 睡眠（若硬件/BIOS 支持）。有助于解决某些“睡眠唤醒异常”。",
    "category": "自定义偏好",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power",
        "Name": "PlatformAoAcOverride",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/customize-preferences/s3sleep"
  }
}
```
