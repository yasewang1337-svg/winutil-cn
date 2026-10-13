function Get-WinUtilStartupCrown {
    param([ValidateSet('Large', 'Compact', 'Minimal')][string]$Size = 'Large')

    # Single-width ASCII keeps all facets aligned in every console code page.
    switch ($Size) {
        'Large' { @(
            '                             /\                             '
            '                            /  \                            '
            '                            \  /                            '
            '                             \/                             '
            '   /\                        /\                        /\   '
            '  /  \                      /  \                      /  \  '
            '  \  / \                   / /\ \                   / \  /  '
            '   \/   \                 / /  \ \                 /   \/   '
            '     \   \               / /    \ \               /   /     '
            '      \   \             / /      \ \             /   /      '
            '       \   \           / /        \ \           /   /       '
            '        \   __________/ /          \ \__________   /        '
            '         \             /            \             /         '
            '          .======================================.          '
            '          |  <>  .   <>  .   <>   .  <>   .  <>  |          '
            '          |--------------------------------------|          '
            '          |  o   o   o   o   <>   o   o   o   o  |          '
            '          ''======================================''          '
        ) }
        'Compact' { @(
            '                /\                '
            '       /\      /  \      /\       '
            '       \/ \   /    \   / \/       '
            '        \  \_/      \_/  /        '
            '         \              /         '
            "          '------------'          "
            '          | <>  <>  <> |          '
            "          '------------'          "
        ) }
        'Minimal' { @(
            '  /\  /\  /\  '
            '  \ \/  \/ /  '
            "   '------'   "
            '   |<>  <>|   '
        ) }
    }
}

function Get-WinUtilStartupBannerLayout {
    param([int]$WindowWidth = 38, [int]$WindowHeight = 13)

    # A zero size means the stream has no terminal. Effective narrow sizes are
    # kept intact so even an eight-column window gets readable plain text.
    if ($WindowWidth -le 0) { $WindowWidth = 38 }
    if ($WindowHeight -le 0) { $WindowHeight = 13 }
    $size = if ($WindowWidth -ge 64 -and $WindowHeight -ge 22) { 'Large' }
        elseif ($WindowWidth -ge 38 -and $WindowHeight -ge 13) { 'Compact' }
        elseif ($WindowWidth -ge 18 -and $WindowHeight -ge 9) { 'Minimal' }
        else { 'Text' }
    $lines = @(if ($size -ne 'Text') { Get-WinUtilStartupCrown -Size $size })
    $width = if ($lines.Count) { $lines[0].Length } else { 0 }
    $captions = foreach ($caption in @('yesewang1337', 'WinUtil-CN')) {
        for ($offset = 0; $offset -lt $caption.Length; $offset += $WindowWidth) {
            $part = $caption.Substring($offset, [math]::Min($WindowWidth, $caption.Length - $offset))
            (' ' * [math]::Max(0, [math]::Floor(($WindowWidth - $part.Length) / 2))) + $part
        }
    }
    [pscustomobject]@{
        Size = $size
        Lines = @($lines)
        Left = [int][math]::Max(0, [math]::Floor(($WindowWidth - $width) / 2))
        Width = $width
        Height = @($lines).Count
        Captions = @($captions)
    }
}

function Test-WinUtilStartupAnimation {
    if ($Host.Name -ne 'ConsoleHost' -or $env:NO_COLOR -or $env:TERM -eq 'dumb') { return $false }
    try {
        return -not [Console]::IsOutputRedirected -and -not [Console]::IsInputRedirected -and
            [Console]::WindowWidth -ge 18 -and [Console]::WindowHeight -ge 9
    } catch { return $false }
}

function Get-WinUtilStartupCrownFrame {
    param($Layout, [double]$Progress = 1, [switch]$LightBackground)

    $progress = [math]::Max(0.0, [math]::Min(1.0, $Progress))
    $gold = if ($LightBackground) { [ConsoleColor]::DarkYellow } else { [ConsoleColor]::Yellow }
    $shadow = if ($LightBackground) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::DarkYellow }
    $light = if ($LightBackground) { [ConsoleColor]::Black } else { [ConsoleColor]::White }
    $rows = [Collections.Generic.List[object]]::new()
    for ($row = 0; $row -lt $Layout.Height; $row++) {
        $line = $Layout.Lines[$row]
        $colors = [ConsoleColor[]]::new($line.Length)
        $revealed = $progress -ge 0.27 -or $row -lt ($progress / 0.27 * $Layout.Height)
        for ($column = 0; $column -lt $line.Length; $column++) {
            $colors[$column] = if ($revealed) { $gold } else { $shadow }
        }
        if ($revealed -and $Layout.Size -eq 'Large') {
            # Dark inner edges and the second band make the gold surface read as
            # a metal crown; each faceted gem keeps a clear bright outline.
            if ($row -ge 6 -and $row -le 12) {
                $inner = 35 - $row
                $colors[$inner] = $shadow
                $colors[59 - $inner] = $shadow
            }
            if ($row -in @(13, 15, 16, 17)) {
                for ($column = 0; $column -lt $line.Length; $column++) { $colors[$column] = $shadow }
                if ($row -eq 16) { $colors[29] = $gold; $colors[30] = $gold }
            }
        }
        if ($progress -ge 0.27 -and $progress -lt 0.75) {
            # Bottom-left to top-right diagonal reflection, with a narrow bright
            # core; the original shaded surface remains visible around it.
            $sweep = (($progress - 0.27) / 0.48) * ($Layout.Width + 22) - 15
            $center = $sweep + ($row - $Layout.Height / 2) * 0.65
            for ($column = [math]::Max(0, [int][math]::Floor($center - 2)); $column -le [math]::Min($line.Length - 1, [int][math]::Ceiling($center + 2)); $column++) {
                $colors[$column] = $light
            }
        } elseif ($progress -ge 0.75 -and $progress -lt 1) {
            # Five short glints: central tip, paired side tips, outer gems,
            # inner gems, central gem. Symmetric pairs move as one beat.
            $beat = [math]::Min(4, [int][math]::Floor(($progress - 0.75) / 0.05))
            if ($Layout.Size -eq 'Large') {
                $glints = @(switch ($beat) {
                    0 { ,@(28, 31, 0, 3) }
                    1 { ,@(2, 5, 4, 7); ,@(54, 57, 4, 7) }
                    2 { ,@(13, 14, 14, 14); ,@(45, 46, 14, 14) }
                    3 { ,@(21, 22, 14, 14); ,@(37, 38, 14, 14) }
                    4 { ,@(29, 30, 14, 14); ,@(29, 30, 16, 16) }
                })
                foreach ($glint in $glints) {
                    if ($row -ge $glint[2] -and $row -le $glint[3]) {
                        for ($column = $glint[0]; $column -le $glint[1]; $column++) { $colors[$column] = $light }
                    }
                }
            } else {
                $gemColumn = [int][math]::Floor(($beat + 1) * $Layout.Width / 6)
                for ($column = [math]::Max(0, $gemColumn - 1); $column -le [math]::Min($line.Length - 1, $gemColumn + 1); $column++) {
                    if ($row -ge $Layout.Height - 3) { $colors[$column] = $light }
                }
            }
        }
        # Merge adjoining colors before any console IO: at most a handful of
        # Write calls per row, never one native call per individual character.
        $segments = [Collections.Generic.List[object]]::new()
        $start = 0
        for ($column = 1; $column -le $line.Length; $column++) {
            if ($column -eq $line.Length -or $colors[$column] -ne $colors[$start]) {
                $segments.Add([pscustomobject]@{ Text = $line.Substring($start, $column - $start); Color = $colors[$start] })
                $start = $column
            }
        }
        $rows.Add([pscustomobject]@{ Segments = $segments.ToArray() })
    }
    [pscustomobject]@{ Rows = $rows.ToArray() }
}

function Write-WinUtilStartupCrownFrame {
    param($Layout, [int]$Top, [double]$Progress = 1, [switch]$LightBackground)

    $frame = Get-WinUtilStartupCrownFrame -Layout $Layout -Progress $Progress -LightBackground:$LightBackground
    for ($row = 0; $row -lt $frame.Rows.Count; $row++) {
        [Console]::SetCursorPosition($Layout.Left, $Top + $row)
        foreach ($segment in $frame.Rows[$row].Segments) {
            [Console]::ForegroundColor = $segment.Color
            [Console]::Write($segment.Text)
        }
    }
}

function Invoke-WinUtilStartupCrownAnimation {
    param($Layout)

    $originalColor = [Console]::ForegroundColor
    $originalCursorVisible = [Console]::CursorVisible
    $lightBackground = [Console]::BackgroundColor -in @([ConsoleColor]::White, [ConsoleColor]::Gray, [ConsoleColor]::Yellow)
    $originalWidth = [Console]::WindowWidth
    $originalHeight = [Console]::WindowHeight
    $endRow = -1
    try {
        [Console]::CursorVisible = $false
        foreach ($line in $Layout.Lines) { [Console]::WriteLine('') }
        $endRow = [Console]::CursorTop
        $top = $endRow - $Layout.Height
        if ($top -lt 0) { throw 'The console cannot reserve space for the crown.' }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $lastFrame = -1
        while ($clock.ElapsedMilliseconds -lt 1200) {
            if ([Console]::WindowWidth -ne $originalWidth -or [Console]::WindowHeight -ne $originalHeight) {
                throw 'The console size changed during the animation.'
            }
            $elapsed = $clock.ElapsedMilliseconds
            $frame = [int][math]::Floor($elapsed / 40)
            if ($frame -ne $lastFrame) {
                Write-WinUtilStartupCrownFrame -Layout $Layout -Top $top -Progress ($elapsed / 1200.0) -LightBackground:$lightBackground
                $lastFrame = $frame
            }
            # Pick the next frame from elapsed time. Slow terminals skip frames
            # instead of adding their render time to a chain of fixed sleeps.
            $remaining = [math]::Min(1200, ($lastFrame + 1) * 40) - $clock.ElapsedMilliseconds
            if ($remaining -gt 0) { Start-Sleep -Milliseconds $remaining }
        }
        if ([Console]::WindowWidth -ne $originalWidth -or [Console]::WindowHeight -ne $originalHeight) {
            throw 'The console size changed before the final frame.'
        }
        Write-WinUtilStartupCrownFrame -Layout $Layout -Top $top -LightBackground:$lightBackground
    } catch {
        $failure = $_.Exception
        try {
            if ([Console]::WindowWidth -lt $originalWidth -or [Console]::WindowHeight -lt $originalHeight) {
                $failure.Data['WinUtilStartupConsoleShrank'] = $true
            }
        } catch {}
        throw
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

    $layout = Get-WinUtilStartupBannerLayout
    try {
        if (-not [Console]::IsOutputRedirected) {
            $layout = Get-WinUtilStartupBannerLayout -WindowWidth ([Console]::WindowWidth) -WindowHeight ([Console]::WindowHeight)
        }
    } catch {}
    Write-Host ''
    $drawn = $false
    if (-not $Static -and $layout.Size -ne 'Text' -and (Test-WinUtilStartupAnimation)) {
        try {
            Invoke-WinUtilStartupCrownAnimation -Layout $layout
            $drawn = $true
        } catch {
            # Only a confirmed shrink needs to move the larger partial crown
            # out of the viewport. Ordinary IO failures retain a short fallback.
            $consoleShrank = $_.Exception.Data['WinUtilStartupConsoleShrank'] -eq $true
            $scrollRows = 0
            try {
                $windowWidth = [Console]::WindowWidth
                $windowHeight = [Console]::WindowHeight
                $layout = Get-WinUtilStartupBannerLayout -WindowWidth $windowWidth -WindowHeight $windowHeight
                if ($consoleShrank -and -not [Console]::IsOutputRedirected -and $windowWidth -gt 0 -and $windowHeight -gt 0) {
                    $scrollRows = $windowHeight
                }
            } catch { $layout = Get-WinUtilStartupBannerLayout }
            # Plain newlines preserve the old frame and earlier logs in scrollback;
            # no screen-clearing control sequences or console buffer changes.
            for ($row = 0; $row -lt $scrollRows; $row++) { Write-Host '' }
        }
    }
    if (-not $drawn) {
        foreach ($line in $layout.Lines) { Write-Host ((' ' * $layout.Left) + $line.TrimEnd()) }
    }
    foreach ($caption in $layout.Captions) { Write-Host $caption }
    Write-Host ''
}
