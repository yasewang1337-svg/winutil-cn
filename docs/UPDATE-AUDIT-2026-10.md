# 2026-10 更新调查与实施清单

调查日期：2026-10-09（Asia/Taipei）。范围覆盖中文桌面版、官方上游、软件目录、MCP npm 包、依赖、测试、文档和 GitHub 维护。按真实影响安排顺序，区分已复现问题、代码差距与产品建议。

## 当前基线

| 对象 | 核对结果 |
| --- | --- |
| 中文仓库调查起点 | `98895c1`；当时本地与远端 main 一致，工作区干净 |
| 调查开始时最新桌面版 | [cn-2026.09.19-30](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.09.19-30)，源码 `b10def3`；已包含下载校验、启动器保护及逐产物扫描 |
| 官方上游 | [26.10.07](https://github.com/ChrisTitusTech/winutil/releases/tag/26.10.07)，`07ccd8e`；调查时 main 同一提交 |
| 上游历史差异 | 共同祖先 `58a81b1` 后 223 次提交、433 个变化文件；相较上次核对的 26.08.19 又增 53 次提交、188 个变化文件 |
| 独立 npm 包 | [winutil-cn-mcp 0.3.0](https://registry.npmjs.org/winutil-cn-mcp/0.3.0)，2026-07-09 发布；与桌面版分开分发 |
| GitHub 待办 | [#5 上游同步](https://github.com/yasewang1337-svg/winutil-cn/issues/5)、[#6 启动报错复测](https://github.com/yasewang1337-svg/winutil-cn/issues/6)仍开放；调查时没有开放 PR |

223 次提交不是 223 个未修复问题。上游后台任务重构单项涉及 122 个文件，Hugo → Astro 迁移涉及 178 个文件，不能整体覆盖中文分支已有的操作计划、设置历史、中文组合及 30 版下载安全机制。

## 本轮实施的明确修复

| 问题与影响 | 本轮处理 | 验证边界 |
| --- | --- | --- |
| 普通“修复 Windows 更新”清空全局 Policies、WindowsSelfHost、GroupPolicy，并重置系统安全模板，超出更新功能范围；“默认更新设置”也重置安全模板 | 删除这些越界操作及误导性完成语句，不转移到 Aggressive 模式。仍有具体更新策略和组件操作，不能视为完整、可恢复的系统默认重置 | 对两个入口做危险命令语义检查；没有在主机执行修复。统一确认、快照和逐项结果仍待改造 |
| Windows 功能安装或已安装软件扫描抛错后，忙状态不释放，后续操作和正常关闭被阻止；后台启动前还有重复派发窗口 | 主线程先预留任务状态；派发、任务和 UI 回调异常都释放；失败报告错误；修正功能进度分母并固定本次选择 | 双 PowerShell 无害模拟验证失败、重复点击、UI 失败和再次执行；真实系统功能安装仍需测试机验收 |
| 6 处 ACL 命令使用英文 Everyone/Administrators，在本地化 Windows 上可能解析失败 | 按[上游 #5045](https://github.com/ChrisTitusTech/winutil/commit/87dd6431764f31956b9f0fd3ae05dbd4ecf9f170)改为固定 SID，应用与撤销成对修改 | 提取命令并捕获参数，验证中文/空格路径，不实际修改权限 |
| OneDrive 卸载器固定在 C 盘 | 按[上游 #4864](https://github.com/ChrisTitusTech/winutil/commit/7d1a03dcc9c1f04662142dba4e837ec4ccbf0e05)改用 SystemRoot | 验证非 C 盘参数，不实际卸载 |
| 4 个 .NET Desktop Runtime 条目在 Chocolatey 路径安装普通 Runtime，不能满足桌面框架需求 | 将 6/8/9/10 的映射修为 `dotnet-X.0-desktopruntime`，不改软件键或 WinGet ID | 已核对[公开包](https://community.chocolatey.org/packages/dotnet-8.0-desktopruntime)及维护源的 windowsdesktop 安装器类型；配置与计划回归，不等于真实安装验收 |
| 同步下载校验模板时，PS5.1 的 `-File ... -Check` 默认参数解析失败；相对路径可能不随 PowerShell 当前目录解析 | 默认值移入脚本正文，显式解析路径，保留直接执行所需 UTF-8 BOM | 从另一目录启动子进程核对默认参数、相对夹具、内容不一致及只读检查不写入 |

实现位置：`functions/public/Invoke-WPFFixesUpdate.ps1`、`Invoke-WPFUpdatesdefault.ps1`、`Invoke-WPFFeatureInstall.ps1`、`Invoke-WPFGetInstalled.ps1`，`config/tweaks.json`、`config/applications.json`，`tools/Sync-VerifiedToolTemplate.ps1`。本轮属于选择性修复，不代表完整同步上游。

## 接下来优先处理的可靠性缺口

| 优先级 | 已确认的缺口 | 建议交付范围及通过条件 |
| --- | --- | --- |
| P1：MCP 独立执行与发布 | npm 0.3.0 的 SHA512 已核验，包内快照仍直接下载并运行未校验的 ViVeTool；当前源码重新打包也缺校验函数上下文。模拟缺函数/服务错误时仍可能报告 `applied`；换源没有确认，临时脚本未清理 | 先限制修改能力并建立独立受限执行器：准确失败结果、确认、受验证下载、临时文件清理。补握手/只读/预览/失败/干净离线打包测试后再发布；当前使用建议见 [MCP README](../mcp/README.md)，本轮没有更新 npm |
| P1：启动盘写入顺序与成功判定 | `Invoke-WinUtilISOUSB.ps1` 先 diskpart clean，后检查容量；忽略 robocopy 返回码后显示成功。当前只读代码证实，未执行磁盘操作 | 擦除前核验源文件、容量/FAT32上限、设备稳定身份与系统盘标志；逐阶段停止错误，正确处理复制返回码，核对启动文件。在可销毁虚拟磁盘上验证容量不足、设备变化、复制失败 |
| P1：SSH 管理员密钥 | 当前修改管理员 Match 块并使用用户目录 authorized_keys；上游已修复路径及权限配置 | 适配[上游 #4936](https://github.com/ChrisTitusTech/winutil/commit/9fdadd1c8f5c58ccf03f7bf2fc735474ca176783)，按[微软要求](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement)区分管理员密钥路径和固定 SID ACL，保留已有密钥；覆盖 CRLF/LF、重复运行和失败中止 |
| P1：Windows 更新模式往返 | 推荐模式写旧 UX 路径，只写 NoAutoRebootWithLoggedOnUsers，且从禁用切回推荐不恢复服务/任务 | 将默认/推荐/禁用作为一个变更单元，适配[#4845](https://github.com/ChrisTitusTech/winutil/commit/29595f90e2b2196fa6172d964ca0f7bebaa142ca)及[#5105](https://github.com/ChrisTitusTech/winutil/commit/4d4e21956251fd71c7c7137b6697ef17e7cb26f1)。核验实际生效及错误结果，不能承诺绝不自动重启；保留企业策略边界 |
| P1/P2：设置兼容性 | Activity 的 EnableActivityFeed=0 有影响剪贴板历史的上游记录；AppX 仍走旧 pipeline/当前 PS 进程；不存在服务会令整个项目失败 | 分别适配[#5035](https://github.com/ChrisTitusTech/winutil/commit/d1a61790a1ff2acf3881e47f7c4d14eb1c918a3e)、[#4822](https://github.com/ChrisTitusTech/winutil/commit/9791386f536b0c10e0f78527a1bacd61a1fe72c2)、[#5140](https://github.com/ChrisTitusTech/winutil/commit/07ccd8e2e755a706f31569808b31f5b77acad6a9)，保留中文结果和快照；Win+V、AppX 实际移除及权限异常在测试机验证 |
| P2：已安装软件检测 | Chocolatey 的 `git;github-desktop` 即使两个包均存在也漏检；WinGet 表格解析跳过固定行数，不检查退出码 | 先修多依赖判定，建立有来源/错误状态的库存结果；验证语言、终端宽度、空结果、失败和包管理器切换，不能把扫描失败当作零软件 |
| P2：长任务与旧修复结果 | 软件进程无限等待，无“当前项完成后停止”；部分旧修复同步阻塞 UI，忽略原生命令错误仍显示完成 | 增加耗时和日志入口、停止后续队列、异常任务恢复标识；避免强杀安装器。逐步接入共享任务与结构化结果，不用单纯增加超时掩盖真实状态 |

## 更实用、适合更多用户的功能更新

1. **软件更新中心**：WinGet 先行，扫描待更新软件，显示当前/目标版本和来源，勾选后逐项更新，并复用已有失败重试与日志。未知版本和固定包默认跳过；不悄悄启用 include-unknown/include-pinned。上游 26.10.07 仍是整批更新，不能通过简单同步获得完整功能。
2. **只读诊断与反馈报告**：参考[上游 #5025](https://github.com/ChrisTitusTech/winutil/commit/7ee5be3d2fbfe2374cbc6bf472be73ba002daa3b)，收集系统/架构、包管理器、待重启、相关错误及网络连通性。导出前预览、脱敏；不把用户路径、用户名或完整日志自动上传。
3. **网卡级 DNS 与恢复**：先选择网卡、保存 IPv4/IPv6 及 DHCP/静态状态、写后读回核验；再考虑 DoH、测速和推荐。当前全部 Up 网卡含 VPN，不宜一概覆盖。上游测速主要测 TCP 53 连接耗时，不能直接宣传真实 DNS 查询最快。
4. **可访问性与新手验收**：明确键盘焦点、可访问名称，验证 125/150/200% DPI、窄窗口、中文长文本及读屏；找首次用户完成“选择软件→核对→执行→看懂失败原因”，以卡点决定界面改动。
5. **软件目录质量**：213 个唯一 WinGet ID 对应的微软目录全部存在，未发现失效 ID；尚未验证厂商安装器下载或真实安装。可为 .NET 6 标识旧应用兼容与停止支持，说明 8/9 于 2026-11-10结束维护，开发组合优先提供现有 Node LTS 候选。上游多出的44个软件键还需与中文扩展去重，不能把数量差当作必装清单。[.NET 生命周期](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)

## 依赖、构建和 GitHub 维护

| 项目 | 当前 → 可更新点 | 处理建议 |
| --- | --- | --- |
| MCP Node | 发布 CI Node 20；engines/文档原先允许18 | 升级到受支持的24 LTS并建立 Windows MCP CI；版本声明与实际最低支持一起验证。[Node 生命周期](https://nodejs.org/en/about/previous-releases) |
| MCP SDK/依赖 | lock中SDK1.29.0，受支持1.x新版本1.32.1；7个依赖静态命中28条公告 | 保持1.x兼容升级并刷新锁文件，另行回归。公告匹配不等于28个可利用漏洞；SDK OAuth公告明确豁免服务端/stdio，多数命中涉及本项目未使用的HTTP能力。不要以命中数量替代可达性判断。[官方 SDK](https://github.com/modelcontextprotocol/typescript-sdk/releases) |
| MCP 打包 | prepublishOnly 不覆盖 npm pack；包/锁根/服务版本不一致，旧快照优先读取 | 明确源码/打包模式，生成快照包含源码SHA与时间；干净检出打包必须包含可离线读取的数据及一致版本 |
| Dependabot | 仅 github-actions；仍忽略 stale >=9，但现用v10 | 补npm生态，移除过时忽略；stale v11先dry run验证90/365天规则，不误关问题。checkout@v7等主要Actions已在当前主版本，无须盲目升大版本 |
| 文档站 | Hugo0.156.0→0.167.0，Hextra0.12.3→0.13.0；中文分支没有文档构建CI和在线部署 | 先补只构建/查链接的CI，再升级并验证中文搜索、图片、稳定路由和主题样式。上游Astro迁移另立范围。[Hugo](https://github.com/gohugoio/hugo/releases/tag/v0.167.0)、[Hextra](https://github.com/imfing/hextra/releases/tag/v0.13.0) |
| 测试框架/启动器 | Pester5.7.1仍可用；net48及ReferenceAssemblies1.0.3不需追新 | Pester6主版本迁移单独验证；固定受支持构建SDK特性带，保留net48运行定位和现有扫描门禁；不为了依赖数量升级而增加用户运行时要求 |

GitHub 当前没有待处理的依赖 PR，不能据此认为依赖均最新。Issue #5 继续跟踪分阶段同步；Issue #6 等待原报告环境复测，不能仅凭本轮模拟测试关闭。

## 验证与未完成事项

调查使用了实际 GitHub/npm/WinGet/Chocolatey 官方元数据、上游 Git 差异、已发布 npm tarball 完整性校验、PowerShell 双版本隔离复现。已排除 30 版已修的下载校验，以及本地已修的 `sc.exe` 退出码、Disable兼容、WaaSMedicSvc恢复等，避免重复计数。

本轮功能测试禁止真实安装、卸载、改注册表/服务、格式化磁盘、启用 SSH 或修改网络。主机虽然有 Hyper-V 命令入口，但当前身份无法枚举虚拟机，因此没有完成 Windows 11 测试虚拟机验收；没有为此提升管理权限、启用虚拟化或重启系统。自动回归与CI构建不能代替这些验证。

发布和最新测试证据统一记录在 [WORKSTATE.md](../WORKSTATE.md)。MCP修复/新版npm发布、启动盘可靠性、SSH与完整更新策略、真实Windows使用验收，以及完整上游架构迁移仍是后续工作。
