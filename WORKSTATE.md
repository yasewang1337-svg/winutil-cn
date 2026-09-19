# WinUtil CN 维护状态

更新：2026-09-20。项目：`https://github.com/yasewang1337-svg/winutil-cn`；工作区 `W:\winutil-cn`。

## 当前任务：安全修复与新版发布（已交付）

用户先要求处理偶发报毒，随后要求修复复核出的缺口，最后明确要求“生成吧 然后把GitHub上的更新了”。本轮修复已通过 [PR #11](https://github.com/yasewang1337-svg/winutil-cn/pull/11) 合并，源码提交 `b10def37204eb7651bb11582d74ba3acd7195d2b`；正式版本 [cn-2026.09.19-30](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.09.19-30) 已发布。版本日期采用CI的UTC日期，实际发布为台北时间09-20 07:00。

### 已实现

- O&O 下载后验证有效签名及精确发布者；ViVeTool v0.3.4按架构固定官方包SHA256，核对包内文件及解压后字节。工具每次使用仅管理员/SYSTEM可写的独立目录，EXE/DLL/数据文件持有只读锁至退出，失败中止，清理仅限本次目录。
- ViVeTool 设置失败可能退出0，警告也可能带成功行，故同时核对退出码和固定版本的完整正常输出。配置apply/undo和无人值守FirstLogon共用校验实现；源码/模板不同会阻止构建，更新入口为 `tools/Sync-VerifiedToolTemplate.ps1`。
- O&O 后台运行保持GUI响应、防重复点击、中文错误反馈。启动器/本地提权使用系统PowerShell、本地文件参数和RemoteSigned，内嵌脚本在只读锁内校验；保留Defender样本提交设置。自动登录/PowerShell配置改官方指南，缺失Chocolatey改手动提示，默认WinGet保留。
- 发布流水线逐个扫描PS1和EXE，扫描失败/不可用或哈希变化均停止发布；附件包含校验和及扫描报告。CI另发现英文Windows的启动器构建脚本缺BOM问题，已修复并加入编码断言。

### 验收与交付证据

- PR检查全部通过。正式发布运行 [35474785713](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/35474785713) 成功：PS5.1/PS7各311项测试、无害启动器夹具、双版本产物语法/BOM检查全部通过。
- Defender实际按需扫描两个最终产物，均退出0且未检出威胁；引擎 `1.1.26080.3`，病毒库 `1.459.293.0`。报告记录了runner实时防护为false及两个产物为NotSigned；这是该次扫描证据，不能代替其他引擎或实际系统行为验证。
- 发布后已下载4个附件，核对GitHub资产digest、SHA256SUMS和扫描报告对应源码提交。EXE内嵌PS1与发布脚本哈希完全一致；下载PS1又通过本地PS5.1/PS7语法/BOM检查，未执行真实WinUtil/优化/安装。
- 新版已同步至根目录 `WinUtil-CN.exe`、`winutil-cn.ps1`、`winutil.ps1`，三份读取及哈希核对成功；发布附件备份位于 `.artifacts/released/cn-2026.09.19-30/`。根目录产物不入Git。
- EXE SHA256：`D7737684A391DF17EA04A42E407A53440556D295E151B64AFB554FFA3853894B`；PS1 SHA256：`28B59D90E28B729A6F4A74D489D10ECE67FC6C34A44AD1597BA7B1E51DE09237`。
- 详细证据：`.artifacts/security-fix/release-ci.log`、`release-metadata.json`、`release-verification.json`、`local-delivery.json`；本地修复回归和工具来源核验在同目录 `tests-ps51.log`、`tests-ps7.log`、`provenance/`。105页开发参考验证、模板一致性、Actionlint及diff检查也通过。

### 仍需区分的告警事实

本机此前正常构建多次被火绒删除临时PS1，日志中具体名为 `TrojanDownloader/PS.Netloader.lr`；旧自动登录函数还曾被报 `HEUR:TrojanDownloader/PS.NetLoader.bv`。06:44的修复后本机构建通过语法检查、随后读取709872字节PS1被拒绝访问，该次没有新的火绒导出事件，不能直接套用历史检测名。原始用户日志88.txt/888.txt及模拟诊断仅保留本地；对外文档已去个人路径。

本次通过GitHub CI正常构建、扫描、发布，下载的新附件目前能在本机读取；这些事实不证明火绒拦截已彻底解决。没有关闭防护、添加排除、改后缀或恢复隔离文件，也没有向厂商提交。若再出现告警，保留当前版本对应的具体引擎、检测名、时间、SHA256及步骤，参考 [docs/HUORONG-REVIEW.md](docs/HUORONG-REVIEW.md) 继续定位。当前“生成并更新GitHub”的请求已完成，无后台待运行任务。

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

上一阶段交付 `cn-2026.09.12-29`：运行 `34705862389` 全成功，Defender完成扫描未检出威胁。实际附件已核验SHA256、双版本语法/BOM、EXE内嵌PS1一致性，并与本地构建在统一换行及构建日期后完全一致；当时根目录 EXE/PS1 为这些附件，本轮已由上方30版替换。此次运行脚本与上一版相同，EXE使用新构建版本号。

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
