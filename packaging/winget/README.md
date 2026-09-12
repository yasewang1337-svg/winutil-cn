# WinGet 分发清单归档

这里保存本仓库曾准备的 WinGet 清单。**现有文件属于 2026.7.7 历史版本，不代表当前最新版，也不表示已在 Microsoft 社区仓库上架。**

## 现有归档

| 字段 | 归档内容 |
| --- | --- |
| 目录 | [history/2026.7.7](history/2026.7.7/) |
| 包标识 | `Holha1337.WinUtilCN` |
| 清单版本 | `2026.7.7` |
| 原目标资产 | Release `cn-2026.07.07-5` 的 `WinUtil-CN.exe` |
| 类型与命令 | `portable`，命令名 `winutil-cn` |
| 提交、审核、上架状态 | 本次未核实，不据本地清单推断 |

本轮只移动原文件，保留其版本、URL、SHA256 和其他内容；没有生成新版候选，也没有向 Microsoft 提交。

| 文件 | 类型 |
| --- | --- |
| [Holha1337.WinUtilCN.yaml](history/2026.7.7/Holha1337.WinUtilCN.yaml) | 版本与默认语言索引 |
| [Holha1337.WinUtilCN.installer.yaml](history/2026.7.7/Holha1337.WinUtilCN.installer.yaml) | 旧资产 URL 与 SHA256 |
| [Holha1337.WinUtilCN.locale.en-US.yaml](history/2026.7.7/Holha1337.WinUtilCN.locale.en-US.yaml) | 默认语言元数据 |
| [Holha1337.WinUtilCN.locale.zh-CN.yaml](history/2026.7.7/Holha1337.WinUtilCN.locale.zh-CN.yaml) | 中文语言元数据 |

## 查阅或准备新版本

普通用户请从[本项目最新发布页](https://github.com/yasewang1337-svg/winutil-cn/releases/latest)下载中文版。

如果需要检查归档清单的格式，可在已安装 WinGet 的开发环境执行：

```powershell
winget validate --manifest packaging\winget\history\2026.7.7
```

这只是格式校验，不代表当前资产可下载、功能已验证或包已上架。

准备新版时，应新建独立的版本候选目录，依据实际发布标签、EXE 版本信息与下载文件的 SHA256 填写清单；不要覆盖历史版本后继续沿用旧哈希。完成本地校验和安装验证后，再单独处理外部提交。当前目录没有自动提交工作流。
