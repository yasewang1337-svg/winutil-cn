[CmdletBinding()]
param(
    [string]$DiffPath,
    [string]$BaseRef,
    [string]$TargetRef,
    [string]$RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$RepositoryRoot = Resolve-WinUtilTranslationFileSystemPath -Path $RepositoryRoot
if (-not $OutputPath) { $OutputPath = Join-Path $RepositoryRoot '汉化/i18n-functions.json' }
$OutputPath = Resolve-WinUtilTranslationFileSystemPath -Path $OutputPath
if ((-not $DiffPath -and -not $BaseRef) -or ($DiffPath -and $BaseRef) -or ($TargetRef -and -not $BaseRef)) {
    throw '必须明确提供 -DiffPath，或 -BaseRef（可选 -TargetRef）；不再默认读取未提交差异。'
}

if ($DiffPath) {
    $DiffPath = Resolve-WinUtilTranslationFileSystemPath -Path $DiffPath
    $diff = [IO.File]::ReadAllText($DiffPath, [Text.UTF8Encoding]::new($false, $true))
} else {
    $revisions = @()
    foreach ($revision in @($BaseRef, $TargetRef)) {
        if (-not $revision) { continue }
        $resolved = (Invoke-WinUtilTranslationGit -Arguments @('-C', $RepositoryRoot, 'rev-parse', '--verify', '--end-of-options', "$revision^{commit}")).Trim()
        if ($resolved -notmatch '^[a-fA-F0-9]{40,64}$') { throw "Git 版本无效：$revision" }
        $revisions += $resolved
    }
    $arguments = @('-C', $RepositoryRoot, '-c', 'core.quotepath=false', 'diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--unified=0') + $revisions + @('--', 'functions/')
    $diff = Invoke-WinUtilTranslationGit -Arguments $arguments
}

function Get-TranslationLiteralPairs {
    param([string]$File, [string[]]$Removed, [string[]]$Added)
    if (-not $Removed.Count -or -not $Added.Count) { return }
    # Pair only within one changed block. Unequal blocks may include logic changes and are not inferred.
    if ($Removed.Count -ne $Added.Count) { throw "差异块增删行数不同，无法可靠配对：$File。请提供仅含文本替换的 diff。" }
    for ($lineIndex = 0; $lineIndex -lt $Removed.Count; $lineIndex++) {
        $oldTokens = $null; $newTokens = $null
        $null = [Management.Automation.Language.Parser]::ParseInput($Removed[$lineIndex], [ref]$oldTokens, [ref]$null)
        $null = [Management.Automation.Language.Parser]::ParseInput($Added[$lineIndex], [ref]$newTokens, [ref]$null)
        $oldStrings = @($oldTokens | Where-Object { $_.Kind -eq 'StringExpandable' -and $_.Text.StartsWith('"') -and $_.Text.EndsWith('"') })
        $newStrings = @($newTokens | Where-Object { $_.Kind -eq 'StringExpandable' -and $_.Text.StartsWith('"') -and $_.Text.EndsWith('"') })
        if ($oldStrings.Count -ne $newStrings.Count) { throw "字符串数量不同，无法可靠配对：$File。" }
        for ($stringIndex = 0; $stringIndex -lt $oldStrings.Count; $stringIndex++) {
            $en = $oldStrings[$stringIndex].Text.Substring(1, $oldStrings[$stringIndex].Text.Length - 2)
            $zh = $newStrings[$stringIndex].Text.Substring(1, $newStrings[$stringIndex].Text.Length - 2)
            if ($en -cne $zh -and $zh -match '\p{IsCJKUnifiedIdeographs}') {
                $oldExpressions = @($oldStrings[$stringIndex].NestedTokens | ForEach-Object Text) -join [char]0
                $newExpressions = @($newStrings[$stringIndex].NestedTokens | ForEach-Object Text) -join [char]0
                if ($oldExpressions -cne $newExpressions) { throw "替换改变了字符串中的变量或表达式：$File。请只提供显示文本变化。" }
                [pscustomobject]@{ file = $File; en = $en; zh = $zh; kind = 'runtime' }
            }
        }
    }
}

$items = [Collections.Generic.List[object]]::new()
$file = ''; $removed = @(); $added = @(); $inHunk = $false; $sawDiffHeader = $false
foreach ($line in @($diff -split '\r?\n') + @('@@ end @@')) {
    if ($line.StartsWith('diff --git ') -or $line.StartsWith('@@') -or ($inHunk -and -not $line.StartsWith('-') -and -not $line.StartsWith('+') -and -not $line.StartsWith('\'))) {
        foreach ($entry in @(Get-TranslationLiteralPairs -File $file -Removed $removed -Added $added)) { $items.Add($entry) }
        $removed = @(); $added = @()
    }
    if ($line.StartsWith('diff --git ')) { $inHunk = $false; $file = ''; $sawDiffHeader = $true; continue }
    if ($line.StartsWith('+++ ')) {
        $target = $line.Substring(4)
        if ($target -eq '/dev/null') { $file = ''; continue }
        if (-not $target.StartsWith('b/')) { throw '差异路径必须使用 git diff 默认的 a/、b/ 前缀。' }
        $file = Resolve-WinUtilTranslationFunctionPath -Path $target.Substring(2) -RepositoryRoot $RepositoryRoot
        continue
    }
    if ($line.StartsWith('@@')) { $inHunk = [bool]$file; continue }
    if ($inHunk -and $line.StartsWith('-')) { $removed += $line.Substring(1) }
    elseif ($inHunk -and $line.StartsWith('+')) { $added += $line.Substring(1) }
}
if (-not $sawDiffHeader -or $items.Count -eq 0) { throw '未提取到运行时中文替换，原翻译表已保留。请检查明确指定的 diff 或版本范围。' }

$existing = @()
if (Test-Path -LiteralPath $OutputPath) {
    $existing = Read-WinUtilTranslationJson -Path $OutputPath
    if ($existing -isnot [array]) { throw '现有运行时翻译表必须是 JSON 数组。' }
}
$merged = Merge-WinUtilFunctionTranslations -Existing $existing -Incoming $items.ToArray() -RepositoryRoot $RepositoryRoot
$json = ConvertTo-Json -InputObject @($merged) -Depth 6
Write-WinUtilTranslationJson -Path $OutputPath -Json $json -Validate {
    param($parsed)
    if ($parsed -isnot [array] -or $parsed.Count -eq 0) { throw '生成的运行时翻译表为空或格式错误。' }
    $null = Merge-WinUtilFunctionTranslations -Existing $parsed -Incoming @() -RepositoryRoot $RepositoryRoot
}
Write-Output "已提取 $($items.Count) 对，合并后 $($merged.Count) 条运行时翻译：$OutputPath"
