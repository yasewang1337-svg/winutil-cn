# 上游历史工具与配置

这里保存从上游沿用的旧工具文本，供维护者追溯。文件追加 `.txt`，避免被当作当前中文启动或签名入口执行；原始内容保留不变。

| 归档文件 | 原名与用途 | 当前中文项目入口 |
| --- | --- | --- |
| [windev.ps1.txt](windev.ps1.txt) | 原名 `windev.ps1`，从 ChrisTitusTech 上游仓库查询标签、下载并执行上游脚本；不是本地中文开发版本 | 从源码运行 [汉化/run-all.ps1](../../汉化/run-all.ps1) 构建；普通使用从本项目发布页下载 |
| [sign.bat.txt](sign.bat.txt) | 原名 `sign.bat`，使用 `CT Tech Group LLC` 证书身份调用 signtool 的上游签名示例 | 当前中文 EXE 构建使用 [tools/launcher](../launcher/README.md)，此文件不参与发布 |
| [upstream-docs-CNAME.txt](upstream-docs-CNAME.txt) | 原位置 `docs/static/CNAME`，记录上游文档站域名，仅供历史对照 | 已退出静态发布目录；中文文档与站点身份见 [docs/README.md](../../docs/README.md) |

本目录不存放当前可执行维护命令，也不证明中文项目拥有上游签名证书。需要修改构建流程时，从[维护说明](../../docs/MAINTENANCE.md)和当前工作流开始。
