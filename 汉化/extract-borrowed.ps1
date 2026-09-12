# 兼容入口；维护实现已移到 maintenance/。旧位置仍支持第一个位置参数。
[CmdletBinding()]
param([Parameter(Position = 0)][string]$SourcePath, [string]$OutputPath)
& (Join-Path $PSScriptRoot 'maintenance/extract-borrowed.ps1') @PSBoundParameters
