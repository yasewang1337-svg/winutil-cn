# 火绒检测复核材料（尚未向厂商提交）

此文档整理已公开的项目资料与去除个人路径的告警摘要，尚未向火绒提交。用户原始日志仅保留本地，不随仓库发布。

## 2026-10-09：31 版发布附件被火绒删除（已确认）

用户补充的三条原始告警与本次核验命令对应，已明确此前“拒绝访问”的原因：火绒检测并删除文件。

| 项目 | 已核实内容 |
| --- | --- |
| 检测名称 / ID | `TrojanDownloader/PS.Netloader.lr` / `2905791205BCC50A`；ID不是文件哈希 |
| 对象 | `cn-2026.10.09-31/winutil-cn.ps1` 发布附件，以及工作区根目录原有的 `winutil.ps1`、`winutil-cn.ps1` |
| 处理结果 | 三条均为“已处理，删除文件” |
| 触发上下文 | Codex 调用 PowerShell 7，执行 `Get-FileHash -LiteralPath ... -Algorithm SHA256` 核对文件；没有以目标PS1为入口执行WinUtil功能 |
| 发布来源 | [31版](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.10.09-31)，源码 `5844369d49482bd2162568333810d02b1d6bfa7a` |
| 发布PS1身份 | 710651字节；GitHub资产digest、校验清单及扫描报告中的SHA256为 `BBEE00E5724FF8383C277EFDC9D5F32DA2BEBDCC4AF369ED20A89F0C26E802FD`；由于本机读取被拦，不能称为本机独立PS1实测哈希 |
| 尚缺信息 | 本次日志未包含告警时间、当前火绒客户端和病毒库版本；不沿用9月旧值 |

`Get-FileHash` 用于读取文件内容并计算哈希，见[微软说明](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash)。本次发布核验设置了 `$ErrorActionPreference = 'Stop'`，在附件哈希循环中读取PS1失败，未进入后续静态验证脚本。根目录核验命令也只查询哈希。因此，日志的“操作类型：执行”不能单独证明目标脚本的功能代码已经执行。现有资料也不足以区分火绒内部的具体扫描通道或命中特征。

### 与30版的源码对照

- 比较已发布源码 `b10def3` → `5844369`：共享下载校验 `Invoke-WinUtilVerifiedTool.ps1`、O&O入口、`scripts/start.ps1`、`tools/launcher/Launcher.cs` 及无人值守模板均未变化。31版涉及的运行源码主要为后台任务状态、更新修复范围、软件包映射、固定SID及OneDrive路径。
- O&O仍要求有效签名及预期发布者；ViVeTool仍固定官方版本SHA256，并保留执行期间文件锁。远程清单仍按JSON解析并验证已有项目ID，不把清单当PowerShell执行。
- `Invoke-WPFButton.ps1` 的 `Invoke-Expression` 处理内置功能配置，并非本次核验命令从互联网下载后执行的内容。这个语法存在本身不能证明恶意，也不能证明它就是火绒命中的位置。
- 本次旧文件和31版附件均被同名、同ID检测；这不足以把告警归因于31版新增代码。检测名/ID相同也不能证明文件字节或实际命中位置相同。

[31版CI](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37923206300)完成PS5.1/7各337项回归、构建和双产物Defender扫描。EXE、校验清单和扫描报告的本地哈希与GitHub digest一致；仅对EXE内嵌资源计算哈希，也与发布PS1 digest一致。上述证据没有替代被拦PS1的本地验证，不能证明火绒误报或用户环境已感染。

原始证据保存在 `.artifacts/update-audit-20261009/huorong-user-report-20261009.txt`，首条命令行在用户提供的文本中被截断；完整核验命令及读取失败另有本次操作记录对应。此轮仅补充证据与文档，没有重下被拦文件、恢复隔离、调整防护或修改运行代码以试探放行条件。下一步是由厂商结合上述发布样本身份复核检测结果；尚未向厂商发送。

## 2026-09-20：历史告警（整改前）

- 项目：WinUtil CN，公开源码 https://github.com/yasewang1337-svg/winutil-cn 。
- 当时维护基线：`eb57d18`；当时本地安全整改尚未发布。
- 告警时间：2026-09-20 05:58:54、06:04:04、06:14:17（三次构建，均由用户导出的原始日志确认）。
- 产品：火绒安全，病毒防护 → 文件实时监控。05:59:00 更新记录显示版本为 `6.0.12.1`，病毒库时间 `2026-09-19 19:44`；其后两次构建仍出现上述检测。
- 检测名：`TrojanDownloader/PS.Netloader.lr`。
- 病毒 ID：`2905791205BCC50A`。这是日志中的检测 ID，不是文件 SHA256。
- 对象：临时构建目录中的 `winutil.ps1`；结果为“已处理，删除文件”。
- 操作进程：PowerShell 7 的 `pwsh.exe`，当时执行项目的中文构建和校验命令。
- 原始日志由用户提供，保存于工作区 `.artifacts/security-huorong-alert.txt` 与 `.artifacts/security-huorong-alert-888.txt`；外发前需去除其中的个人路径。
- 新日志还确认：05:52:48 旧 `functions/public/Invoke-WPFPanelAutologin.ps1` 被单独检测为 `HEUR:TrojanDownloader/PS.NetLoader.bv`（ID `D058C0522D9803AD`）并删除。这是已改为官方说明入口的旧实现；单个旧函数的告警不证明它是后续整个脚本被检测的唯一原因。

## 复现与范围

1. 在工作区执行 `pwsh -NoProfile -File 汉化/run-all.ps1`。
2. 构建工具在临时副本中合并配置、函数和界面，生成 UTF-8 BOM 的中文 PS1，并检查语法。
3. 第一轮输出记录为 686,645 字节；随后读取产物失败，火绒日志确认将该临时 PS1 删除。
4. 移除剩余 Chocolatey/PowerShell 配置远程脚本执行入口后，再次构建记录为 686,752 字节，读取产物仍被拒绝。新导出的日志确认：06:04:04 火绒仍以 `TrojanDownloader/PS.Netloader.lr` 检测并删除同一临时路径的产物。
5. 2026-09-20 06:14 按用户要求对当前源码再次构建，生成686,767字节脚本后，仍在 `汉化/run-all.ps1:43` 读取临时产物时得到 `UnauthorizedAccessException`，未进入 EXE 打包。构建日志保存在 `.artifacts/security-rebuild-20260920-061415.log`；用户新提供的 `888.txt` 中06:14:17事件的临时路径、操作命令和时间完全对应，确认是火绒以相同检测名主动删除文件。
6. 06:44完成 O&O/ViVeTool 完整性及失败传播修复后正常构建：709,872字节临时PS1通过语法检查，随后读取仍被拒绝访问，未进入EXE打包。证据见 `.artifacts/security-fix/build.log`、`build-result.json`。本次尚无新的火绒导出事件，当前只能确认构建受阻，不能把前三次检测名直接视作这一次已核实的检测结论。

此过程没有启动 WinUtil 图形应用，也没有执行系统优化、安装、卸载或配置恢复。日志中“操作类型：执行”是火绒的事件分类，不代表已执行生成脚本中的优化功能。

上述被删除产物未能取得 SHA256，未恢复隔离文件。当时根目录EXE仍是旧发布版，两份旧PS1在06:44读取检查时也被拒绝访问，随后复查已不存在；不能用旧版哈希代替这些被拦截样本的哈希。后续已按用户要求从CI生成并交付新版，见下一节。

## 后续正式发布与验证

安全修复通过 [PR #11](https://github.com/yasewang1337-svg/winutil-cn/pull/11) 合并至 `b10def37204eb7651bb11582d74ba3acd7195d2b`，[正式CI](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/35474785713) 正常构建并发布 [cn-2026.09.19-30](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.09.19-30)。PS5.1/PS7各311项回归、启动器无害夹具及产物检查通过；两个最终产物均完成Defender按需扫描，未检出威胁。

发布附件提供 `SHA256SUMS.txt` 和 `security-scan.json`：EXE哈希 `D7737684A391DF17EA04A42E407A53440556D295E151B64AFB554FFA3853894B`，PS1哈希 `28B59D90E28B729A6F4A74D489D10ECE67FC6C34A44AD1597BA7B1E51DE09237`。当时已下载核对GitHub资产digest、校验和及EXE内嵌脚本一致性，并同步到工作区；交付时附件能在本机读取。后续10月再次核验发生火绒删除，不能把9月可读作为当前放行证据。

这是一次明确的CI扫描通过和交付记录，**不是火绒已经放行的结论**。没有关闭防护、设置排除或恢复隔离样本；尚未对新版本执行真实系统优化，也没有向火绒提交复核。

## 已实施的源码整改

- 启动器及本地提权入口移除 `ExecutionPolicy Bypass`，改用进程级 `RemoteSigned`；本地提权用 `-File` 传参。
- 非管理员的远程内存启动不再下载脚本后提权执行。
- 启动器只调用系统 PowerShell 路径；释放脚本在持有只读锁后校验内嵌资源哈希，执行期间禁止写入或替换。
- 遥测设置及撤销操作不再修改 Defender 自动样本提交选项。
- 自动登录和 PowerShell 配置入口改为官方说明页；缺失 Chocolatey 时提供手动安装指引，不再下载并直接执行其初始化脚本。默认 WinGet 流程保留。
- 发布检查同时扫描 EXE 和 PS1；扫描失败或不可用时中止，保存哈希、签名、病毒库与扫描输出。

没有采用关闭安全防护、添加排除项、改后缀、混淆、加密或打包躲避检测的处理。

## 本地源码复核（2026-09-20，以下为修复前的发现）

此前整改没有覆盖全部下载执行入口。“其余只能等待杀毒厂商修规则”的判断过早。下表保留修复前证据及当时行号，后续已按用户要求完成这些入口的代码整改（见下方），不能再把表中的问题当作当前行为。下面的风险不是对火绒内部命中特征的推断，也不证明上游下载站或工具已经被入侵。

| 优先级 | 位置 | 已确认的问题 |
| --- | --- | --- |
| 高 | [Invoke-WPFOOSU.ps1](../functions/public/Invoke-WPFOOSU.ps1)，5–6行 | 固定厂商 HTTPS 地址下载 EXE 到固定临时路径后直接启动，没有签名、发布者或已固定哈希校验，也没有执行期间的文件保护。运行在 WinUtil 的管理员进程上下文。 |
| 高 | [tweaks.json](../config/tweaks.json)，77行；配置中的反向脚本在80行 | ViVeTool 下载 ZIP、解压后直接运行，无哈希/签名检查。下载和解压的非终止错误不会阻止后续启动；使用固定相对路径，可能继续使用旧文件。未读取子进程退出码仍打印完成文案。 |
| 高 | [autounattend.xml](../tools/autounattend.xml)，456–462行 | 安装镜像模板的 FirstLogon.ps1 同样下载、解压并运行 ViVeTool，使用固定临时目录且合并解压；缺失完整性校验和失败即停处理。这一分支在使用生成镜像安装 Windows 后首次登录时自动运行，不能只修改界面按钮就算覆盖。 |

### 无害模拟与证据

- O&O：`.artifacts/security-review/Review-OOSU.ps1` 先替换下载、启动及校验命令，再加载被审查函数。PowerShell 5.1 和7均观察到“下载返回 → 尝试启动”，没有签名或哈希校验。结果保存在同目录 `oosu-ps51.json`、`oosu-ps7.json`。
- ViVeTool：`.artifacts/security-review/Test-ViveFailureSimulation.ps1` 使用真实配置片段、AST 命令白名单及副作用替身。两引擎各检查9种组合（配置正向、反向、FirstLogon × 下载非终止错误、解压非终止错误、模拟进程退出19），18种均未报告失败；两种前置失败仍到达启动替身，配置分支仍输出完成文案。实际未下载文件、未启动 ViVeTool、未修改系统。证据为同目录 `vive-failure-summary.json`、`vive-failure-ps7.log`、`vive-failure-ps51-remotesigned.log`，汇总包含输入SHA256。
- 单测通过只说明已有测试覆盖的行为，没有覆盖上述缺口。该诊断用于证明错误传播和验证缺失，不通过删减脚本、改名或修改特征来寻找杀毒放行条件。

### 已排除的误读

- [Compile.ps1](../Compile.ps1) 只有显式传 `-Run` 才会执行产物；本任务各次失败构建都没有传该参数。告警不等于已经执行了系统优化功能。
- 同一编译器会把所有函数、配置脚本和完整无人值守 XML 打入 PS1，未点击功能也不代表下载执行代码不在文件里。首次删除旧自动登录下载代码时，表中的几处仍保留；现已按上述共享校验实现整改。
- [Invoke-WPFImpex.ps1](../functions/public/Invoke-WPFImpex.ps1) 第27–51行把远程配置解析为 JSON，并校验为已有项目 ID 的字符串数组；不是把远程 JSON 当作 PowerShell 执行。内置配置中的动态脚本执行也不能仅凭 `Invoke-Expression` 字样认定恶意。
- Adobe hosts 功能下载的是文本映射数据，不是远程脚本执行；不过未经条目限制就追加系统 hosts，仍有来源和意外重定向风险。
- ViVeTool 的 `UndoScript` 确实存在于产物中，但当前普通“恢复记录”走历史恢复函数，不应把它描述为一定会从恢复按钮触发。

### 修复顺序

1. 为第三方可执行文件建立明确的信任检查：固定版本/可信哈希，或校验有效签名及预期发布者；[Get-AuthenticodeSignature 官方说明](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-authenticodesignature)可作为实现依据。校验失败就停止。
2. 下载、解压失败立即中止；每次使用独立工作目录，拒绝复用旧 EXE，检查进程退出码。校验完成到启动期间也应防止文件被替换。
3. 同时修复界面配置和安装镜像模板，避免只修一条入口。再做安全功能回归、正常构建和完整产物扫描。

最初复核仅增加诊断证据；随后用户要求“修复”，已修改上述业务实现，仍未向厂商提交。

### 后续代码修复

- 新增共享校验入口：O&O 要求有效 Authenticode 签名及精确发布者；ViVeTool 固定两架构官方包 SHA256，核对文件清单及解压后的每个文件。
- 每次创建仅管理员/SYSTEM 可写的独立目录，EXE/DLL等持有只读锁至进程退出；错误即停，清理仅限本次目录，不复用旧包。
- ViVeTool v0.3.4 可能设置失败仍退出0，故额外核对其完整正常输出，拒绝警告和缺少确认的结果；普通非零退出码同样报告失败。
- GUI apply/undo 与 FirstLogon 调用同一实现；新增模板同步工具及编译漂移检查。FirstLogon 失败会写日志及最终部分失败提示。
- O&O 后台执行保持界面响应，重复点击被阻止，错误通过中文弹窗反馈。

来源、固定哈希和维护方法见 [安全说明](SECURITY.md)。本轮原始下载仅用于核验哈希/签名，没有运行下载的工具；实际文件读锁、签名查询、ZIP校验及无害进程重定向另做了双引擎隔离检查。具体回归与构建结果记录于 WORKSTATE.md 及 `.artifacts/security-fix/`，不以软件测试替代安全产品复核。

## 希望厂商复核的问题

请核对上述检测是否针对本开源工具的具体危险行为，或属于误报。如属误报，请告知需要提供的准确样本及安全提交方式；如存在具体风险，请说明涉及的函数或行为，以便继续修复。

目前已确认历史构建告警，以及31版发布附件在哈希核验时被火绒检测并删除，尚不能确认具体命中特征或断言误报。31版双PowerShell各337项隔离测试、启动器无害夹具与Defender扫描通过，均不能代替火绒的检测或厂商复核。

提交入口请从火绒安全客户端的“问题反馈 / 病毒上报”进入官方渠道，参见[火绒官方用户手册](https://cdn-www.huorong.cn/Public/Uploads/uploadfile/files/20260512/%E7%81%AB%E7%BB%92%E5%AE%89%E5%85%A8%E8%BD%AF%E4%BB%B6%206.0%20%E7%94%A8%E6%88%B7%E6%93%8D%E4%BD%9C%E6%89%8B%E5%86%8C%EF%BC%886.0.10.0%E7%89%88%E6%9C%AC%EF%BC%89.pdf)。
