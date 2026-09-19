# WinUtil-CN 启动器

把编译好的中文版脚本 `winutil-cn.ps1` 打包成一个**离线自包含 EXE**，供不便使用命令行的用户双击运行，也作为 winget 收录所需的安装产物。

## 设计原则

| 原则 | 做法 |
|---|---|
| **自包含** | 脚本作为嵌入资源打进 EXE，运行时释放到临时目录执行——离线、不联网、不下载远程代码 |
| **透明** | 不加壳、不混淆；只做「释放脚本 → 调用系统 PowerShell → 清理」，采用进程级 `RemoteSigned`，不修改持久执行策略 |
| **零依赖** | 目标 net48：.NET Framework 4.x 在所有 Windows 10/11 上预装，产物开箱即跑、无需安装运行时 |
| **现代工具链** | 用最新 .NET SDK 的 Roslyn 编译器（`LangVersion=latest` → 最新 C#），SDK 风格 `.csproj` 工程 |
| **可靠** | `app.manifest` 强制管理员权限（弹 UAC）；透传 `-Preset` / `-Config` 参数；等待退出、透传退出码、清理临时文件 |
| **完整性** | 释放脚本后持有只允许共享读取的文件句柄，直到子进程退出；仅调用系统目录内的 PowerShell，不回退 PATH |

目标 net48 是为了复用 Windows 自带的 .NET Framework 运行环境。框架选择不代表杀毒检测结论；每个发布产物仍需独立扫描。64 位系统优先使用 64 位进程。

## 文件

| 文件 | 作用 |
|---|---|
| `Launcher.cs`                | 启动器源码（现代 C#：文件级命名空间、可空注解、集合表达式等） |
| `WinUtilCN.Launcher.csproj`  | SDK 风格工程：目标 net48、嵌入脚本、元数据、net48 引用包 |
| `app.manifest`               | 应用清单：强制管理员权限 + 声明 Windows 10/11 兼容性 |
| `build.ps1`                  | 编译脚本：`dotnet build` 把脚本嵌入并产出 `WinUtil-CN.exe` |

## 本地编译

```powershell
# 先有 winutil-cn.ps1（见 汉化\run-all.ps1，或从 Release 下载）
pwsh -File tools\launcher\build.ps1 -ScriptPath .\winutil-cn.ps1 -OutFile .\WinUtil-CN.exe
```

需要 [.NET SDK](https://dotnet.microsoft.com/download)（任意现代版本，≥ .NET 8 即可；越新支持的 C# 语法越全）。

发布时由 `.github/workflows/release-cn.yaml` 自动完成编译、EXE/PS1 分别扫描及附件上传。扫描未完成或检测到威胁都会中止发布，`security-scan.json` 保存对应哈希、签名和扫描证据。

`tools/Test-Launcher.ps1` 在临时副本中构建只内嵌无害参数回显脚本的启动器，再通过反射验证文件锁、参数及退出码；不启动正式应用、不触发 UAC。

## 关于杀毒误报

当前没有配置可信发布者签名。未签名、应用信誉、脚本行为都可能影响检测，但没有具体告警记录不能确定原因。可信代码签名有助于确认发布者及积累信誉，不能保证消除告警；多引擎扫描也不是安全证明。

详细的哈希核对、告警分类、厂商复核和后续签名顺序见[安全告警说明](../../docs/SECURITY.md)。不得通过关闭防护、添加排除项、混淆或改变打包方式来躲过检测。
