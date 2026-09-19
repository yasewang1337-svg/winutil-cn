# 中文版维护与验证

## 当前维护入口

- [仓库结构](REPOSITORY.md)：源码、配置、测试、文档、构建与历史文件的职责。
- [工作流用途](../.github/WORKFLOWS.md)：中文版发布、回归、MCP 和上游保留流程。
- [文档说明](README.md)：用户指南、生成参考、本地 Hugo 预览。
- [汉化层](../汉化/README.md)：日常隔离构建、直接修改源码的 apply 工具，以及单独的翻译提取维护入口。

常规构建在临时副本中应用翻译和额外软件，成功后只替换根目录 `winutil.ps1`。不要把 `.artifacts/`、EXE、编译脚本、MCP data 或启动器 bin/obj 加入 Git；CI 会报告这类误提交，不再自动删除并推送。

开发参考通过 `tools/devdocs-generator.ps1` 从当前配置生成，路径由 `tools/devdocs-routes.json` 中的稳定项目 ID 映射决定；不要手动编辑生成正文，也不要在 config 顶层放归档或示例 JSON。生成器和翻译提取器在失败或零有效输出时保留既有内容。

## 2026-09 可靠性维护

- 启动开关探测只读取指定注册表值，不枚举无关值、不创建注册表键。值损坏或无权限时记录包含路径和值名的警告并继续加载；缺失值采用配置默认值。对应 [Issue #6](https://github.com/yasewang1337-svg/winutil-cn/issues/6)。
- 本地脚本提权使用当前 PowerShell 的绝对路径与 `-File`，正确引用脚本及参数；非管理员远程内存调用不会再自动下载并提权。
- 编译从脚本所在目录读取源文件，明确使用 UTF-8，校验 JSON、XML、PowerShell 语法后才替换产物。失败会保留上次完整产物并返回错误；旧产物不能当成本次成功构建。
- 运行时翻译数据采用仓库相对路径，支持换目录构建和幂等执行。
- CI 在 Windows PowerShell 5.1 与 PowerShell 7 上运行回归测试，测试失败或未发现测试时阻止发布。EXE 与 PS1 分别接受 Defender 扫描，扫描未完成、检出威胁或扫描后哈希变化均阻止发布；产物附 `SHA256SUMS.txt` 与 `security-scan.json`，保留历史发布供回退。告警与签名维护见[安全说明](SECURITY.md)。

## 验证入口

构建与以下测试不需要管理员权限，不会执行系统优化或安装应用。测试中的注册表场景使用模拟对象；WPF 测试加载窗口结构但不显示窗口。

```powershell
Save-Module Pester -RequiredVersion 5.7.1 -Path .artifacts/test-modules
pwsh -NoProfile -File 汉化\run-all.ps1
$testModule = (Resolve-Path '.artifacts/test-modules/Pester/5.7.1/Pester.psd1').Path
pwsh -NoProfile -File tools\Invoke-Tests.ps1 -PesterModule $testModule
powershell -NoProfile -File tools\Invoke-Tests.ps1 -PesterModule $testModule
pwsh -NoProfile -File tools\Test-Build.ps1
powershell -NoProfile -File tools\Test-Build.ps1
```

EXE 使用 .NET SDK 构建，目标为系统自带的 .NET Framework 4.8：

```powershell
Copy-Item winutil.ps1 winutil-cn.ps1
pwsh -NoProfile -File tools\launcher\build.ps1
```

测试覆盖源文件语法、编译失败与输入不变、编码、配置/装机组合引用、注册表探测、设置历史、软件执行结果、真实 worker/WPF 调度、翻译维护和文档生成的失败路径。中文测试文件必须保存为 UTF-8 BOM，避免英文 Windows 上的 PS 5.1 按默认 ANSI 解码。系统优化实际效果、第三方安装程序、完整交互操作仍需在测试虚拟机上验证；不能用自动测试结果替代真机效果验证。

## 上游迁移状态

截至 2026-09-12，核对的上游稳定版为 [26.08.19](https://github.com/ChrisTitusTech/winutil/releases/tag/26.08.19)。中文版基线 `7ca2ed8` 与该版本的共同祖先为 `58a81b1`；其后的上游变更为 170 个提交、362 个文件。

本轮没有完成整个上游版本迁移。待处理范围包括：

1. UI 延迟加载、侧栏及选择状态重构，保持中文控件绑定、品牌主题和装机组合可用。
2. 新增/移除的软件、Appx 页面、DNS 与优化项变更；核对翻译与旧配置导入。
3. 上游文档从 Hugo 迁移至 Astro 后，保留中文文档和现有链接的可达性。
4. 引入适用的上游回归用例，并在 Windows 11 虚拟机验证 GUI、安装、回滚与 Win11 创建器。

进度跟踪于 [Issue #5](https://github.com/yasewang1337-svg/winutil-cn/issues/5)。在上述兼容性验证完成前，不将选择性修复标记为“已同步最新上游”。
