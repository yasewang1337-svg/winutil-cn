# 中文版维护与验证

## 2026-09 可靠性维护

- 启动开关探测只读取指定注册表值，不枚举无关值、不创建注册表键。值损坏或无权限时记录包含路径和值名的警告并继续加载；缺失值采用配置默认值。对应 [Issue #6](https://github.com/yasewang1337-svg/winutil-cn/issues/6)。
- 一键命令提权后仍使用中文版，带单引号的脚本与配置路径会正确转义。
- 编译从脚本所在目录读取源文件，明确使用 UTF-8，校验 JSON、XML、PowerShell 语法后才替换产物。失败会保留上次完整产物并返回错误；旧产物不能当成本次成功构建。
- 运行时翻译数据采用仓库相对路径，支持换目录构建和幂等执行。
- CI 在 Windows PowerShell 5.1 与 PowerShell 7 上运行回归测试，测试失败或未发现测试时阻止发布。产物附 `SHA256SUMS.txt`，Defender 扫描状态如实记录，保留历史发布供回退。

## 验证入口

构建与以下测试不需要管理员权限，不会执行系统优化或安装应用。测试中的注册表场景使用模拟对象；WPF 测试加载窗口结构但不显示窗口。

```powershell
Save-Module Pester -RequiredVersion 5.7.1 -Path .artifacts/test-modules
pwsh -NoProfile -File 汉化\run-all.ps1
pwsh -NoProfile -File tools\Invoke-Tests.ps1 -PesterModule .artifacts/test-modules/Pester/5.7.1/Pester.psd1
powershell -NoProfile -File tools\Invoke-Tests.ps1 -PesterModule .artifacts/test-modules/Pester/5.7.1/Pester.psd1
pwsh -NoProfile -File tools\Test-Build.ps1
powershell -NoProfile -File tools\Test-Build.ps1
```

EXE 使用 .NET SDK 构建，目标为系统自带的 .NET Framework 4.8：

```powershell
Copy-Item winutil.ps1 winutil-cn.ps1
pwsh -NoProfile -File tools\launcher\build.ps1
```

测试覆盖源文件语法、编译失败、编码、配置/装机组合引用、注册表探测、汉化可移植性与 XAML 加载。系统优化实际效果、第三方安装程序、完整交互操作仍需在测试虚拟机上验证；不能用自动测试结果替代真机效果验证。

## 上游迁移状态

截至 2026-09-12，核对的上游稳定版为 [26.08.19](https://github.com/ChrisTitusTech/winutil/releases/tag/26.08.19)。中文版基线 `7ca2ed8` 与该版本的共同祖先为 `58a81b1`；其后的上游变更为 170 个提交、362 个文件。

本轮没有完成整个上游版本迁移。待处理范围包括：

1. UI 延迟加载、侧栏及选择状态重构，保持中文控件绑定、品牌主题和装机组合可用。
2. 新增/移除的软件、Appx 页面、DNS 与优化项变更；核对翻译与旧配置导入。
3. 上游文档从 Hugo 迁移至 Astro 后，保留中文文档和现有链接的可达性。
4. 引入适用的上游回归用例，并在 Windows 11 虚拟机验证 GUI、安装、回滚与 Win11 创建器。

进度跟踪于 [Issue #5](https://github.com/yasewang1337-svg/winutil-cn/issues/5)。在上述兼容性验证完成前，不将选择性修复标记为“已同步最新上游”。
