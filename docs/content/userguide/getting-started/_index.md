---
title: 快速上手
weight: 2
prev: /userguide/
next: /userguide/application/
---

## 欢迎使用 Winutil！

Winutil 帮你在一个地方完成安装应用、套用系统优化项、运行常见修复，以及管理 Windows 设置。本指南介绍最安全的上手方式，以及大多数用户最先会做的几步操作。

## 系统要求

在运行 Winutil 之前，请确认你的系统满足以下要求：

> [!IMPORTANT]
> Winutil 不支持 Windows 10。Windows 10 已于 **2025 年 10 月 14 日**结束支持。

- **操作系统**：Windows 11
- **PowerShell**：5.1 或更高版本（Windows 11 默认已内置）
- **管理员访问权限**：进行系统级改动所必需
- **网络连接**：下载应用和更新时需要
- **.NET Framework**：4.5 或更高版本（通常已预装）

## 安装

Winutil 不需要传统意义上的安装。它以脚本形式直接从 PowerShell 运行。

### 第 1 步：以管理员身份打开 PowerShell

有好几种方式可以用管理员权限打开 PowerShell：

**方法一：开始菜单（推荐）**

1. 右键点击 Windows「开始」按钮
2. 选择「终端（管理员）」

**方法二：搜索**

1. 按下 `Windows` 键
2. 输入「PowerShell」或「Terminal」
3. 按 `Ctrl + Shift + Enter` 以管理员身份启动
4. 或者右键点击，选择「以管理员身份运行」

**方法三：运行对话框**

1. 按 `Windows + R`
2. 输入 `powershell`
3. 按 `Ctrl + Shift + Enter`

### 第 2 步：运行启动命令

在以管理员身份运行的 PowerShell 中，根据你想要的发布渠道，运行下面其中一条命令。

**稳定版（推荐）**

```powershell
irm "https://christitus.com/win" | iex
```

**开发分支（最前沿——仅供测试）**

```powershell
irm "https://christitus.com/windev" | iex
```

> [!NOTE]
> - `irm` 命令下载脚本，`iex` 执行它。从官方来源下载时，这是安全的。
> - 开发分支可能包含实验性改动，只应在非生产系统上用于测试。

### 第 3 步：等待 Winutil 加载

第一次运行 Winutil 时，它可能需要一小会儿来：

- 下载最新版本
- 初始化界面
- 加载全部功能和设置

## 首次设置

### 认识界面

Winutil 打开后是一个简洁的、带标签页的界面：

**主要标签页**：

- **Install（安装）**：浏览并安装应用
- **Tweaks（优化项）**：套用系统优化和自定义
- **Config（配置）**：访问系统工具和实用程序
- **Updates（更新）**：管理 Windows 更新
- **Win11 Creator（Win11 创建器）**：基于官方微软镜像，构建一份自定义的 Windows 11 ISO。

## 你的第一批操作

以下是给新用户推荐的几个上手步骤：

### 1. 创建还原点

在做任何改动之前，先创建一个系统还原点：

1. 进入 **Tweaks（优化项）** 标签页
2. 在「基础优化项（Essential Tweaks）」下找到「Create Restore Point（创建还原点）」
3. 勾选它，然后点击 **Run Tweaks（运行优化项）**

这样一旦需要，你就有了一个可回退的点。

### 2. 安装常用应用

1. 切换到 **Install（安装）** 标签页
2. 浏览分类，或使用搜索栏
3. 勾选你想安装的应用
4. 点击底部的「Install/Upgrade Selected（安装/升级所选）」

### 3. 套用基础优化项

以极小的风险获得更好的 Windows 体验：

1. 进入 **Tweaks（优化项）** 标签页
2. 选择 **Standard（标准）** 预设，获得一份均衡配置
3. 查看已选中的优化项
4. 点击 **Run Tweaks（运行优化项）**

> [!NOTE]
> 某些优化项、修复和更新改动，可能需要重启或注销后，完整效果才会显现。

## 常见任务

### 安装应用

**单个应用**：

1. 打开 **Install（安装）** 标签页
2. 搜索应用名称
3. 勾选它旁边的复选框
4. 点击「Install/Upgrade Selected（安装/升级所选）」

**多个应用**：

1. 勾选多个应用的复选框
2. 所有勾选的应用会依次安装
3. 进度显示在底部面板

### 套用优化项

**基础优化项**（对所有用户安全）：

1. 进入 **Tweaks（优化项）** 标签页
2. 从「基础优化项」区域中选择
3. 点击 **Run Tweaks（运行优化项）**

**高级优化项**（谨慎使用）：

1. 只有在你理解其影响时才修改
2. 务必先创建还原点
3. 查阅每个优化项的文档

**撤销优化项**：

1. 选中你之前套用的同一批优化项
2. 点击 **Undo Selected Tweaks（撤销所选优化项）**
3. 系统会恢复到之前的状态

### 使用快速修复

针对常见 Windows 问题：

1. 进入 **Config（配置）** 标签页
2. 导航到 **Fixes（修复）** 区域
3. 选择合适的修复：
   - **Reset Network（重置网络）**：修复网络连接问题
   - **Reset Windows Update（重置 Windows 更新）**：解决更新问题
   - **System Corruption Scan（系统损坏扫描）**：修复损坏的系统文件
   - **WinGet Reinstall（重装 WinGet）**：修复包管理器问题

### 更换 DNS 服务器

为了更好的隐私和速度：

1. 进入 **Tweaks（优化项）** 标签页
2. 找到 DNS 区域
3. 选择一个提供商：
   - **Cloudflare**：快速且注重隐私
   - **Google**：可靠且广泛使用
   - **Quad9**：注重安全，屏蔽恶意软件
   - **AdGuard**：屏蔽广告和追踪器
4. 点击 **Apply（应用）**

## 认识预设

Winutil 提供了几种预设配置：

- **Minimal（精简）**：改动最小，保留大多数 Windows 功能
- **Standard（标准）**：对大多数用户来说是个不错的折中
- **Advanced（高级）**：选中一组经过筛选、相对更安全的高级优化项。

## 安全提示

✅ **该做**：

- 在重大改动前创建还原点
- 套用前阅读优化项说明
- 从基础优化项开始
- 保持 Windows 更新
- 备份重要数据

❌ **别做**：

- 在不理解的情况下一次性套用全部优化项
- 跳过创建还原点
- 不做功课就使用高级优化项
- 无必要地禁用安全功能
- 在未经测试的情况下用于生产系统

## 首次运行故障排查

### 脚本下载不下来

如果启动命令失败：

- 确认 PowerShell 或 Terminal 是以管理员身份运行的。
- 确认电脑能联网，且能访问 `christitus.com`。
- 从普通的 PowerShell 会话重试，而不是受限的企业 shell 配置文件。
- 如果命令一启动就立刻关闭，请以管理员身份重新打开 Terminal 再运行一次，这样你才能看清错误输出。

如果仍然失败，请查看[已知问题](/knownissues/)页面。

## 下一步

现在你已经搭好了，去探索这些指南吧：

- [应用指南](../application/) —— 了解安装、升级和卸载软件
- [优化项指南](../tweaks/) —— 理解系统优化
- [FAQ](/faq/) —— 常见问题解答

## 获取帮助

如果你需要协助：

- **文档**：浏览本文档站点
- **已知问题**：查看[已知问题](/knownissues/)页面
- **Discord**：加入[社区 Discord 服务器](https://discord.gg/RUbZUZyByQ)
- **GitHub Issues**：在 [GitHub](https://github.com/ChrisTitusTech/winutil/issues) 上报告 Bug
- **YouTube**：观看[视频教程](https://www.youtube.com/watch?v=6UQZ5oQg8XA)

## 快速参考卡

| 任务 | 位置 | 操作 |
| ---- | -------- | ------ |
| 安装或升级应用 | Install 标签页 | 勾选复选框 -> Install/Upgrade Selected |
| 卸载应用 | Install 标签页 | 勾选复选框 -> Uninstall Selected |
| 套用优化项 | Tweaks 标签页 | 选择优化项 -> Run Tweaks |
| 撤销优化项 | Tweaks 标签页 | 选择优化项 -> Undo Selected Tweaks |
| 创建还原点 | Tweaks 标签页 | 基础优化项区域 |
| 修复网络 | Config 标签页 | Fixes -> Reset Network |
| 更换 DNS | Tweaks 标签页 | DNS 区域 |
| 打开控制面板 | Config 标签页 | 传统 Windows 面板 |
