<#
.SYNOPSIS
    编译 WinUtil-CN 自包含启动器：把 winutil-cn.ps1 作为嵌入资源打进单个 EXE。

.DESCRIPTION
    使用 Windows 自带的 .NET Framework C# 编译器（csc.exe），产物不依赖任何额外运行时——
    .NET Framework 4.x 在所有 Windows 10/11 上均预装。CI 与本地均可调用。

.PARAMETER ScriptPath
    要嵌入的脚本（默认取仓库根的构建产物 winutil-cn.ps1）。

.PARAMETER OutFile
    输出的 EXE 路径（默认写到仓库根 WinUtil-CN.exe）。
#>
[CmdletBinding()]
param(
    [string]$ScriptPath,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $ScriptPath) { $ScriptPath = Join-Path $repoRoot 'winutil-cn.ps1' }
if (-not $OutFile)    { $OutFile    = Join-Path $repoRoot 'WinUtil-CN.exe' }

if (-not (Test-Path $ScriptPath)) {
    throw "找不到要嵌入的脚本：$ScriptPath（请先构建 winutil-cn.ps1）"
}

$csc = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { throw '未找到 .NET Framework C# 编译器 csc.exe' }

$src      = Join-Path $PSScriptRoot 'Launcher.cs'
$manifest = Join-Path $PSScriptRoot 'app.manifest'

# /resource:<文件>,<逻辑名> —— 逻辑名须与 Launcher.cs 里 ScriptResource 常量一致。
& $csc /nologo /target:exe /platform:anycpu /optimize+ `
    "/win32manifest:$manifest" `
    "/resource:$ScriptPath,WinUtilCN.winutil-cn.ps1" `
    "/out:$OutFile" `
    $src
if ($LASTEXITCODE -ne 0) { throw "csc 编译失败（退出码 $LASTEXITCODE）" }

$item = Get-Item $OutFile
$sha  = (Get-FileHash $OutFile -Algorithm SHA256).Hash
Write-Host ("编译完成: {0}  {1:N0} 字节" -f $item.Name, $item.Length)
Write-Host ("SHA256  : $sha")
