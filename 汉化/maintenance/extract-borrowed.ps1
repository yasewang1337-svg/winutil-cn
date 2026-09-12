[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$SourcePath,
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'i18n-borrowed.json')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $SourcePath) { throw '必须明确提供 -SourcePath，指向需要提取的中文编译脚本；没有机器专属默认路径。' }
$SourcePath = Resolve-WinUtilTranslationFileSystemPath -Path $SourcePath
$OutputPath = Resolve-WinUtilTranslationFileSystemPath -Path $OutputPath
$raw = [IO.File]::ReadAllText($SourcePath, [Text.UTF8Encoding]::new($false, $true))
$pattern = '(?ms)^\s*\$sync\.configs\.(tweaks|feature)\s*=\s*@''\r?\n(.*?)\r?\n''@'
$result = [ordered]@{ tweaks = [ordered]@{}; feature = [ordered]@{} }

function Merge-BorrowedTranslationObject {
    param($Value)
    if ($null -eq $Value -or $Value -is [array] -or $Value -isnot [pscustomobject]) { throw '借用翻译表必须是按 tweaks / feature 分组的 JSON 对象。' }
    foreach ($section in $Value.PSObject.Properties) {
        if ($section.Name -notin @('tweaks', 'feature')) { throw "未知翻译分组：$($section.Name)" }
        if ($section.Value -isnot [pscustomobject]) { throw "翻译分组格式无效：$($section.Name)" }
        foreach ($entry in $section.Value.PSObject.Properties) {
            if ($entry.Name -notmatch '^WPF[A-Za-z0-9_]+$' -or $entry.Value -isnot [pscustomobject]) { throw "无效的稳定控件编号：$($entry.Name)" }
            if (-not $result[$section.Name].Contains($entry.Name)) { $result[$section.Name][$entry.Name] = [ordered]@{} }
            foreach ($field in $entry.Value.PSObject.Properties) {
                if ($field.Name -notin @('Content', 'Description') -or $field.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($field.Value)) { throw "无效翻译字段：$($entry.Name).$($field.Name)" }
                $result[$section.Name][$entry.Name][$field.Name] = $field.Value
            }
        }
    }
}
if (Test-Path -LiteralPath $OutputPath) { Merge-BorrowedTranslationObject (Read-WinUtilTranslationJson -Path $OutputPath) }
$seenSections = @{}; $count = 0
foreach ($match in [regex]::Matches($raw, $pattern)) {
    $section = $match.Groups[1].Value
    if ($seenSections.ContainsKey($section)) { throw "输入脚本包含重复的 $section 配置，未写入翻译表。" }
    $seenSections[$section] = $true
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ("winutil-translation-$([guid]::NewGuid().ToString('N')).json")
    try {
        [IO.File]::WriteAllText($temporary, $match.Groups[2].Value, [Text.UTF8Encoding]::new($false))
        $configuration = Read-WinUtilTranslationJson -Path $temporary
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    if ($configuration -isnot [pscustomobject]) { throw "输入脚本的 $section 配置必须是 JSON 对象。" }
    $incoming = [ordered]@{}
    foreach ($property in $configuration.PSObject.Properties) {
        $fields = [ordered]@{}
        foreach ($field in @('Content', 'Description')) {
            if ($property.Value.$field -is [string] -and $property.Value.$field -match '\p{IsCJKUnifiedIdeographs}') { $fields[$field] = $property.Value.$field; $count++ }
        }
        if ($fields.Count) { $incoming[$property.Name] = [pscustomobject]$fields }
    }
    Merge-BorrowedTranslationObject ([pscustomobject]@{ $section = [pscustomobject]$incoming })
}
if ($count -eq 0) { throw '未提取到中文 Content / Description，原借用翻译表已保留。' }
$json = ConvertTo-Json -InputObject $result -Depth 8
Write-WinUtilTranslationJson -Path $OutputPath -Json $json -Validate { param($parsed) if ($parsed -isnot [pscustomobject]) { throw '生成的借用翻译格式错误。' } }
Write-Output "已提取并合并 $count 个中文字段：$OutputPath"
