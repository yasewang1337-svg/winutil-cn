# WinUtil-CN 启动器

把编译好的中文版脚本 `winutil-cn.ps1` 打包成一个**离线自包含 EXE**，供不便使用命令行的用户双击运行，也作为 winget 收录所需的安装产物。

## 设计原则

| 原则 | 做法 |
|---|---|
| **自包含** | 脚本作为嵌入资源打进 EXE，运行时释放到临时目录执行——离线、不联网、不下载远程代码 |
| **透明** | 不加壳、不混淆、不用 `-EncodedCommand`；只做「释放脚本 → 调用系统 PowerShell → 清理」，尽量少触发杀软启发式 |
| **零依赖** | 用 Windows 自带的 .NET Framework 编译，产物在所有 Windows 10/11 上开箱即跑，无需安装运行时 |
| **可靠** | `app.manifest` 强制管理员权限（弹 UAC）；透传 `-Preset` / `-Config` 参数；等待退出、透传退出码、清理临时文件 |

## 文件

| 文件 | 作用 |
|---|---|
| `Launcher.cs`  | 启动器源码（C# 5 兼容，适配 Windows 自带旧版 csc 编译器） |
| `app.manifest` | 应用清单：强制管理员权限 + 声明 Windows 10/11 兼容性 |
| `build.ps1`    | 编译脚本：调用 `csc.exe` 把脚本嵌入并产出 `WinUtil-CN.exe` |

## 本地编译

```powershell
# 先有 winutil-cn.ps1（见 汉化\run-all.ps1，或从 Release 下载）
pwsh -File tools\launcher\build.ps1 -ScriptPath .\winutil-cn.ps1 -OutFile .\WinUtil-CN.exe
```

发布时由 `.github/workflows/release-cn.yaml` 自动完成编译、Defender 自检与附件上传。

## 关于杀毒误报

未签名的 EXE 可能被杀软误报，这是「未签名 + 调用 PowerShell」这一组合的通病，非本程序行为所致。缓解手段：代码签名（根治）、向厂商提交误报申诉、随发布附上 [VirusTotal](https://www.virustotal.com/) 多引擎扫描链接自证。源码完全公开，可自行审阅与复现编译。
