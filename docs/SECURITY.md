# 安全告警与发布验证

WinUtil CN 需要管理员权限来安装软件和修改系统设置。不能仅凭开源、文件名、数字签名或一次扫描通过认定文件安全，也不能在没有具体检测记录时认定“必然是误报”。

本轮火绒告警、本机构建阻断以及后续CI扫描与发布的不同结论，见[复核材料（未向厂商提交）](HUORONG-REVIEW.md)。

## 收到告警时

1. 保留杀毒软件名称、产品/病毒库版本、完整威胁名称、被拦截文件名、时间和发生步骤。区分下载 EXE、启动后释放的 PS1、具体功能下载的第三方文件。
2. 仅使用[本仓库发布页](https://github.com/yasewang1337-svg/winutil-cn/releases)的附件，选择同一个版本的文件与 `SHA256SUMS.txt`。
3. 对仍能读取的原始文件计算哈希；已被隔离时先使用告警详情中的哈希，不要为核对哈希关闭防护或恢复隔离文件：

   ```powershell
   Get-FileHash .\WinUtil-CN.exe -Algorithm SHA256
   Get-AuthenticodeSignature .\WinUtil-CN.exe | Format-List Status,StatusMessage,SignerCertificate
   Get-FileHash .\winutil-cn.ps1 -Algorithm SHA256
   ```

4. 与该版本的 `SHA256SUMS.txt` 核对。哈希相同只证明与发布附件一致；若不相同，停止使用该副本。`NotSigned` 表示尚未签名，不等于检测到病毒。
5. 在[错误反馈](https://github.com/yasewang1337-svg/winutil-cn/issues/new?template=bug_report.yaml)中附上上述信息。开发者先复核源码、构建记录及对应哈希，再向实际检测厂商提交复核。Defender 的文件复核入口是 [Microsoft Security Intelligence](https://www.microsoft.com/en-us/wdsi/filesubmission)；火绒等其他产品应使用该产品的官方误报反馈入口。

不要关闭 Defender、火绒、SmartScreen，或把 PowerShell、临时目录、整个项目加入排除项来解决告警。

## 三类常见拦截

| 提示 | 含义与处理 |
| --- | --- |
| 杀毒软件列出 Trojan、RiskTool、PUA 等具体名称 | 保留完整名称和文件哈希，按检测厂商流程复核；目前不能只凭名称断言误报。 |
| SmartScreen“Windows 已保护你的电脑”、未知发布者 | 与应用信誉/签名有关，和 Defender Antivirus 的病毒检测不是同一结论；核对发布来源、签名与策略。 |
| PowerShell 提示脚本未签名/禁止运行 | 属于执行策略；用 `Get-ExecutionPolicy -List` 查看原因，组织策略交由管理员处理，不改成 Bypass/Unrestricted。 |

下载的 PS1 可能带有互联网来源标记。`RemoteSigned` 会要求这类脚本有可信签名。启动器使用本地内嵌脚本及进程级 `RemoteSigned`，不修改机器或用户的持久执行策略；组织组策略仍然优先。如果策略要求签名，应使用可信签名产物或由组织管理员审批。

## 本轮行为调整

- 启动器改用 `RemoteSigned`，只调用系统绝对路径下的 PowerShell；释放的脚本在执行期间禁止被其他进程写入或替换。
- 本地脚本提权使用 `-File` 传参；非管理员的远程内存启动不再下载代码并提权执行。
- “禁用遥测”及其撤销操作保留现有 Defender 自动样本提交设置。新版不会自动修复旧版本已改动的设置，可在 Windows 安全中心查看现状并按自己的策略处理。
- “自动登录”按钮改为打开微软官方说明页，由用户了解影响后获取 Autologon，不再下载到临时目录后直接执行，也不自动接受其许可。
- 已安装的 Chocolatey 仍可用于管理软件；未安装时显示官方安装指引，并提示可使用默认 WinGet。PowerShell 配置安装入口改为打开上游指南，不再自动执行远程安装脚本。
- O&O 下载后必须通过 Authenticode 有效签名与 `O&O Software GmbH` 发布者检查；ViVeTool 固定 v0.3.4，先验证对应架构 ZIP 的 SHA256，再解压并逐文件复核。EXE、DLL 和数据文件的只读锁保持到工具退出。
- 两种工具每次使用独立的受保护目录，仅管理员和 SYSTEM 可写；下载、校验或启动失败立即中止，不复用旧文件。ViVeTool 同时核对退出码及固定版本的成功输出，错误和警告不会被当成完成。O&O 在后台准备并等待关闭，主窗口保持响应。
- 开始菜单配置与无人值守 FirstLogon 共用同一校验实现；FirstLogon 记录失败步骤并继续其他独立步骤，结束时提示部分失败。
- README 和上手指南改为先下载、核对哈希、再运行本地脚本。软件安装等明确选择的功能仍需联网，第三方安装器应单独核验。

这些修改减少不必要的风险行为，不保证某个杀毒引擎一定不再告警。

## 发布维护

第三方工具的校验实现位于 [Invoke-WinUtilVerifiedTool.ps1](../functions/private/Invoke-WinUtilVerifiedTool.ps1)。ViVeTool 哈希来自[官方 v0.3.4 发布](https://github.com/thebookisclosed/ViVe/releases/tag/v0.3.4)的实际下载，并与 [Microsoft WinGet 清单](https://github.com/microsoft/winget-pkgs/blob/master/manifests/t/thebookisclosed/Vive/0.3.4/thebookisclosed.Vive.installer.yaml)核对：

| 包 | SHA256 |
| --- | --- |
| IntelAmd | `CC27F073F3FE5DD2C3D947FAF558FD4B2F8E34454F812689B0D65EE8A52E4147` |
| SnapdragonArm64 | `30AD9A4912686355BFCE60E1D7BEF608735475B7E2160D67418EED8F5E3BA8C7` |

升级 ViVeTool 时需重新核对来源、哈希、文件清单与输出协议。v0.3.4 的 [Main/FinalizeSet](https://github.com/thebookisclosed/ViVe/blob/v0.3.4/ViVeTool/Program.cs) 在部分失败时仍退出 0，警告也可能伴随成功行，因此不能只看退出码或搜索“成功”。O&O 使用[官方滚动下载](https://www.oo-software.com/en/download/current/ooshutup10)，不固定会随版本变化的文件哈希；签名或发布者变动须人工核实，不自动放宽检查。

修改校验源码后运行 `tools/Sync-VerifiedToolTemplate.ps1`，再用 `-Check` 验证模板同步；编译器也会拒绝源码与模板不同的构建。隔离回归见 `pester/verified-tools.Tests.ps1`、`pester/verified-tool-integration.Tests.ps1` 和 `pester/oosu-ui.Tests.ps1`，不运行实际系统优化。

发布流水线分别扫描 EXE 与 PS1。检测到威胁、扫描器不可用或扫描未完成都阻止发布；生成 `security-scan.json` 记录扫描时间、病毒库信息、签名状态、文件 SHA256 和扫描输出。发布前再次核对哈希，保证扫描对象与附件一致。历史版本可能没有这个文件，以该版本实际附件为准。

后续引入代码签名时，应使用经过身份验证的发布者证书，先签 PS1，再把最终 PS1 嵌入 EXE，接着签 EXE，最后扫描、计算哈希并发布，签名后不再修改文件。当前没有配置可信发布者证书，不能把自签证书或填写 EXE 公司名称当作有效发布者身份。持续使用同一签名身份有助于信誉积累，签名不能保证消除杀毒或 SmartScreen 提示。

参考：[微软开发者检测复核 FAQ](https://learn.microsoft.com/en-us/defender-xdr/developer-faq)、[SmartScreen 应用信誉](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)、[PowerShell 执行策略](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)。
