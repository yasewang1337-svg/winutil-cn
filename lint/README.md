# PowerShell 静态分析设置

[settings.psd1](settings.psd1) 是 PSScriptAnalyzer 的数据配置文件，原名为 `PSScriptAnalyser.ps1`。它不是要执行的 PowerShell 脚本。

配置保留原有规则选择：使用默认规则，但排除 `PSAvoidUsingWriteHost`。这与程序的交互式终端输出相容；不表示其余诊断已经全部修复。

本机已安装 PSScriptAnalyzer 模块时，在仓库根目录运行：

```powershell
Import-Module PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path .\functions -Recurse -Settings .\lint\settings.psd1
```

仅检查配置是否能作为数据加载：

```powershell
Import-PowerShellDataFile .\lint\settings.psd1
```

当前配置供维护者按需使用，不是已接入 CI 的全仓库零告警门禁。发布回归测试仍以 [tools/Invoke-Tests.ps1](../tools/Invoke-Tests.ps1) 为入口。
