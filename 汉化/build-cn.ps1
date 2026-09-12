# 构建中文版。读取、JSON、XML 或 PowerShell 语法错误都必须中止。
# 不允许发布缺少函数或沿用上次产物的半成品。
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& (Join-Path $root 'Compile.ps1')
$output = Join-Path $root 'winutil.ps1'
if (-not (Test-Path -LiteralPath $output)) { throw 'Compile.ps1 未生成 winutil.ps1' }
Write-Output ("中文版：{0:N0} 字节" -f (Get-Item -LiteralPath $output).Length)
