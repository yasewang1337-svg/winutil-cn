---
title: "关闭活动历史相关策略"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFTweaksActivity; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFTweaksActivity`
- 当前分类：常用设置（按需选择）
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`e2ce1bf52cefe360a765bdcbde469664139ec732c332661c9bfdfeb383e10959`

关闭 Windows 活动历史的记录/同步相关策略。仅修改对应策略，不清理现有文件；效果取决于系统版本。可恢复本次修改前的注册表值。

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFTweaksActivity": {
    "Content": "关闭活动历史相关策略",
    "Description": "关闭 Windows 活动历史的记录/同步相关策略。仅修改对应策略，不清理现有文件；效果取决于系统版本。可恢复本次修改前的注册表值。",
    "category": "常用设置（按需选择）",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "EnableActivityFeed",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "PublishUserActivities",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "UploadUserActivities",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/dev/tweaks/essential-tweaks/activity"
  }
}
```
