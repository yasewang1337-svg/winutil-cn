---
title: 功能
weight: 5
prev: /userguide/tweaks/
next: /userguide/updates/
---

用 **Features（功能）** 和 **Fixes（修复）** 两个区域，来安装可选的 Windows 组件，并运行常见的修复任务。

本页对应 Winutil 中的 **Config（配置）** 标签页。有些操作会立即完成，另一些则可能弹出提示、从微软下载文件，或需要重启后改动才完全生效。

{{< image src="images/config-tab-new" alt="包含功能与修复的配置标签页" >}}

## Windows 功能

勾选功能复选框并点击 **Install Features（安装功能）**，即可安装常见的 **Windows 功能**。

如果某项功能依赖 Windows 安装介质或可选下载，Windows 可能需要更长时间才能完成，或请求重启。

* 全部 .NET Framework（2、3、4）
* Hyper-V 虚拟化
* 传统媒体组件（WMP、DirectPlay）
* NFS —— 网络文件系统
* 启用每日注册表备份任务（凌晨 12:30）
* 启用传统 F8 启动恢复
* 禁用传统 F8 启动恢复
* 适用于 Linux 的 Windows 子系统（WSL）
* Windows 沙盒

## 修复

用这些一键修复来解决常见的系统问题。

请在你有具体问题需要纠正时使用，而不是作为日常清理步骤。

* 设置自动登录
* 重置 Windows 更新
* 重置网络
* 系统损坏扫描
* 重装 WinGet

## 传统 Windows 面板

直接从 Winutil 打开老式的 Windows 面板。可用面板包括：

* 控制面板
* 网络连接
* 电源面板
* 区域
* 声音设置
* 系统属性
* 用户账户

## 远程访问

在你的 Windows 机器上启用 OpenSSH 服务器，以便远程访问。

只有当你确实打算使用远程 shell 访问时才启用它。开启后，在把机器暴露给其他设备之前，先核查你的防火墙规则和账户权限。
