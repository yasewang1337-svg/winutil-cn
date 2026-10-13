BeforeAll {
    $script:bannerPath = Join-Path $PSScriptRoot '../functions/private/Show-WinUtilStartupBanner.ps1'
    $script:bannerSource = [IO.File]::ReadAllText($script:bannerPath)
    . ([scriptblock]::Create($script:bannerSource))

    function Get-LitCrownGlyphs {
        param($Frame)
        @($Frame.Rows | ForEach-Object {
            $_.Segments | Where-Object { $_.Color -eq [ConsoleColor]::White } | ForEach-Object { $_.Text -replace ' ', '' }
        }) -join ''
    }

    function Invoke-RedirectedStartupFixture {
        param([switch]$Static, [hashtable]$Environment = @{})
        $fixture = Join-Path $TestDrive ('crown-' + [guid]::NewGuid().ToString('N') + '.ps1')
        $footer = @'
$script:animationAttempted = $false
function Invoke-WinUtilStartupCrownAnimation { param($Layout) $script:animationAttempted = $true }
Show-WinUtilStartupBanner -Static:$Static
if ($script:animationAttempted) { throw 'A redirected process must not attempt animation.' }
[Console]::WriteLine('fixture-complete')
'@
        [IO.File]::WriteAllText($fixture, "param([switch]`$Static)`r`n" + $script:bannerSource + "`r`n" + $footer, [Text.UTF8Encoding]::new($true))
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = Join-Path $PSHOME $(if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' })
        $info.Arguments = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "' + $fixture + '"' + $(if ($Static) { ' -Static' } else { '' })
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        foreach ($key in $Environment.Keys) { $info.EnvironmentVariables[$key] = $Environment[$key] }
        $process = [Diagnostics.Process]::Start($info)
        try {
            $completed = $process.WaitForExit(15000)
            if (-not $completed) { $process.Kill() }
            if (-not $completed) { throw 'The redirected banner process did not exit.' }
            [pscustomobject]@{
                Output = $process.StandardOutput.ReadToEnd()
                Errors = $process.StandardError.ReadToEnd()
                ExitCode = $process.ExitCode
            }
        } finally { $process.Dispose() }
    }
}

Describe 'Startup crown fits the available console' {
    It 'uses a substantial ASCII crown in a standard 80 by 25 window' {
        $layout = Get-WinUtilStartupBannerLayout -WindowWidth 80 -WindowHeight 25
        $layout.Size | Should -Be 'Large'
        $layout.Width | Should -BeGreaterOrEqual 54
        $layout.Width | Should -BeLessOrEqual 60
        $layout.Height | Should -BeGreaterOrEqual 15
        $layout.Height | Should -BeLessOrEqual 18
        ($layout.Left + $layout.Width) | Should -BeLessOrEqual 80
        ($layout.Height + $layout.Captions.Count + 2) | Should -BeLessOrEqual 25
    }

    It 'selects a readable layout at <Width> by <Height>' -TestCases @(
        @{ Width = 64; Height = 22; Size = 'Large' }
        @{ Width = 63; Height = 25; Size = 'Compact' }
        @{ Width = 80; Height = 21; Size = 'Compact' }
        @{ Width = 38; Height = 13; Size = 'Compact' }
        @{ Width = 37; Height = 25; Size = 'Minimal' }
        @{ Width = 80; Height = 12; Size = 'Minimal' }
        @{ Width = 18; Height = 9; Size = 'Minimal' }
        @{ Width = 17; Height = 25; Size = 'Text' }
        @{ Width = 8; Height = 5; Size = 'Text' }
        @{ Width = 1; Height = 25; Size = 'Text' }
    ) {
        param($Width, $Height, $Size)
        $layout = Get-WinUtilStartupBannerLayout -WindowWidth $Width -WindowHeight $Height
        $layout.Size | Should -Be $Size
        ($layout.Left + $layout.Width) | Should -BeLessOrEqual $Width
        $layout.Lines.Count | Should -Be $layout.Height
        foreach ($line in $layout.Lines) {
            $line.Length | Should -Be $layout.Width
            $line | Should -Not -Match '[^\x20-\x7E]'
        }
        foreach ($caption in $layout.Captions) {
            $caption.Length | Should -BeLessOrEqual $Width
            $caption | Should -Not -Match '[^\x20-\x7E]'
        }
        ($layout.Captions -join '' -replace ' ', '') | Should -Be 'yesewang1337WinUtil-CN'
        if ($Size -ne 'Text') {
            ($layout.Height + $layout.Captions.Count + 2) | Should -BeLessOrEqual $Height
        }
    }

    It 'handles unavailable or invalid terminal dimensions without oversized allocation' -TestCases @(
        @{ Width = 0; Height = 0 }
        @{ Width = -1; Height = -1 }
    ) {
        param($Width, $Height)
        $layout = Get-WinUtilStartupBannerLayout -WindowWidth $Width -WindowHeight $Height
        $layout.Size | Should -Be 'Compact'
        ($layout.Left + $layout.Width) | Should -BeLessOrEqual 38
        foreach ($caption in $layout.Captions) { $caption.Length | Should -BeLessOrEqual 38 }
    }
}

Describe 'Crown reflection keeps its geometry and settles' {
    It 'preserves printable glyphs through the whole timeline at <Width> by <Height>' -TestCases @(
        @{ Width = 80; Height = 25 }
        @{ Width = 38; Height = 13 }
        @{ Width = 18; Height = 9 }
        @{ Width = 8; Height = 5 }
    ) {
        param($Width, $Height)
        $layout = Get-WinUtilStartupBannerLayout -WindowWidth $Width -WindowHeight $Height
        foreach ($progress in @(-0.1, 0.0, 0.1, 0.27, 0.5, 0.749, 0.76, 0.81, 0.86, 0.91, 0.96, 1.0, 1.1)) {
            $frame = Get-WinUtilStartupCrownFrame -Layout $layout -Progress $progress
            $frame.Rows.Count | Should -Be $layout.Height
            for ($row = 0; $row -lt $layout.Height; $row++) {
                ($frame.Rows[$row].Segments.Text -join '') | Should -BeExactly $layout.Lines[$row]
                foreach ($segment in $frame.Rows[$row].Segments) {
                    $segment.Text.Length | Should -BeGreaterThan 0
                    $segment.Color | Should -BeOfType ([ConsoleColor])
                }
            }
        }
    }

    It 'shows a real reflection and tip or jewel glints before returning to gold' {
        $layout = Get-WinUtilStartupBannerLayout -WindowWidth 80 -WindowHeight 25
        foreach ($progress in @(0.5, 0.76, 0.81, 0.86, 0.91, 0.96)) {
            $frame = Get-WinUtilStartupCrownFrame -Layout $layout -Progress $progress
            (Get-LitCrownGlyphs $frame).Length | Should -BeGreaterThan 0 -Because "progress $progress must illuminate visible crown characters"
        }
        Get-LitCrownGlyphs (Get-WinUtilStartupCrownFrame -Layout $layout -Progress 0) | Should -BeNullOrEmpty
        Get-LitCrownGlyphs (Get-WinUtilStartupCrownFrame -Layout $layout -Progress 1) | Should -BeNullOrEmpty
    }

    It 'keeps visible contrast on a light console background' {
        $layout = Get-WinUtilStartupBannerLayout -WindowWidth 80 -WindowHeight 25
        foreach ($progress in @(0, 0.5, 0.76, 0.96, 1)) {
            $frame = Get-WinUtilStartupCrownFrame -Layout $layout -Progress $progress -LightBackground
            $colors = @($frame.Rows | ForEach-Object { $_.Segments } | Where-Object { $_.Text.Trim() } | ForEach-Object { $_.Color })
            $colors.Count | Should -BeGreaterThan 0
            $colors | Should -Not -Contain ([ConsoleColor]::White)
            $colors | Should -Not -Contain ([ConsoleColor]::Yellow)
        }
    }
}

Describe 'Startup continues when animation is disabled or interrupted' {
    BeforeEach {
        Mock Invoke-WinUtilStartupCrownAnimation {}
        Mock Test-WinUtilStartupAnimation { $true }
    }

    It 'plays once and preserves the maintainer and product captions' {
        $output = Show-WinUtilStartupBanner 6>&1 | Out-String
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 1 -Exactly
        $output | Should -Match 'yesewang1337'
        $output | Should -Match 'WinUtil-CN'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'does not probe animation capabilities or animate when Static is requested' {
        $output = Show-WinUtilStartupBanner -Static 6>&1 | Out-String
        Should -Invoke Test-WinUtilStartupAnimation -Times 0 -Exactly
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 0 -Exactly
        $output | Should -Match 'yesewang1337'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'uses plain output when animation is unavailable' {
        Mock Test-WinUtilStartupAnimation { $false }
        $output = Show-WinUtilStartupBanner 6>&1 | Out-String
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 0 -Exactly
        $output | Should -Match 'yesewang1337'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'continues with plain text after a console handle fails' {
        $plainOutput = Show-WinUtilStartupBanner -Static 6>&1 | Out-String
        Mock Invoke-WinUtilStartupCrownAnimation { throw [IO.IOException]::new('Console handle closed') }
        $output = Show-WinUtilStartupBanner 6>&1 | Out-String
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 1 -Exactly
        $output | Should -BeExactly $plainOutput -Because 'an ordinary handle failure must not insert a viewport of blank lines'
        $output | Should -Match 'yesewang1337'
        $output | Should -Match 'WinUtil-CN'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'continues after a resize invalidates the previous cursor coordinates' {
        $plainOutput = Show-WinUtilStartupBanner -Static 6>&1 | Out-String
        Mock Invoke-WinUtilStartupCrownAnimation { throw [ArgumentOutOfRangeException]::new('top') }
        $output = Show-WinUtilStartupBanner 6>&1 | Out-String
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 1 -Exactly
        $output | Should -BeExactly $plainOutput -Because 'an invalid coordinate alone does not prove a real console shrink'
        $output | Should -Match 'yesewang1337'
        $output | Should -Not -Match ([string][char]27)
    }
}

Describe 'Plain output in real redirected PowerShell processes' {
    It 'completes <Mode> without attempting animation or emitting control sequences' -TestCases @(
        @{ Mode = 'redirected'; Static = $false; Environment = @{} }
        @{ Mode = 'explicit static'; Static = $true; Environment = @{} }
        @{ Mode = 'NO_COLOR'; Static = $false; Environment = @{ NO_COLOR = '1' } }
        @{ Mode = 'dumb terminal'; Static = $false; Environment = @{ TERM = 'dumb' } }
    ) {
        param($Mode, $Static, $Environment)
        $result = Invoke-RedirectedStartupFixture -Static:$Static -Environment $Environment
        $result.ExitCode | Should -Be 0 -Because $result.Errors
        $result.Errors | Should -BeNullOrEmpty
        $result.Output | Should -Match 'yesewang1337'
        $result.Output | Should -Match 'WinUtil-CN'
        $result.Output | Should -Match 'fixture-complete'
        $result.Output | Should -Not -Match '[\x00-\x08\x0B\x0C\x0E-\x1F]'
    }
}
