function Get-WinUtilTweakHistory {
    <# .SYNOPSIS Reads structured records only; no recorded scripts are executed. #>
    param([string]$TweakId, [string]$Directory = (Join-Path $env:LOCALAPPDATA 'WinUtil\TweakHistory'))
    if (-not (Test-Path -LiteralPath $Directory)) { return }
    $records = foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter '*.clixml' -File -ErrorAction Stop) {
        try {
            $record = Import-Clixml -LiteralPath $file.FullName -ErrorAction Stop
            if ($record.SchemaVersion -ne 1 -or $record.Id -notmatch '^[a-f0-9]{32}$') { throw '不支持的记录格式' }
            if (-not $TweakId -or $record.TweakId -eq $TweakId) { $record }
        } catch { Write-Warning "无法读取优化记录 $($file.Name)：$($_.Exception.Message)" }
    }
    $records | Sort-Object CreatedAt -Descending
}
