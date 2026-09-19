[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '../functions/private/Invoke-WinUtilVerifiedTool.ps1'),
    [string]$TemplatePath = (Join-Path $PSScriptRoot 'autounattend.xml'),
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText($SourcePath, [Text.UTF8Encoding]::new($false, $true)).Replace("`r`n", "`n").Trim()
if ([string]::IsNullOrWhiteSpace($source)) { throw '工具校验源码为空，未修改无人值守模板。' }
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw '工具校验源码存在语法错误，未修改无人值守模板。' }

$template = [IO.File]::ReadAllText($TemplatePath, [Text.UTF8Encoding]::new($false, $true))
$document = [xml]$template
$targetPath = 'C:\Windows\Setup\Scripts\WinUtilVerifiedTool.ps1'
$nodes = @($document.SelectNodes('//*[local-name()="File" and @path="C:\Windows\Setup\Scripts\WinUtilVerifiedTool.ps1"]'))
if ($nodes.Count -gt 1) { throw '无人值守模板包含重复的工具校验脚本。' }
$matchesSource = $nodes.Count -eq 1 -and $nodes[0].InnerText.Replace("`r`n", "`n").Trim() -ceq $source
if ($Check) {
    if (-not $matchesSource) { throw '无人值守模板的工具校验脚本缺失或与源码不同，请先运行 tools/Sync-VerifiedToolTemplate.ps1。' }
    Write-Output '无人值守模板的工具校验脚本与源码一致。'
    return
}
if ($matchesSource) {
    Write-Output '无人值守模板的工具校验脚本已是最新。'
    return
}

# Copy text only; never dot-source or execute a tool while updating the template.
$escapedSource = [Security.SecurityElement]::Escape($source).Replace("`n", "`r`n")
$replacement = '<File path="' + $targetPath + '">' + "`r`n" + $escapedSource + "`r`n        </File>"
if ($nodes.Count -eq 1) {
    $pattern = '(?s)<File\s+path="' + [regex]::Escape($targetPath) + '"\s*>.*?</File>'
    if ([regex]::Matches($template, $pattern).Count -ne 1) { throw '无法唯一定位模板工具脚本，未修改文件。' }
    $updated = [regex]::Replace($template, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
} else {
    if ([regex]::Matches($template, '</Extensions>').Count -ne 1) { throw '无法唯一定位无人值守模板 Extensions，未修改文件。' }
    $updated = $template.Replace('    </Extensions>', '        ' + $replacement + "`r`n    </Extensions>")
}
$updatedDocument = [xml]$updated
$updatedNodes = @($updatedDocument.SelectNodes('//*[local-name()="File" and @path="C:\Windows\Setup\Scripts\WinUtilVerifiedTool.ps1"]'))
if ($updatedNodes.Count -ne 1 -or $updatedNodes[0].InnerText.Replace("`r`n", "`n").Trim() -cne $source) {
    throw '更新后的无人值守模板校验失败，未修改文件。'
}
[IO.File]::WriteAllText($TemplatePath, $updated, [Text.UTF8Encoding]::new($false))
Write-Output '已同步无人值守模板的工具校验脚本。'
