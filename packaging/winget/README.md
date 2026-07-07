# winget 上架清单

用于把 WinUtil-CN 提交到 [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) 的 manifest。

| 字段 | 值 |
|---|---|
| 包标识（PackageIdentifier） | `Holha1337.WinUtilCN` |
| 版本 | `2026.7.7` |
| 安装类型 | `portable`（自包含 EXE，无需真正安装） |
| 安装后命令 | `winutil-cn` |
| 指向资产 | Release `cn-2026.07.07-5` 的 `WinUtil-CN.exe` |

## 文件

| 文件 | 类型 |
|---|---|
| `Holha1337.WinUtilCN.yaml`             | version（默认语言 en-US） |
| `Holha1337.WinUtilCN.installer.yaml`   | installer（URL + SHA256） |
| `Holha1337.WinUtilCN.locale.en-US.yaml`| defaultLocale（英文，moderator 期望的默认） |
| `Holha1337.WinUtilCN.locale.zh-CN.yaml`| locale（中文语言包） |

## 本地校验

```powershell
winget validate --manifest packaging\winget
# 可选：真机安装测试（会注册 portable 包，可 winget uninstall 撤销）
winget install --manifest packaging\winget
```

## 提交

推荐用官方工具 [wingetcreate](https://github.com/microsoft/winget-create)：

```powershell
winget install wingetcreate
wingetcreate submit --token <GitHub-PAT> packaging\winget
```

或手动：fork winget-pkgs → 放到 `manifests/h/Holha1337/WinUtilCN/2026.7.7/` → 提 PR。

## 更新版本

每次发新版：改 `PackageVersion`、`InstallerUrl`（指向新 Release tag）、`InstallerSha256`，重新校验并提交。SHA256 见对应 Release 说明或 CI 日志。

> ⚠️ 注意：winget-pkgs 由 Microsoft 人工审核。系统修改类工具、上游未上架的分支、未签名 EXE 都可能被审核质疑或要求改动——过审与否不完全可控。
