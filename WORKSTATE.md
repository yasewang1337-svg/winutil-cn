# WinUtil CN 维护状态

更新：2026-10-09。项目：`https://github.com/yasewang1337-svg/winutil-cn`；工作区 `W:\winutil-cn`。

## 当前任务：更新页布局、Windows 10/11 镜像与仓库展示（已验证，待发布）

用户要求修复 Windows 更新页标题裁剪、镜像页不再只限 Win11、GitHub 仓库页及预览图随版本更新；进一步明确选择 Windows 10 / 11 都能制作镜像。基于 main `f94b988`，分支 `codex/windows-pages-repo-20261009`。

并行分工：`ui_visual_polish` 修复更新页与验证两页布局；`ui_hover_details` 扩展实际镜像处理、版本识别及模板分流；`ui_integration_review` 更新指南与仓库展示并只读审查；主助手负责镜像页UI、编译模板、下载事件、真实预览与集成交付。更新页已修复固定尺寸导致的裁剪；Win10采用独立最小应答，不套用Win11定制脚本。宿主支持范围仍为Windows11，制作目标为x64 Win10/11，其他架构不宣称支持。

已完成：更新页改纵向布局与自适应标题/按钮；镜像页支持官方Win10/11下载选择、整页滚动、长磁盘名换行及常显清理入口；按详细DISM元数据识别Win10 19041–19045 / Win11 >=22000的x64客户端，WIM/ESD统一先导出所选版本。制作使用独立受保护目录与状态清单，Win10独立最小应答，Win11保留现有定制；驱动要求同代际，写盘前核对设备身份/容量，失败不报告成功。四种后台操作接入全局忙状态与启动失败恢复。消息框枚举不再被汉化成非法参数。

最终PS5.1/7完整回归各582项通过。首轮发现一处旧编译夹具缺少新Win10模板输入，补齐后双版本全部通过。隔离源码快照实际构建及双版本语法/BOM通过，检查新模板和控件已嵌入，根目录34版文件未变。布局单项验证覆盖明暗/1280与800px/100%与150%、镜像全部步骤、下拉文字与箭头间距及滚动可达。20张最终WPF预览中5张已更新仓库截图；Hugo161页/2别名、6518站点引用与128条Markdown相对链接无缺失，105页开发参考、Actionlint/diff检查通过。

证据在 `.artifacts/windows-pages/`：`tests-ps51-final.log`、`tests-ps7-final.log`、`isolated-build.json`、`screenshot-delivery.json`、`docs-qa.json`；子目录 `updates/`、`iso-layout/`、`iso/` 保存定向验证。没有真实挂载用户ISO、修改系统或写U盘；ISO输出启动、完整安装与目标设备驱动仍未真机验收。尚待GitHub正式构建、附件复核、仓库About与本地交付。

## 上一阶段：界面美化与一致悬停介绍（已交付34版）

用户要求美化UI/交互，并指出软件名称悬停仅显示名称，而勾选框才显示介绍。确认33版 `Initialize-InstallAppEntry.ps1` 的名称ToolTip覆盖祖先介绍；本轮基于main `a6a1c6d`，分支 `codex/ui-polish-20261009`。修复整张软件条目统一介绍，增加可读标题/完整用途/包ID、缺介绍回退和主题/字号适配；统一深浅主题、软件条目/分类/导航/按钮层级与键盘焦点。右键菜单由图标改清楚文字，Apps/Shift+F10可打开、Esc关闭，保留任务忙/离线/单软件确认边界。

并行：`ui_hover_details` 负责悬停与条目事件，`ui_visual_polish` 负责主题/XAML/软件列表布局，主助手负责文字菜单、衔接、指南、整体验证与交付。使用真实WPF无害控件测试及离屏渲染，不在主机运行WinUtil系统修改。验证、发布和本地替换均已完成，正式入口已更新为34版。记录与预览放 `.artifacts/ui-polish/`。

用户否定初稿的通用模板感，明确要求联网研究成熟设计后重做；初稿未发布。已查Files、UniGetUI官方项目和微软NavigationView/CommandBar/Typography规范，调整为Windows桌面工作界面：左侧稳定导航、顶部产品与窗口操作、软件页紧凑命令栏、全宽名称与用途列表；首页移除营销口号与重复卡片，改真实任务入口。保留已验证的整行Tooltip/键盘操作，深浅色改中性灰与克制蓝色强调。视觉与列表由原两代理重做，主助手负责软件命令栏/菜单。最终设计及来源记入 `.artifacts/ui-polish/design-revision.md`。

新方案已实现并冻结，参考及取舍记录在 `.artifacts/ui-polish/design-revision.md`（替代初稿）。第三代理 `ui_integration_review` 只读复核生产初始化/事件/离线与忙状态，协助修正弹层资源与Esc焦点、标题栏手势和紧凑导航提示。另修主题切换丢字号、空闲BlurEffect导致文字发虚、已选数量读屏不更新。真实渲染含生产WindowChrome入口；10张深浅/1280px/800px/150%及菜单图已复核，悬停预览覆盖完整中文与包ID；未运行真实安装或系统修改。

本地完整回归PS5.1/7各500项通过；105页参考验证、Hugo161页/2个别名、Actionlint/diff检查通过。初轮499项通过后，补上标题栏调整后的工具弹层外部关闭回归，最终双版本各500项。README与应用指南已换本轮真实截图。证据 `.artifacts/ui-polish/{tests-ps51-final.log,tests-ps7-final.log,render-main.json,hugo.log}`；`.artifacts/ui-hover/`保留悬停与列表路由结果。

- [PR #20](https://github.com/yasewang1337-svg/winutil-cn/pull/20) 已合并，源码提交 `1041d5fcecfb65db5f6a58474f58fb310d22fcf5`。PR运行 [37937608532](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37937608532) 与正式发布运行 [37937986012](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37937986012) 全部通过，PS5.1/7各500项、无害启动器及产物语法/BOM检查均成功。
- 正式版 [cn-2026.10.09-34](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.10.09-34) 已发布，发布说明已更新本轮设计与交互改进并回读核对。四份附件已核对GitHub digest、校验清单和扫描报告源码提交；EXE内嵌PS1与独立脚本一致，独立脚本本地PS5.1/7语法/BOM检查通过。Defender逐文件按需扫描未检出威胁，报告保留runner实时防护false与NotSigned事实；不代表其他引擎验收。
- 用户关闭占用中的旧窗口后，根目录 `WinUtil-CN.exe`、`winutil-cn.ps1`、`winutil.ps1` 已替换为34版，2026-10-09T13:44:21Z再次核对三份哈希与发布附件一致。EXE SHA256：`316826E4501DB1961AE076F9E04CBEC011B3F92A9674EFDCA8AE886F23F3610C`；PS1 SHA256：`74323D742D5708EEAA0887EA3059286D5D63120DDBC9BEA05DE08F9F39A32CED`。正式附件在 `.artifacts/released/cn-2026.10.09-34/`，证据在 `.artifacts/ui-polish/{release-ci.log,release-metadata.json,asset-digests.json,release-verification.json,local-delivery.json}`。
- 本轮界面改进已交付。真实WPF控件与离屏图已验证深浅主题、宽窄窗口、150%字号和键盘/悬停事件；未运行真实软件安装或系统修改，未以离屏验证替代多屏DPI及读屏器人工验收。

## 上一阶段：软件使用流程体验优化（已交付33版）

用户要求“优化一下用户使用体验”。以已交付32版及main `5e2a895` 为基线，在 `codex/ux-software-flow-20261009` 分支实施。范围聚焦找软件、核对选择、看懂结果：搜索数量与空状态、名称/介绍/包ID搜索、仅看已选和清除筛选；多项选择弹层滚动与键盘使用；结果列表及逐项详情、当前会话上次结果回看。修正“显示已装应用”实际添加勾选的文案。保留现有主题和确认机制，不做真实安装或系统变更。

并行分工：`ux_selection_review` 负责软件搜索/筛选/选择及相关真实WPF模拟；`ux_result_dialog` 负责结果窗口、长文本和窄窗；主助手负责结果回看/重试衔接、维护与用户指南、双版本集成验证及GitHub交付。

- 已实现上述范围，同时修复清单重置误清“仅看已选”、旧分类折叠状态被搜索覆盖、任务失败时旧结果被当作新结果等衔接问题。结果详情包含操作类型；整批升级不提供自动失败重试。软件名称自然换行，完整名称保留Tooltip和读屏信息。
- 最终全量回归PS5.1/7各443项通过；105页开发参考更新并校验，Hugo构建161页/2个别名，Actionlint及diff检查通过。真实WPF离屏预览覆盖暗亮主题、结果窗360px窄宽与22px字号、软件区340px及150%字号、30项已选清单。初轮439项通过后，依据视觉发现补充长名/字号/操作类型并追加4项测试；最终443项无失败。
- 证据在 `.artifacts/ux-software-flow/`（最终回归 `tests-ps51-final.log`、`tests-ps7-final.log`，结果窗口渲染、文档构建与参考校验）及 `.artifacts/ux-selection/`（真实192项目录的列表、筛选、长名称与弹层预览）。没有运行真实安装/卸载或修改系统；离屏字体测试不等同实际多屏DPI/读屏器人工验收。
- [PR #18](https://github.com/yasewang1337-svg/winutil-cn/pull/18) 已合并，源码提交 `0f592c5bdea09ff5d4a7c5b01822be12fe05a3bf`。PR运行 [37931456323](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37931456323) 与正式发布运行 [37931674812](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37931674812) 全部通过，双版本各443项回归、无害启动器及产物语法/BOM检查均成功。
- 正式版 [cn-2026.10.09-33](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.10.09-33) 已发布，说明已更新本轮体验改进并回读核对。Defender逐文件按需扫描退出0、未检出威胁，引擎 `1.1.26080.3`、病毒库 `1.459.638.0`；扫描报告保留runner实时防护false及两份产物NotSigned事实，不代表其他引擎验收。
- 发布四份附件已核对GitHub digest、校验清单、扫描报告的源码提交、EXE内嵌PS1与独立脚本一致性；独立脚本本地PS5.1/7语法/BOM复核通过。根目录 `WinUtil-CN.exe`、`winutil-cn.ps1`、`winutil.ps1` 已更新并再次核对哈希。EXE SHA256：`7369E90E48AF059B57FE62B0AF6F6134DBA8579131A253E016E0D1D727F8E2E7`；PS1 SHA256：`780196B4DA91441754FA698070171868D368E7248A471D1C750A307528DA81B9`。正式附件在 `.artifacts/released/cn-2026.10.09-33/`，验证及本地交付证据在 `.artifacts/ux-software-flow/{release-ci.log,release-metadata.json,asset-digests.json,release-verification.json,local-delivery.json}`。本轮体验改进已交付，无需继续扩大范围。

## 上一阶段：程序行为透明化与可靠性优化（已交付32版）

用户要求31版发布说明不包含火绒专项说明，转向优化程序行为及正常降低误报风险。31版说明中的相关段落已移除并回读确认；纯告警文档PR #15已关闭未合并，原文与源码对照保留在本地证据目录和 `codex/huorong-31-followup` 分支，未向厂商发送。本轮实现通过 [PR #16](https://github.com/yasewang1337-svg/winutil-cn/pull/16) 合并，源码提交 `c74983f8412cd6db9e5abc8abb0df7d74eb761a5`；正式版本 [cn-2026.10.09-32](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.10.09-32) 已发布，发布说明已写入本轮改进并回读核对。

- 本轮实现：20个按钮由脚本文本迁移为固定动作，10个函数按钮限定ID与处理函数；开发工具换源先确认并正确报告失败；O&O下载前确认，ViVe计划说明下载与系统影响；保留既有校验与文件锁，记录第三方下载文件的真实来源、哈希和验证结果。
- 同步生成器支持固定动作，更新用户指南及发布模板，避免未来版本自动带入旧专项告警段落。未改变包管理器MCP独立实现、未发布npm，也不为消除检测而混淆或等价改写代码。
- 最终完整回归PS5.1/7各396项通过，覆盖非法配置拒绝、模态确认重入/取消/异常、缺工具、原生命令非零退出及真实无害cmd夹具。整合初次PS7有6项面板路径断言失败，对照确认当时代理仍在更新路径实现与测试；文件稳定后双版本全量通过。105页参考已刷新，Hugo生成161页/2个别名，6523个内部链接与资源无缺失；模板一致性、Actionlint及diff通过。
- PR运行 [37928463825](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37928463825) 与正式发布运行 [37928628097](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37928628097) 全部成功，双版本均各396项通过。正式产物逐个Defender按需扫描退出0、未检出威胁；引擎 `1.1.26080.3`、病毒库 `1.459.638.0`，报告如实记录runner实时防护false及两份产物NotSigned。
- 已下载正式发布四份附件并核对GitHub资产digest、SHA256SUMS、扫描报告源码提交及EXE内嵌脚本一致性。独立脚本通过本地PS5.1/7语法与BOM检查；未运行真实程序、安装或系统设置操作。当前可读取不代表已通过其他引擎的实机检测，本轮未做火绒开启后的独立复测，也未变更防护配置。
- 已将32版同步至根目录 `WinUtil-CN.exe`、`winutil-cn.ps1`、`winutil.ps1`，三份哈希与正式附件一致。EXE SHA256：`19EEC7EE53C88E357C3D41907921CC4983D63B052E8B08EDE58FAF08F7345A68`；PS1 SHA256：`998B7CC3B985499FC3117A284215C3690309765215A7B3A75BFC086460083001`。附件在 `.artifacts/released/cn-2026.10.09-32/`，证据在 `.artifacts/transparent-actions/` 的 `release-ci.log`、`release-metadata.json`、`asset-digests.json`、`release-verification.json`、`local-delivery.json`。源码仍未配置可信代码签名证书；没有发布独立npm包。

## 上一阶段：全面更新调查与选择性修复（已发布，本地脚本复核曾受阻）

用户要求“更新一下，全面调查一下可更新点”。调查起点本地与远端main均为 `98895c1`，工作区干净，实际最新桌面版为30（不是浏览器仍打开的28）。本轮分支 `maintenance/update-audit-20261009`。上游核对到26.10.07 / `07ccd8e`；共同祖先后的历史差异为223提交/433文件，不等同待修问题数量。

- 已完成三路调查：上游迁移、运行可靠性与用户体验、依赖/软件目录/MCP发布。对外完整清单见 `docs/UPDATE-AUDIT-2026-10.md`；本地证据在 `.artifacts/update-audit-20261009/{upstream,runtime,dependencies,validation}/`。
- 已实现：移除更新修复/默认更新入口的全局策略和安全模板重置；修复功能安装、库存扫描异常后卡忙及重复派发；6处英文ACL主体改固定SID；OneDrive卸载器用SystemRoot；4项.NET Desktop Runtime的Chocolatey映射改正确类型；修复模板同步工具PS5.1默认参数和相对路径解析。
- 已更新维护/上游状态、MCP真实使用边界、Windows更新指南及启动器环境说明，刷新105页受管理参考。没有发布npm，也没有宣称完整同步上游。
- 本地最终完整回归PS5.1/7各337项通过，含6场景真实worker/WPF Dispatcher无害夹具。Hugo生成161页/2个别名，6523处内部页面/资源引用无缺失；Actionlint与diff检查通过。完整源码编译、启动器与扫描由GitHub隔离CI验收，不在主机运行真实WinUtil或改系统。
- Hyper-V命令存在，但当前身份无法枚举虚拟机；真实Windows11安装、恢复、磁盘/网络验收仍未完成。无提权开启虚拟化、重启或绕过防护。
- [PR #13](https://github.com/yasewang1337-svg/winutil-cn/pull/13) 已合并，源码提交 `5844369d49482bd2162568333810d02b1d6bfa7a`。首轮CI发现PS5.1在英文环境默认编码读取中文源码导致一项AST测试失败，已改为与编译器一致的显式UTF-8读取；最终PR运行 [37922974206](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37922974206) 双版本各337项通过，编译、启动器和其他检查均通过。
- 正式版本 [cn-2026.10.09-31](https://github.com/yasewang1337-svg/winutil-cn/releases/tag/cn-2026.10.09-31) 已发布，运行 [37923206300](https://github.com/yasewang1337-svg/winutil-cn/actions/runs/37923206300) 全成功：PS5.1/7各337项、无害启动器、双版本产物语法/BOM检查通过，Defender逐个扫描PS1和EXE均退出0且未检出威胁。引擎 `1.1.26080.3`、病毒库 `1.459.636.0`，报告如实记录runner实时防护false、两份产物NotSigned。发布说明已补本轮变更、调查入口和实际验证限制。
- 发布后下载四份原始附件。EXE、SHA256SUMS、扫描报告本地哈希与GitHub资产digest一致；清单、报告、源码提交相符；仅反射读取EXE资源并计算哈希，内嵌脚本与发布PS1 digest一致，没有提取或执行脚本。证据在 `.artifacts/update-audit-20261009/release-verification.json`、`release-metadata.json`、`validation/release-ci.log`。
- **当时本地限制**：核对根目录旧PS1时返回拒绝访问，随后元数据检查已找不到两份旧PS1；新版下载到 `.artifacts/released/cn-2026.10.09-31/` 后，读取独立PS1也返回拒绝访问。当时未取得具体告警；后续用户日志确认这些文件被火绒删除，原始证据仅保留本地。31版独立PS1的本地哈希/语法复核未完成，没有重下受阻文件、改名、恢复隔离或调整防护；根目录入口现已由上方验证完成的32版更新。
- 已将核验成功的31版EXE同步到 `W:\winutil-cn\WinUtil-CN.exe`，同步后哈希一致，未启动真实程序。EXE SHA256：`D105317A1846BA1414B7D63763A216C340F36987A93E954C490C99178FC70868`；发布PS1的GitHub digest/扫描报告SHA256：`BBEE00E5724FF8383C277EFDC9D5F32DA2BEBDCC4AF369ED20A89F0C26E802FD`。详见 `local-delivery.json`；这个PS1值来自发布证据，不能写成本机独立文件实测。
- 本轮调查和首批修复已交付。优先后续：MCP受限执行及独立发布、启动盘擦除前检查与退出码、SSH/更新模式完整适配，再推进逐软件更新中心和诊断报告。Issue #5/#6保持开放，没有发布npm或声称全量同步上游。

## 上一阶段：安全修复与新版发布（已交付）

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

- Issue #5：完整上游迁移未完成。2026-10-09核对稳定版26.10.07，相对共同祖先58a81b1有223提交/433文件变化；后续恢复时重新核对版本，参考 docs/MAINTENANCE.md。
- Issue #6：前述开关启动读取故障已有修复，等待原报告环境复测，保留开放。
- 逐软件待更新清单、网络诊断与外部首次用户试用仍是独立后续任务；设置恢复限已记录的注册表值和服务启动配置。

## 操作入口

- 测试工具：`.artifacts/tools/Pester/5.7.1/Pester.psd1`；调用 tools/Invoke-Tests.ps1 时使用绝对模块路径，中文测试文件必须UTF-8 BOM。
- GitHub CLI：`.artifacts/tools/gh/bin/gh.exe`，用户已授权本仓库维护及repo/workflow登录。凭据由系统保存，不写入项目。
- Git无默认作者时沿用历史Codex noreply身份；推送使用一次性CLI credential helper，避免等待默认Credential Manager。
- 只执行隔离测试和构建，不在用户电脑上运行真实优化、安装、卸载、还原点或自动导入操作。
