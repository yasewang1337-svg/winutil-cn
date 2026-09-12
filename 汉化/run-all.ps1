# 在临时副本中应用中文数据并编译，仅将验证成功的 winutil.ps1 发布到仓库根目录。
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stageName = 'winutil-cn-build-' + [guid]::NewGuid().ToString('N')
$stage = Join-Path $tempRoot $stageName
$output = Join-Path $root 'winutil.ps1'
$publishTemporary = "$output.$([guid]::NewGuid().ToString('N')).tmp"
try {
    $null = New-Item -ItemType Directory -Path $stage -ErrorAction Stop
    foreach ($directory in @('functions', 'config', 'scripts', 'xaml')) {
        $source = Join-Path $root $directory
        if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "缺少构建目录：$source" }
        if (@(Get-ChildItem -LiteralPath $source -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count -or
            ((Get-Item -LiteralPath $source -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "构建输入不允许链接到其他目录，请使用普通源码副本：$source"
        }
        Copy-Item -LiteralPath $source -Destination $stage -Recurse -Force
    }
    [IO.File]::WriteAllBytes((Join-Path $stage 'Compile.ps1'), [IO.File]::ReadAllBytes((Join-Path $root 'Compile.ps1')))
    $stageLocalization = Join-Path $stage '汉化'
    $stageTools = Join-Path $stage 'tools'
    $null = New-Item -ItemType Directory -Path $stageLocalization, $stageTools
    [IO.File]::WriteAllBytes((Join-Path $stageTools 'autounattend.xml'), [IO.File]::ReadAllBytes((Join-Path $root 'tools/autounattend.xml')))
    $steps = @('apply-categories.ps1', 'apply-xaml.ps1', 'apply-i18n.ps1', 'apply-apps.ps1', 'apply-extra-apps.ps1', 'apply-functions.ps1', 'build-cn.ps1')
    foreach ($name in $steps) { [IO.File]::WriteAllBytes((Join-Path $stageLocalization $name), [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $name))) }
    foreach ($data in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.json' -File) {
        [IO.File]::WriteAllBytes((Join-Path $stageLocalization $data.Name), [IO.File]::ReadAllBytes($data.FullName))
    }
    # PS 5.1 must not interpret UTF-8 script text as the local ANSI code page.
    foreach ($path in @((Join-Path $stage 'Compile.ps1')) + @($steps | ForEach-Object { Join-Path $stageLocalization $_ })) {
        $text = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false, $true))
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($true))
    }
    for ($index = 0; $index -lt $steps.Count; $index++) {
        Write-Output "[$($index + 1)/$($steps.Count)] 临时副本：$($steps[$index])"
        & (Join-Path $stageLocalization $steps[$index])
    }
    $built = Join-Path $stage 'winutil.ps1'
    if (-not (Test-Path -LiteralPath $built -PathType Leaf)) { throw '临时构建未生成 winutil.ps1，保留上一次成功产物。' }
    $bytes = [IO.File]::ReadAllBytes($built)
    if ($bytes.Length -le 3 -or $bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) {
        throw '临时产物不是有效的 UTF-8 BOM 脚本，保留上一次成功产物。'
    }
    $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($built), [ref]$null, [ref]$errors)
    if ($errors.Count) { throw "临时产物语法检查失败：$($errors | Out-String)" }
    [IO.File]::Copy($built, $publishTemporary)
    if ([IO.File]::Exists($output)) { [IO.File]::Replace($publishTemporary, $output, [NullString]::Value) }
    else { [IO.File]::Move($publishTemporary, $output) }
    Write-Output "构建完成：$output；源 config/functions/xaml 保持不变。"
} finally {
    if ([IO.File]::Exists($publishTemporary)) { [IO.File]::Delete($publishTemporary) }
    # Never recursively remove a path unless its final absolute target is this build's own temporary directory.
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    $allowedPrefix = $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedStage.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedStage) -ne $stageName) {
        Write-Warning "临时目录校验失败，未清理：$stage"
    } elseif (Test-Path -LiteralPath $resolvedStage -PathType Container) {
        try { Remove-Item -LiteralPath $resolvedStage -Recurse -Force -ErrorAction Stop }
        catch { Write-Warning "临时目录清理失败，可手动删除本次目录：$resolvedStage。$($_.Exception.Message)" }
    }
}
