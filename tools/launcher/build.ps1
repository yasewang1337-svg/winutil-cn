<#
.SYNOPSIS
    编译 WinUtil-CN 自包含启动器：把 winutil-cn.ps1 作为嵌入资源打进单个 EXE。

.DESCRIPTION
    用现代 .NET SDK（Roslyn，LangVersion=latest）编译，目标 net48——
    .NET Framework 4.x 在所有 Windows 10/11 上预装，产物无需安装任何运行时。CI 与本地均可调用。

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
# 解析成绝对路径：否则 MSBuild 会把相对路径当成相对于 .csproj 目录，导致嵌入资源找不到。
$ScriptPath = (Resolve-Path $ScriptPath).Path
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw '未找到 dotnet SDK（编译启动器需要 .NET SDK）'
}

$proj   = Join-Path $PSScriptRoot 'WinUtilCN.Launcher.csproj'
$outDir = Join-Path $PSScriptRoot 'bin\Release'

Write-Host ("编译器: dotnet {0} (Roslyn / 最新 C#)" -f (dotnet --version))
dotnet build $proj -c Release --nologo -v minimal `
    "-p:ScriptPath=$ScriptPath" `
    "-p:OutDir=$outDir\"
if ($LASTEXITCODE -ne 0) { throw "dotnet build 失败（退出码 $LASTEXITCODE）" }

$built = Join-Path $outDir 'WinUtil-CN.exe'
if (-not (Test-Path $built)) { throw "未在 $outDir 找到 WinUtil-CN.exe" }
Copy-Item $built $OutFile -Force

$item = Get-Item $OutFile
$sha  = (Get-FileHash $OutFile -Algorithm SHA256).Hash
Write-Host ("编译完成: {0}  {1:N0} 字节" -f $item.Name, $item.Length)
Write-Host ("SHA256  : $sha")
