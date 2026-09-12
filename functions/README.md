# 函数职责索引

这里保存编译进 WinUtil CN 的 PowerShell 函数。`public/` 主要是界面事件与操作入口，`private/` 主要是计划、执行、状态与控件辅助函数；它们是源码组织约定，不是 PowerShell 模块的导出边界。

本轮按领域建立索引，保留原文件路径。修改某个功能时，先找入口，再沿执行和结果链路阅读。

## 按任务查找

| 领域 | 主要入口 | 执行与辅助代码 |
| --- | --- | --- |
| 安装、卸载和整批升级 | [Invoke-WPFInstall](public/Invoke-WPFInstall.ps1)、[Invoke-WPFUnInstall](public/Invoke-WPFUnInstall.ps1)、[Invoke-WPFInstallUpgrade](public/Invoke-WPFInstallUpgrade.ps1) | [Get-WinUtilPackagePlan](private/Get-WinUtilPackagePlan.ps1) → [Invoke-WinUtilPackageOperation](private/Invoke-WinUtilPackageOperation.ps1) → [Invoke-WinUtilPackageBatch](private/Invoke-WinUtilPackageBatch.ps1) |
| 包管理器与结果判定 | [Install-WinUtilProgramWinget](private/Install-WinUtilProgramWinget.ps1)、[Install-WinUtilProgramChoco](private/Install-WinUtilProgramChoco.ps1) | [Invoke-WinUtilPackageProcess](private/Invoke-WinUtilPackageProcess.ps1) 捕获退出码与日志；[Get-WinUtilPackageExitResult](private/Get-WinUtilPackageExitResult.ps1) 映射结果；[Test-WinUtilPackageManager](private/Test-WinUtilPackageManager.ps1) 检测环境 |
| 装机组合与清单 | [Invoke-WPFBundle](public/Invoke-WPFBundle.ps1)、[Invoke-WPFImpex](public/Invoke-WPFImpex.ps1) | [Get-WinUtilBundlePlan](private/Get-WinUtilBundlePlan.ps1)、[New-WinUtilBundleDialog](private/New-WinUtilBundleDialog.ps1)、[Show-WinUtilBundleDialog](private/Show-WinUtilBundleDialog.ps1)、[Update-WinUtilSelections](private/Update-WinUtilSelections.ps1) |
| 设置方案与执行 | [Invoke-WPFPresets](public/Invoke-WPFPresets.ps1)、[Invoke-WPFtweaksbutton](public/Invoke-WPFtweaksbutton.ps1) | [Confirm-WinUtilTweakPlan](private/Confirm-WinUtilTweakPlan.ps1) → [Invoke-WinUtilTweakBatch](private/Invoke-WinUtilTweakBatch.ps1) → [Invoke-WinUtilTweaks](private/Invoke-WinUtilTweaks.ps1) |
| 设置记录与恢复 | [Invoke-WPFTweakHistory](public/Invoke-WPFTweakHistory.ps1)、[Invoke-WPFundoall](public/Invoke-WPFundoall.ps1) | [Get-WinUtilTweakRegistryState](private/Get-WinUtilTweakRegistryState.ps1)、[Save-WinUtilTweakHistory](private/Save-WinUtilTweakHistory.ps1)、[Get-WinUtilTweakHistory](private/Get-WinUtilTweakHistory.ps1)、[Restore-WinUtilTweakHistory](private/Restore-WinUtilTweakHistory.ps1) |
| 单项设置与状态 | [Invoke-WinUtilTweakToggle](private/Invoke-WinUtilTweakToggle.ps1)、[Get-WinUtilToggleStatus](private/Get-WinUtilToggleStatus.ps1) | [Set-WinUtilRegistry](private/Set-WinUtilRegistry.ps1)、[Set-WinUtilService](private/Set-WinUtilService.ps1)、[Set-WinUtilDNS](private/Set-WinUtilDNS.ps1)、[New-WinUtilTweakRestorePoint](private/New-WinUtilTweakRestorePoint.ps1) |
| 首页、导航与搜索 | [Initialize-WPFUI](public/Initialize-WPFUI.ps1)、[Invoke-WPFHome](public/Invoke-WPFHome.ps1)、[Invoke-WPFButton](public/Invoke-WPFButton.ps1)、[Invoke-WPFTab](public/Invoke-WPFTab.ps1) | [Find-AppsByNameOrDescription](private/Find-AppsByNameOrDescription.ps1)、[Find-TweaksByNameOrDescription](private/Find-TweaksByNameOrDescription.ps1)、[Invoke-WPFUIElements](public/Invoke-WPFUIElements.ps1) |
| 动态控件与显示偏好 | [Initialize-InstallAppArea](private/Initialize-InstallAppArea.ps1)、[Initialize-InstallAppEntry](private/Initialize-InstallAppEntry.ps1) | [Set-WinUtilWindowBounds](private/Set-WinUtilWindowBounds.ps1)、[Invoke-WinUtilFontScaling](private/Invoke-WinUtilFontScaling.ps1)、[Invoke-WinutilThemeChange](private/Invoke-WinutilThemeChange.ps1)、[Set-Preferences](private/Set-Preferences.ps1) |
| 后台任务与界面线程 | [Invoke-WPFRunspace](public/Invoke-WPFRunspace.ps1)、[Invoke-WPFUIThread](public/Invoke-WPFUIThread.ps1) | [Complete-WinUtilRunspaceJobs](private/Complete-WinUtilRunspaceJobs.ps1)、[Initialize-WinUtilPackageUiCallbacks](private/Initialize-WinUtilPackageUiCallbacks.ps1)、[Initialize-WinUtilTweakUiCallbacks](private/Initialize-WinUtilTweakUiCallbacks.ps1) |
| 修复、系统功能与更新 | [Invoke-WPFSystemRepair](public/Invoke-WPFSystemRepair.ps1)、[Invoke-WPFFeatureInstall](public/Invoke-WPFFeatureInstall.ps1) | [网络修复](public/Invoke-WPFFixesNetwork.ps1)、[更新修复](public/Invoke-WPFFixesUpdate.ps1)、[WinGet 修复](public/Invoke-WPFFixesWinget.ps1)、[功能执行](private/Invoke-WinUtilFeatureInstall.ps1)、[恢复默认更新](public/Invoke-WPFUpdatesdefault.ps1) |
| Windows 镜像与启动盘 | [Invoke-WinUtilISO](private/Invoke-WinUtilISO.ps1) | [Invoke-WinUtilISOScript](private/Invoke-WinUtilISOScript.ps1)、[Invoke-WinUtilISOUSB](private/Invoke-WinUtilISOUSB.ps1)；相关模板在 [tools/autounattend.xml](../tools/autounattend.xml) |
| 自动模式及其他独立工具 | [Invoke-WinUtilAutoRun](public/Invoke-WinUtilAutoRun.ps1) | [PowerShell 配置安装](private/Invoke-WinUtilInstallPSProfile.ps1)、[SSH 服务](private/Invoke-WinUtilSSHServer.ps1)、[电源计划](public/Invoke-WPFUltimatePerformance.ps1)、[O&O 工具入口](public/Invoke-WPFOOSU.ps1) |

## 修改时的关联位置

- 配置和界面：软件、组合、设置数据在 [config](../config/)，界面骨架在 [xaml/inputXML.xaml](../xaml/inputXML.xaml)，启动与事件注册在 [scripts](../scripts/)。
- 构建：[Compile.ps1](../Compile.ps1) 递归读取这里的 `.ps1` 文件；不要把测试 fixture、历史代码或实验脚本放进 `functions/`。
- 翻译：[汉化层](../汉化/README.md) 和测试引用具体路径。移动函数前必须联动调用、翻译、生成文档和测试；只看编译器支持递归还不够。
- 测试：[pester](../pester/) 覆盖计划、退出码、恢复、界面与自动化边界；隔离场景脚本放 [pester/fixtures](../pester/fixtures/)。入口为 [tools/Invoke-Tests.ps1](../tools/Invoke-Tests.ps1)。

软件任务的结果表示包管理器返回状态，不是事务回滚；系统设置历史只覆盖已登记的注册表和服务启动配置。阅读或扩展功能时，应保留这些结果与恢复边界。全仓库职责见[目录说明](../docs/REPOSITORY.md)。
