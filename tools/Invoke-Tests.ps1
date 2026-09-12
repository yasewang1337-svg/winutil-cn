[CmdletBinding()]
param([string]$PesterModule)

$ErrorActionPreference = 'Stop'
if ($PesterModule) {
    Import-Module $PesterModule -MinimumVersion 5.7.1 -Force
} else {
    Import-Module Pester -RequiredVersion 5.7.1 -Force
}
$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path $PSScriptRoot '../pester'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Normal'
# All registry scenarios are mocked. Avoid touching HKCU even for test setup.
$configuration.TestRegistry.Enabled = $false
$result = Invoke-Pester -Configuration $configuration
if ($result.TotalCount -eq 0 -or $result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
    throw "测试失败：$($result.FailedCount) 失败 / $($result.TotalCount) 总数，$($result.FailedContainersCount) 个文件失败。"
}
Write-Output "PowerShell $($PSVersionTable.PSVersion)：$($result.PassedCount) 项测试通过。"
