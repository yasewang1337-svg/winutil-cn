# 兼容入口；维护实现已移到 maintenance/。必须显式提供输入，见 README。
[CmdletBinding()]
param([string]$DiffPath, [string]$BaseRef, [string]$TargetRef, [string]$RepositoryRoot, [string]$OutputPath)
& (Join-Path $PSScriptRoot 'maintenance/extract-functions-i18n.ps1') @PSBoundParameters
