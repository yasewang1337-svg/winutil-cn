---
title: 用户指南
weight: 2
breadcrumbs: false
cascade:
  type: docs
  params:
    reversePagination: false
    breadcrumbs: false
---

欢迎来到 **Winutil** 官方用户指南——你的 Windows 一体化工具箱。

> [!IMPORTANT]
> Winutil 不支持 Windows 10。Windows 10 已于 **2025 年 10 月 14 日**结束支持。

## Winutil 是什么？

Winutil（Chris Titus Tech 的 Windows 实用工具）是一款基于 PowerShell 的综合性工具，帮你：

- **安装应用**：无需手动下载，快速安装热门软件
- **套用优化项**：为性能、隐私和易用性优化 Windows
- **修复问题**：一键排查常见的 Windows 故障
- **管理更新**：掌控 Windows 更新的方式与时机
- **访问工具**：快速打开 Windows 面板和实用程序

## 谁适合用 Winutil？

Winutil 是为以下人群设计的：

- **家庭用户**：想优化自己个人电脑的人
- **高级用户**：想对 Windows 做精细控制的人
- **IT 专业人士**：高效管理多台系统的团队
- **游戏玩家**：为游戏性能优化系统的用户
- **注重隐私的用户**：想减少遥测和数据收集的人
- **开发者**：搭建干净开发环境的用户

## 快速上手

第一次用 Winutil？按顺序跟着下面的指南走，就能快速上手：

1. **[快速上手](getting-started/)** —— 了解如何启动 Winutil，并掌握基础操作。
2. **[应用](application/)** —— 轻松安装、更新和移除应用。
3. **[优化项](tweaks/)** —— 套用性能、隐私和易用性方面的改进。
4. **[功能](features/)** —— 探索内置工具和常见的 Windows 修复。
5. **[更新](updates/)** —— 配置系统上 Windows 更新的行为方式。
6. **[自动化](automation/)** —— 自动化配置，并在多台电脑之间复用。
7. **[Win11 创建器](win11creator/)** —— 构建一份自定义的、已瘦身的 Windows 11 ISO。

## 主要功能

### 应用安装

浏览并一键安装数百款热门应用。再也不用四处找下载链接，或应付安装包里的捆绑软件。

**[阅读应用指南 →](application/)**

### 系统优化项

套用性能、隐私和易用性方面的优化。从预设配置中选择，或自定义单独的优化项。

**[阅读优化项指南 →](tweaks/)**

### 配置与修复

针对常见 Windows 问题的快速修复：
- 重置网络设置
- 修复 Windows 更新问题
- 修复系统文件
- 访问传统 Windows 面板

**[阅读功能指南 →](features/)**

### 更新管理

掌控 Windows 更新，可选：
- 启用/禁用更新
- 仅安全更新
- 暂停更新
- 管理驱动更新

**[阅读更新指南 →](updates/)**

### 自动化

自动化 Winutil 配置，用于：
- 多台电脑的搭建
- 企业部署
- 一致的配置
- 脚本化安装

**[阅读自动化指南 →](automation/)**

### Windows 11 创建器

构建一份自定义 Windows 11 ISO：移除捆绑软件、禁用遥测、绕过硬件要求检查。你还可以把它导出为 ISO 文件，或直接写入 U 盘。

**[阅读 Win11 创建器指南 →](win11creator/)**

## 安全与最佳实践

使用 Winutil 之前：

✅ **务必**：
- 以管理员身份运行 PowerShell
- 在重大改动前创建系统还原点
- 在套用前弄清楚每个优化项的作用
- 先从基础优化项开始，再考虑高级的
- 保留重要数据的备份

❌ **切勿**：
- 在不理解的情况下套用全部优化项
- 跳过创建还原点
- 在未经测试的情况下用于生产系统
- 无必要地禁用安全功能

## 系统要求

- **操作系统**：Windows 11
- **PowerShell**：5.1 或更高版本（Windows 11 已内置）
- **权限**：需要管理员访问权限
- **网络**：下载应用和更新时需要
- **.NET Framework**：4.5+（通常已预装）

## 获取帮助

需要帮助？

- **文档**：你正在读的就是。请使用导航菜单。
- **FAQ**：查看[常见问题](../faq/)
- **已知问题**：查看[已知问题](../knownissues/)
- **Discord**：加入[社区 Discord](https://discord.gg/RUbZUZyByQ)
- **GitHub**：在 [GitHub Issues](https://github.com/ChrisTitusTech/winutil/issues) 上报告 Bug
- **YouTube**：观看[视频教程](https://www.youtube.com/watch?v=6UQZ5oQg8XA)

## 参与贡献

想帮忙改进 Winutil？

- **报告 Bug**：在 GitHub 上提交 Issue
- **建议功能**：发起功能请求
- **贡献代码**：提交 Pull Request
- **改进文档**：帮助扩充本文档
- **分享知识**：在 Discord 上帮助他人

**[阅读贡献指南 →](../contributing/)**

## 视频教程

观看完整的 Winutil 概览：

{{< youtube id=6UQZ5oQg8XA loading=lazy >}}

准备好开始了吗？前往 **[快速上手指南](getting-started/)**。

## 下一步

直接进入下面这一节开始上手：

{{< cards >}}
  {{< card link="getting-started" title="快速上手" icon="document-text" subtitle="学习如何使用 Winutil。" >}}
{{< /cards >}}
