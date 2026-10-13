BeforeAll {
    $script:bannerPath = Join-Path $PSScriptRoot '../functions/private/Show-WinUtilStartupBanner.ps1'
    $script:bannerSource = [IO.File]::ReadAllText($script:bannerPath)
    . ([scriptblock]::Create($script:bannerSource))
}

Describe 'Startup crown without terminal side effects' {
    BeforeEach {
        Mock Invoke-WinUtilStartupCrownAnimation {}
        Mock Test-WinUtilStartupAnimation { $true }
    }

    It 'uses a single-width silhouette that fits a narrow console' {
        $lines = @(Get-WinUtilStartupCrown)
        $lines.Count | Should -Be 8
        foreach ($line in $lines) {
            $line | Should -Not -Match '[^\x20-\x7E]'
            $line.Length | Should -BeLessOrEqual 34
        }
    }

    It 'draws one crown animation and the new maintainer name' {
        $output = (Show-WinUtilStartupBanner 6>&1 | Out-String)
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 1 -Exactly
        $output | Should -Match 'yesewang1337'
        $output | Should -Match 'WinUtil-CN'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'keeps automation static without probing or drawing the console' {
        $output = (Show-WinUtilStartupBanner -Static 6>&1 | Out-String)
        Should -Invoke Test-WinUtilStartupAnimation -Times 0 -Exactly
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 0 -Exactly
        $output | Should -Match '<>  <>  <>'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'falls back cleanly when the console is redirected or too small' {
        Mock Test-WinUtilStartupAnimation { $false }
        $output = (Show-WinUtilStartupBanner 6>&1 | Out-String)
        Should -Invoke Invoke-WinUtilStartupCrownAnimation -Times 0 -Exactly
        $output | Should -Match '<>  <>  <>'
        $output | Should -Match 'yesewang1337'
        $output | Should -Not -Match ([string][char]27)
    }

    It 'does not prevent startup when the terminal disappears during drawing' {
        Mock Invoke-WinUtilStartupCrownAnimation { throw 'Console handle closed' }
        { Show-WinUtilStartupBanner 6>$null } | Should -Not -Throw
        $output = (Show-WinUtilStartupBanner 6>&1 | Out-String)
        $output | Should -Match '<>  <>  <>'
        $output | Should -Match 'yesewang1337'
    }
}

Describe 'Plain output in a real redirected PowerShell process' {
    It 'emits printable text without escape sequences or terminal failures' {
        $fixture = Join-Path $TestDrive 'crown-fixture.ps1'
        [IO.File]::WriteAllText($fixture, $script:bannerSource + "`r`nShow-WinUtilStartupBanner`r`n[Console]::WriteLine('fixture-complete')", [Text.UTF8Encoding]::new($true))
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = Join-Path $PSHOME $(if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' })
        $info.Arguments = '-NoProfile -ExecutionPolicy RemoteSigned -File "' + $fixture + '"'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($info)
        try {
            $completed = $process.WaitForExit(15000)
            if (-not $completed) { $process.Kill() }
            $completed | Should -BeTrue
            $output = $process.StandardOutput.ReadToEnd()
            $errors = $process.StandardError.ReadToEnd()
            $process.ExitCode | Should -Be 0 -Because $errors
            $errors | Should -BeNullOrEmpty
            $output | Should -Match 'yesewang1337'
            $output | Should -Match 'fixture-complete'
            $output | Should -Match '<>  <>  <>'
            $output | Should -Not -Match '[\x00-\x08\x0B\x0C\x0E-\x1F]'
        } finally { $process.Dispose() }
    }
}
