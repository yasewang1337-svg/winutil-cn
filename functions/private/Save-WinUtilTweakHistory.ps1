function Save-WinUtilTweakHistory {
    <# .SYNOPSIS Persists snapshots before mutation, preserving byte arrays and registry types. #>
    param($Record, [string]$Directory = (Join-Path $env:LOCALAPPDATA 'WinUtil\TweakHistory'))
    if ($Record.Id -notmatch '^[a-f0-9]{32}$') { throw '无效的优化记录编号。' }
    [System.IO.Directory]::CreateDirectory($Directory) | Out-Null
    $destination = Join-Path $Directory ($Record.Id + '.clixml')
    $temporary = Join-Path $Directory ($Record.Id + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $Record | Export-Clixml -LiteralPath $temporary -Depth 20 -Encoding UTF8 -ErrorAction Stop
        if ([System.IO.File]::Exists($destination)) {
            [System.IO.File]::Replace($temporary, $destination, [NullString]::Value)
        } else { [System.IO.File]::Move($temporary, $destination) }
    } finally {
        if ([System.IO.File]::Exists($temporary)) { [System.IO.File]::Delete($temporary) }
    }
}
