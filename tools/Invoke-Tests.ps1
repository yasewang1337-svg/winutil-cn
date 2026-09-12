[CmdletBinding()]
param([string]$PesterModule)

$ErrorActionPreference = 'Stop'
# Pester executes these files directly. PowerShell 5.1 needs a BOM for non-ASCII
# test text even though application sources are explicitly loaded as UTF-8.
$testRoot = Join-Path $PSScriptRoot '../pester'
foreach ($testFile in Get-ChildItem -LiteralPath $testRoot -Filter '*.ps1' -Recurse) {
    $bytes = [IO.File]::ReadAllBytes($testFile.FullName)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    if (-not $hasBom -and [IO.File]::ReadAllText($testFile.FullName) -match '[^\x00-\x7F]') {
        throw "Non-ASCII PowerShell test files must use UTF-8 with BOM: $($testFile.FullName)"
    }
}
if ($PesterModule) {
    Import-Module $PesterModule -MinimumVersion 5.7.1 -Force
} else {
    Import-Module Pester -RequiredVersion 5.7.1 -Force
}
$configuration = New-PesterConfiguration
$configuration.Run.Path = $testRoot
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Normal'
# All registry scenarios are mocked. Avoid touching HKCU even for test setup.
$configuration.TestRegistry.Enabled = $false
$result = Invoke-Pester -Configuration $configuration
if ($result.TotalCount -eq 0 -or $result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
    throw "测试失败：$($result.FailedCount) 失败 / $($result.TotalCount) 总数，$($result.FailedContainersCount) 个文件失败。"
}
Write-Output "PowerShell $($PSVersionTable.PSVersion)：$($result.PassedCount) 项测试通过。"
