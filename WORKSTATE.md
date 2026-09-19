# WinUtil CN 维护状态

更新：2026-09-20。项目：`https://github.com/yasewang1337-svg/winutil-cn`；工作区 `W:\winutil-cn`。

## 当前任务

用户要求优化项目并处理偶发报毒。本轮从干净的 main `eb57d18` 开始；首批整改及随后用户要求“修复”的 O&O/ViVeTool 四项整改均已写入工作区并通过隔离测试，未提交、推送或发布。最新正常构建仍在读取临时 PS1 时被拒绝访问，未进入 EXE 打包，报毒问题尚未解决。根目录 EXE 仍是旧版；两份旧 PS1 在本轮读取时同样被拒绝访问，复查已不存在，不能当作新交付。

用户随后明确要求“生成吧 然后把GitHub上的更新了”，已授权提交、合并并发布此轮修复。采用分支PR及GitHub CI正常构建、双版本回归和Defender扫描；任何检查或扫描失败均停止发布。合并及正式发布的实际结果待本轮完成后写回。不会改变本机防护来生成产物。

发布推进：PR #11，分支 `codex/security-download-hardening`。首轮远端完整PS1构建及双版本311项测试通过；启动器夹具在英文Windows暴露 `tools/launcher/build.ps1` 缺少UTF-8 BOM的解析错误，已补BOM及编码断言，本地无害夹具复测通过，待远端重跑。原始失败日志 `.artifacts/security-fix/pr-ci-failure.log`，修复验证 `launcher-encoding-test.log`。

### 最新修复与验证（06:45）

- 共用 `Invoke-WinUtilVerifiedTool`：O&O 必须通过有效 Authenticode 签名及精确发布者检查；ViVeTool v0.3.4 两架构包先验固定 SHA256，哈希与官方包和 Microsoft WinGet 清单一致，再校验 ZIP 文件清单及全部解压文件。
- 工具目录使用每次唯一的 ProgramData 子目录，创建时设置仅管理员/SYSTEM 可写的受保护权限；EXE/DLL/数据文件持有只读锁直至子进程结束。下载/校验/启动失败中止，清理仅限本次目录，拒绝递归跟随链接或清理异常子目录。
- 核对上游源码发现 ViVeTool 失败可能退出0，警告也可能带成功行；已同时检查退出码及该固定版本的完整正常输出。O&O 后台运行、防重复启动、中文错误提示，关闭主窗口时提醒先关闭 O&O。
- 配置 apply/undo 与 FirstLogon 调用同一实现。`tools/Sync-VerifiedToolTemplate.ps1` 同步文本，`-Check` 与 Compile 拦截源码/模板漂移；FirstLogon 失败单独记日志并继续其他独立步骤。
- 全量回归：PS5.1 / PS7 各 **311 项通过**，日志 `.artifacts/security-fix/tests-ps51.log`、`tests-ps7.log`；模板同步、105页开发文档检查、Actionlint、diff --check通过。真实官方文件只用于下载/签名/哈希校验，没有执行；额外API/文件锁/无害输出重定向检查见 `provenance/`。其早期 helper-review.json 是补输出判定前的审查，最终行为以全量测试与当前源码为准。未在用户系统运行真实优化、安装镜像或管理员工具。
- 06:44:57正常构建生成709872字节临时PS1、语法检查通过，但读 `winutil-cn-build-622469dcccca49b890fe7b70a7079dd3/winutil.ps1` 被拒绝访问，未生成新EXE。日志和前后产物状态在 `.artifacts/security-fix/build.log`、`build-result.json`。此次没有新的火绒导出记录，不能把此前检测名冒充本次已核实的告警。根目录旧EXE的长度、时间和SHA256均未变。
- 尚未完成：获得可读取的新产物、完成完整产物安全扫描并交付新版EXE。当前应保留证据并结合最新安全产品日志/厂商复核处理阻断；没有关闭防护、添加排除项、恢复隔离文件或做检测规避，也未对外提交。不要无新依据重复构建。

### 前续整改与历史证据

- 用户提供 `88.txt`：火绒于 2026-09-20 05:58:54 将临时构建 `winutil.ps1` 报为 `TrojanDownloader/PS.Netloader.lr` 并删除（病毒 ID `2905791205BCC50A`，不是文件 SHA256）。原始证据复制到 `.artifacts/security-huorong-alert.txt`；原始日志保留在本地，未向厂商发送文件或反馈。
- 已实现：启动及提权去掉 Bypass/远程内存下载后提权；启动器使用系统 PowerShell 路径、只读锁及内嵌资源 SHA256 校验；遥测操作不再改 Defender 自动样本提交；自动登录/PowerShell 配置入口改官方指南；缺失 Chocolatey 改手动安装提示，默认 WinGet 及已有 Chocolatey 管理功能保留。
- 已实现：EXE/PS1 分别扫描，扫描未完成或失败阻止发布，`security-scan.json` 记录证据，发布前再验哈希；更新指南、错误反馈表及105页生成参考（多数只刷新源配置指纹）。
- 已验证：PS 5.1 / PS7 各 **268 项通过**（`.artifacts/security-tests-ps51.log`、`security-tests-ps7.log`）；`tools/Test-Launcher.ps1` 用无害夹具验证系统路径、文件锁、参数/退出码、清理，无 UAC/真实应用启动；Actionlint 与 diff --check 通过；开发参考 ValidateOnly 105项、0更新。
- 构建证据：首轮临时 PS1 为686645字节；移除两处剩余远程脚本入口后第二轮为686752字节，仍读取失败（`.artifacts/security-build.log`）。用户后补 `888.txt` 确认两次均被火绒以 `TrojanDownloader/PS.Netloader.lr` 删除。未获得新产物 SHA256、未生成新版 EXE、未恢复隔离文件。`.artifacts/security-build-inputs.json` 为第二轮输入快照，之后有3个函数的编码/换行整理，不能声称当前逐字节输入与该快照相同。
- 本机 Defender 状态为服务/防病毒未启用、无病毒库信息；已确认有火绒安全进程。没有调整安全软件设置、添加排除项、关闭防护或进行伪装。单测和启动器夹具通过不代表实际应用获杀软放行。
- 2026-09-20 06:14 用户要求再次构建：当前源码生成686767字节PS1后，在 `汉化/run-all.ps1:43` 读取时出现拒绝访问。用户后补 `888.txt` 的06:14:17事件与此次路径/时间/命令一致，确认仍是火绒以相同检测名删除文件；05:59更新记录显示产品6.0.12.1、病毒库2026-09-19 19:44。新日志备份 `.artifacts/security-huorong-alert-888.txt`，已补入 `.artifacts/security-rebuild-latest.json` 与复核草稿。未进入 EXE 构建，根目录三份产物仍为09-13旧版，未更改任何安全配置。
- `888.txt` 还确认05:52旧 `Invoke-WPFPanelAutologin.ps1` 单独被 `HEUR:TrojanDownloader/PS.NetLoader.bv` 删除；该函数已经改为官方指南入口，不把这个旧函数告警当作整个产物后续检测的唯一原因。
- 06:20本地复核的历史发现（现已修复，见上方）：O&O 无校验执行；ViVeTool GUI和FirstLogon无完整性校验，使用固定路径，失败仍可继续启动。无害诊断放 `.artifacts/security-review/`；O&O双引擎确认原实现未校验；ViVe双引擎18种模拟均未报告失败，汇总 `vive-failure-summary.json` 带修复前输入SHA256。这些历史发现不能证明火绒命中特征，也不能断言纯误报。
- 厂商复核草稿 [docs/HUORONG-REVIEW.md](docs/HUORONG-REVIEW.md) 已同步代码修复及新构建结果，尚未对外提交。对外发资料仍需明确授权。当前没有可信代码签名证书；签名不能保证消除PS1检测。

## 上一阶段：文件组织整理（已交付）

用户批准的文件组织审计整理已完成。工作分支 `maintenance/repository-organization-20260913` 基于 `96cc3f3`，经 PR #10 合并为 main `cf0e977`；远端工作分支已删除，本地已同步 main。范围：修复维护工具覆盖数据、隔离构建输入、归类历史工具/图片/测试/分发清单、同步指南与生成参考，保持现有中文启动与下载入口。

并行分工：safe_tweaks 修复生成器与参考文档；install_results 修复翻译提取器和隔离构建；bundle_choices 归类文件与补索引；主助手整合工作流、文档入口、验证与交付。各代理不提交或推送。

审计证据：`.artifacts/repository-organization-audit.md`、`repository-reproduction.json`。基线353个跟踪文件，无字节级重复。隔离复现：旧文档生成器91页→0页仍成功，旧翻译提取器10859字节→0；构建软件注入192→213项并写回源码。复现未修改原仓库。

## 实施进展

- 已限制并标识上游旧预发布、赞助、文档自动合并等流程；生成产物检查改为只读失败，不再自动删除文件并提交。
- 已同步中文文档入口、自动化范围与本地 Hugo 配置；上游 CNAME 从静态发布目录移入历史资料。图片按 branding/screenshots/archive 分类，旧脚本存为非执行文本，测试夹具和旧 WinGet 清单独立归类，新增目录与函数领域索引。
- 文档生成器已改为稳定路由、预检、暂存及失败回滚，生成105页并保留原91个路径；翻译提取器要求明确输入、合并保存并拒绝空结果，修复切换 PowerShell 目录后的相对路径读写错误。中文构建在临时副本中进行，保留原有输出入口。
- 本地验证完成：PS5.1/7各235项测试通过；实际双引擎构建均通过双版本语法/BOM检查，117个源输入不变，编译内容仅JSON格式不同且均含213个软件。Hugo生成161页及2个别名，6522个内部页面/资源引用无缺失；27项纯移动哈希不变；Actionlint通过。
- 验证记录：`.artifacts/organization-tests-*.log`、`organization-build-verification.json`、`organization-build-equivalence.json`、`organization-docs-qa.json`、`organization-validation.json`、`devdocs-refresh-verification.json`。一次连续构建遭遇输出文件临时占用，替换失败保留旧产物，随后重新构建成功；没有执行生成脚本或EXE。
- PR #10 已合并，PR检查全部通过；PR回归运行 `34705778828`、正式发布运行 `34705862389` 均在双版本各通过235项。实际发布附件已验证，详见下方；本轮已无待实施事项。

## 已交付基线

| 阶段 | 证据 |
| --- | --- |
| 可靠性与依赖维护 | PR #7，主提交 b7fcb63；依赖PR #1/#2/#4已合并；发布 cn-2026.09.12-27 |
| 新手体验 | PR #8，主提交 a622c3b；发布 cn-2026.09.12-28，PS5.1/7各200项通过，真实worker/WPF调度的模拟回归 |
| 仓库展示 | PR #9，主提交 4b11477；README/图片/贡献指南与GitHub About已更新；维护记录96cc3f3，无新Release |
| 文件组织与维护流程 | PR #10，主提交 cf0e977；双版本各235项通过，发布 cn-2026.09.12-29；目录索引见 docs/REPOSITORY.md |

正式最新交付 `cn-2026.09.12-29`：运行 `34705862389` 全成功，Defender完成扫描未检出威胁。实际附件已核验SHA256、双版本语法/BOM、EXE内嵌PS1一致性，并与本地构建在统一换行及构建日期后完全一致；根目录 EXE/PS1 为这些附件。此次运行脚本与上一版相同，EXE使用新构建版本号。

- EXE：`6A72FE98C365F1EA3759AB2B4E0963EC7BEA0C41691D24B5689F2065F7988703`
- PS1：`3E220699F7252CF624D1940308B323F4DA5724BE979006F5EB770A07909F8046`
- 发布附件与验证记录在 `.artifacts/released/cn-2026.09.12-29/`、`organization-release-verification.json`、`organization-release-ci.log`、`organization-pr-ci-tests.log`。上一版附件与历史验证仍保留在原目录。
- 展示验证：`.artifacts/readme-qa.json` 与 `readme-*.png`，桌面/深色/手机布局与真实GitHub页面已核对。

完整历史记录保留在 Git 提交 `96cc3f3:WORKSTATE.md`，本轮前备份 `.artifacts/WORKSTATE-before-organization.md`。历史“已确认问题”不代表当前仍未修复，历史测试不替代本轮验证。

## 后续边界

- Issue #5：完整上游迁移未完成。此前核对稳定版26.08.19，相对共同祖先58a81b1有170提交/362文件变化；后续恢复时重新核对版本，参考 docs/MAINTENANCE.md。
- Issue #6：前述开关启动读取故障已有修复，等待原报告环境复测，保留开放。
- 逐软件待更新清单、网络诊断与外部首次用户试用仍是独立后续任务；设置恢复限已记录的注册表值和服务启动配置。

## 操作入口

- 测试工具：`.artifacts/tools/Pester/5.7.1/Pester.psd1`；调用 tools/Invoke-Tests.ps1 时使用绝对模块路径，中文测试文件必须UTF-8 BOM。
- GitHub CLI：`.artifacts/tools/gh/bin/gh.exe`，用户已授权本仓库维护及repo/workflow登录。凭据由系统保存，不写入项目。
- Git无默认作者时沿用历史Codex noreply身份；推送使用一次性CLI credential helper，避免等待默认Credential Manager。
- 只执行隔离测试和构建，不在用户电脑上运行真实优化、安装、卸载、还原点或自动导入操作。
