function Get-WinUtilStartupCrown {
    # Single-width ASCII keeps the silhouette aligned in every console code page.
    @(
        '                /\                '
        '       /\      /  \      /\       '
        '       \/ \   /    \   / \/       '
        '        \  \_/      \_/  /        '
        '         \              /         '
        "          '------------'          "
        '          | <>  <>  <> |          '
        "          '------------'          "
    )
}

function Test-WinUtilStartupAnimation {
    # Native console drawing works in the launcher's Windows PowerShell 5.1
    # window as well as Windows Terminal. No VT mode or encoding changes needed.
    if ($Host.Name -ne 'ConsoleHost' -or $env:NO_COLOR -or $env:TERM -eq 'dumb') { return $false }
    try {
        return -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected -and
            [Console]::WindowWidth -ge 38 -and [Console]::WindowHeight -ge 13
    } catch { return $false }
}

function Write-WinUtilStartupCrownFrame {
    param([string[]]$Lines, [int]$Top, [int]$Sweep = -10)

    for ($row = 0; $row -lt $Lines.Count; $row++) {
        [Console]::SetCursorPosition(2, $Top + $row)
        $line = $Lines[$row]
        # A narrow warm-white reflection travels across a steady gold outline.
        $start = [math]::Max(0, [math]::Min($line.Length, $Sweep - 2))
        $end = [math]::Max($start, [math]::Min($line.Length, $Sweep + 3))
        [Console]::ForegroundColor = [ConsoleColor]::Yellow
        [Console]::Write($line.Substring(0, $start))
        [Console]::ForegroundColor = [ConsoleColor]::White
        [Console]::Write($line.Substring($start, $end - $start))
        [Console]::ForegroundColor = [ConsoleColor]::Yellow
        [Console]::Write($line.Substring($end))
    }
}

function Invoke-WinUtilStartupCrownAnimation {
    param([string[]]$Lines)

    $originalColor = [Console]::ForegroundColor
    $originalCursorVisible = [Console]::CursorVisible
    $endRow = -1
    try {
        [Console]::CursorVisible = $false
        # Reserve the whole block first. This also handles a console near its
        # bottom edge without redrawing unrelated startup output above it.
        foreach ($line in $Lines) { [Console]::WriteLine('') }
        $endRow = [Console]::CursorTop
        $top = $endRow - $Lines.Count
        if ($top -lt 0) { throw 'The console cannot reserve space for the crown.' }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        for ($frame = 0; $frame -lt 8; $frame++) {
            if ([Console]::WindowWidth -lt 38 -or [Console]::WindowHeight -lt 13) {
                throw 'The console became too small for the animation.'
            }
            Write-WinUtilStartupCrownFrame -Lines $Lines -Top $top -Sweep ($frame * 5 - 1)
            # Do not accumulate render time on slower consoles. The decoration
            # adds at most a 240 ms sleep budget and never waits for user input.
            $remaining = ($frame + 1) * 30 - $clock.ElapsedMilliseconds
            if ($remaining -gt 0) { Start-Sleep -Milliseconds $remaining }
        }
        Write-WinUtilStartupCrownFrame -Lines $Lines -Top $top
    } finally {
        try { [Console]::ForegroundColor = $originalColor } catch {}
        try { [Console]::CursorVisible = $originalCursorVisible } catch {}
        if ($endRow -ge 0) {
            try { [Console]::SetCursorPosition(0, [math]::Min($endRow, [Console]::BufferHeight - 1)) } catch {}
        }
    }
}

function Show-WinUtilStartupBanner {
    param([switch]$Static)

    $lines = @(Get-WinUtilStartupCrown)
    Write-Host ''
    $drawn = $false
    if (-not $Static -and (Test-WinUtilStartupAnimation)) {
        try {
            Invoke-WinUtilStartupCrownAnimation -Lines $lines
            $drawn = $true
        } catch {
            # A detached/resized terminal must never stop the actual application.
        }
    }
    if (-not $drawn) {
        foreach ($line in $lines) { Write-Host ('  ' + $line.TrimEnd()) }
    }
    Write-Host '             yesewang1337'
    Write-Host '              WinUtil-CN'
    Write-Host ''
}
