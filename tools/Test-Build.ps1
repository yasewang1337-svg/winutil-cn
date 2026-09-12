[CmdletBinding()]
param([string]$Path)
$ErrorActionPreference = 'Stop'
if (-not $Path) { $Path = Join-Path $PSScriptRoot '../winutil.ps1' }
$Path = (Resolve-Path -LiteralPath $Path).Path
$bytes = [IO.File]::ReadAllBytes($Path)
if ($bytes.Length -lt 3 -or ($bytes[0..2] -join ',') -ne '239,187,191') {
    throw '中文版构建产物必须为 UTF-8 BOM。'
}
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
if ($errors.Count) { throw "PowerShell $($PSVersionTable.PSVersion) 语法检查失败：$($errors | Out-String)" }
Write-Output "PowerShell $($PSVersionTable.PSVersion)：语法及 UTF-8 BOM 检查通过。"
