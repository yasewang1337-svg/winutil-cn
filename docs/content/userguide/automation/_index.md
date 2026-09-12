---
title: 清单与自动化
weight: 7
prev: /userguide/updates/
next: /userguide/win11creator/
---

装机清单保存软件和设置的选择，便于重装电脑或在另一台设备上复用。图形界面导入和命令行自动执行是两个不同入口。

## 图形界面：导入后先核对

1. 在软件或设置页面选好项目，从首页或菜单选择导出清单，保存 JSON 文件。
2. 下次打开工具，选择导入清单。
3. 工具先检查格式和项目 ID；确认后替换当前选择。
4. 再查看安装或设置计划，确认执行。

导入本身不会安装软件、执行设置或切换开关；格式错误、未知项目或取消导入时保留已有选择。

## 命令行：明确要求自动执行

先从[中文发布页](https://github.com/yasewang1337-svg/winutil-cn/releases/latest)下载 `winutil-cn.ps1`，在管理员 PowerShell 中进入保存目录。下面的命令会执行操作，使用前应先核对方案或清单。

```powershell
# 执行基础设置方案
& .\winutil-cn.ps1 -Preset Minimal

# 按自己已核对的清单执行
& .\winutil-cn.ps1 -Config 'C:\Path\To\Config.json'
```

自动模式支持软件安装操作和可记录的基础注册表设置（含受支持的开关）。`Minimal` 和 `Standard` 可用于这一入口；`Advanced` 包含还原点与脚本，需要在图形界面确认。服务调整、Appx 移除、DNS、系统功能与其他脚本操作不属于自动模式支持范围。

当前方案的精确内容见本仓库 [preset.json](https://github.com/yasewang1337-svg/winutil-cn/blob/main/config/preset.json)。使用其他版本导出的清单前，应先在图形界面导入检查兼容性。

## 检查结果

自动执行遇到未完成或失败项会报告错误，不能仅凭窗口结束判断全部成功。软件日志位于 `%LOCALAPPDATA%\WinUtil-CN\Logs\Packages`；设置历史位于 `%LOCALAPPDATA%\WinUtil\TweakHistory`。

自动执行不会提供完整系统回滚。恢复范围与[设置指南](../tweaks/)一致；软件版本回退、删除的应用和清理文件需要另外处理。
