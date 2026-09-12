BeforeAll {
    $privateNames = @(
        'Get-WinUtilPackagePlan', 'Get-WinUtilPackageExitResult', 'Invoke-WinUtilPackageProcess',
        'Install-WinUtilProgramWinget', 'Install-WinUtilProgramChoco', 'Invoke-WinUtilPackageBatch',
        'Invoke-WinUtilPackageOperation', 'Show-WinUtilPackageDialog', 'Show-WPFInstallAppBusy',
        'Initialize-WinUtilPackageUiCallbacks', 'Invoke-WinUtilPackageUiAction',
        'Hide-WPFInstallAppBusy', 'Install-WinUtilWinget', 'Install-WinUtilChoco', 'Set-WinUtilTaskbaritem'
    )
    foreach ($name in $privateNames) {
        . ([scriptblock]::Create((Get-Content (Join-Path $PSScriptRoot "../functions/private/$name.ps1") -Raw -Encoding UTF8)))
    }
    foreach ($name in @('Invoke-WPFInstall', 'Invoke-WPFRunspace', 'Invoke-WPFUIThread')) {
        . ([scriptblock]::Create((Get-Content (Join-Path $PSScriptRoot "../functions/public/$name.ps1") -Raw -Encoding UTF8)))
    }
    function New-TestPackage($name, $winget, $choco = 'na') {
        [pscustomobject]@{ content = $name; winget = $winget; choco = $choco }
    }
    function Convert-TestExitCode([string]$hex) {
        [BitConverter]::ToInt32([BitConverter]::GetBytes([Convert]::ToUInt32($hex, 16)), 0)
    }
}

Describe 'Software execution plans' {
    It 'keeps an exact stable ID, deduplicates selections and preserves names' {
        $package = New-TestPackage 'Example App' 'Example.App'
        $plan = @(Get-WinUtilPackagePlan -Packages @($package, $package) -Preference Winget)
        $plan.Count | Should -Be 1
        $plan[0].Id | Should -Be 'Winget:Example.App'
        $plan[0].Name | Should -Be 'Example App'
    }
    It 'falls back from unavailable Chocolatey entries to WinGet without mixing package IDs' {
        $plan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Example' 'Example.App'), (New-TestPackage 'Other' 'Other.App' 'other-app')) -Preference Choco)
        $plan[0].Manager | Should -Be 'Winget'
        $plan[0].PackageId | Should -Be 'Example.App'
        $plan[1].Manager | Should -Be 'Choco'
        $plan[1].PackageId | Should -Be 'other-app'
    }
    It 'rejects switches, wildcards and the special all keyword in individual selections' {
        foreach ($id in @('all', 'na', '--force', 'Example.App --force', '*')) {
            $plan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Invalid' $id)))
            $plan[0].InvalidReason | Should -Not -BeNullOrEmpty
        }
    }
    It 'accepts an empty selection without creating an operation' {
        @(Get-WinUtilPackagePlan -Packages @()).Count | Should -Be 0
    }
    It 'expands legacy Chocolatey lists into independently identified items and deduplicates shared packages' {
        $packages = @((New-TestPackage 'GitHub Desktop' 'GitHub.GitHubDesktop' 'git;github-desktop'), (New-TestPackage 'Git' 'Git.Git' 'git'))
        $plan = @(Get-WinUtilPackagePlan -Packages $packages -Preference Choco)
        ($plan.PackageId -join ',') | Should -Be 'git,github-desktop'
        $plan[0].Name | Should -Match 'git'
        $plan[1].Name | Should -Match 'github-desktop'
    }
    It 'produces valid IDs for the actual catalog under both manager preferences' {
        $catalog = Get-Content (Join-Path $PSScriptRoot '../config/applications.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $packages = @($catalog.PSObject.Properties | ForEach-Object { $_.Value })
        foreach ($manager in @('Winget', 'Choco')) {
            $plan = @(Get-WinUtilPackagePlan -Packages $packages -Preference $manager)
            @($plan | Where-Object InvalidReason).Count | Should -Be 0
            @($plan | Where-Object { $_.PackageId -match ';' }).Count | Should -Be 0
        }
    }
}

Describe 'Native package exit results' {
    It 'does not claim success when the exit code is missing or unknown' {
        (Get-WinUtilPackageExitResult Winget Install $null).Status | Should -Be 'Failed'
        (Get-WinUtilPackageExitResult Winget Install 123).Status | Should -Be 'Failed'
    }
    It 'recognizes signed HRESULTs for already installed and no applicable update' {
        foreach ($hex in @('8A150061', '8A15002B')) {
            $result = Get-WinUtilPackageExitResult Winget Install (Convert-TestExitCode $hex)
            $result.Status | Should -Be 'Skipped'
            $result.ExitCodeHex | Should -Be "0x$hex"
        }
    }
    It 'distinguishes completed installs that need reboot from installs blocked until reboot' {
        $completed = Get-WinUtilPackageExitResult Winget Install (Convert-TestExitCode '8A150109')
        $blocked = Get-WinUtilPackageExitResult Winget Install (Convert-TestExitCode '8A15010A')
        $completed.Status | Should -Be 'RebootRequired'
        $blocked.Status | Should -Be 'Failed'
        $blocked.NeedsReboot | Should -BeTrue
    }
    It 'keeps partial all-upgrade failures visible' {
        (Get-WinUtilPackageExitResult Winget UpgradeAll (Convert-TestExitCode '8A15002C')).Status | Should -Be 'Failed'
    }
    It 'supports Chocolatey reboot and uninstall-only no-op codes' {
        (Get-WinUtilPackageExitResult Choco Install 3010).Status | Should -Be 'RebootRequired'
        (Get-WinUtilPackageExitResult Choco Uninstall 1605).Status | Should -Be 'Skipped'
        (Get-WinUtilPackageExitResult Choco Install 1605).Status | Should -Be 'Failed'
        (Get-WinUtilPackageExitResult Choco Install 350).Status | Should -Be 'Failed'
    }
}

Describe 'Package command arguments' {
    BeforeEach {
        Mock Invoke-WinUtilPackageProcess { [pscustomobject]@{ ExitCode = 0; OutputPath = 'out'; ErrorPath = 'err' } }
    }
    It 'runs each WinGet package separately with exact IDs and disabled prompts' {
        Install-WinUtilProgramWinget -Action Install -Programs @('Example.One', 'Example.Two') -LogDirectory $TestDrive | Out-Null
        Should -Invoke Invoke-WinUtilPackageProcess -Times 2 -Exactly
        Should -Invoke Invoke-WinUtilPackageProcess -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'winget.exe' -and $Arguments[0] -eq 'install' -and $Arguments[2] -eq 'Example.One' -and
            '--exact' -in $Arguments -and '--disable-interactivity' -in $Arguments
        }
    }
    It 'does not include unknown or pinned versions in all upgrades' {
        Install-WinUtilProgramWinget -Action UpgradeAll -Programs all -LogDirectory $TestDrive | Out-Null
        Should -Invoke Invoke-WinUtilPackageProcess -Times 1 -Exactly -ParameterFilter {
            '--all' -in $Arguments -and '--include-unknown' -notin $Arguments -and '--include-pinned' -notin $Arguments
        }
    }
    It 'asks Chocolatey to preserve package exit codes' {
        Install-WinUtilProgramChoco -Action Uninstall -Programs example-app -LogDirectory $TestDrive | Out-Null
        Should -Invoke Invoke-WinUtilPackageProcess -Times 1 -Exactly -ParameterFilter {
            $Arguments[0] -eq 'uninstall' -and '--use-package-exit-codes' -in $Arguments
        }
    }
    It 'never invokes native tools for malformed package IDs' {
        { Install-WinUtilProgramWinget -Action Install -Programs 'Example.App --force' -LogDirectory $TestDrive } | Should -Throw
        Should -Invoke Invoke-WinUtilPackageProcess -Times 0 -Exactly
    }
}

Describe 'Native process exit-code capture' {
    It 'preserves a real child process failure code and both output streams without installing anything' {
        $arguments = @('-NoProfile', '-NonInteractive', '-Command', '"[Console]::Out.WriteLine(''stdout-evidence''); [Console]::Error.WriteLine(''stderr-evidence''); exit 23"')
        $result = Invoke-WinUtilPackageProcess -FilePath powershell.exe -Arguments $arguments -LogDirectory $TestDrive -LogName native-test
        $result.ExitCode | Should -Be 23
        (Get-Content -LiteralPath $result.OutputPath -Raw) | Should -Match 'stdout-evidence'
        (Get-Content -LiteralPath $result.ErrorPath -Raw) | Should -Match 'stderr-evidence'
    }
}

Describe 'Per-software result collection' {
    BeforeEach {
        Mock Get-Command { [pscustomobject]@{ Source = 'simulated.exe' } } -ParameterFilter { $Name -in @('winget.exe', 'choco.exe') }
        Mock Write-Host {}
        Mock Install-WinUtilWinget { throw 'Tests must not install package managers' }
        Mock Install-WinUtilChoco { throw 'Tests must not install package managers' }
        Mock Install-WinUtilProgramWinget {
            $code = switch ($Programs[0]) { 'Example.Failure' { 123 } 'Example.Reboot' { 3010 } 'Example.Skipped' { Convert-TestExitCode '8A150061' } default { 0 } }
            [pscustomobject]@{ ExitCode = $code; OutputPath = 'out'; ErrorPath = 'err' }
        }
        Mock Install-WinUtilProgramChoco { [pscustomobject]@{ ExitCode = 0; OutputPath = 'out'; ErrorPath = 'err' } }
    }
    It 'records mixed outcomes, keeps later items running and saves actual result JSON' {
        $packages = @('Success','Failure','Reboot','Skipped') | ForEach-Object { New-TestPackage $_ "Example.$_" }
        $plan = @(Get-WinUtilPackagePlan -Packages $packages)
        $batch = Invoke-WinUtilPackageBatch -Plan $plan -LogRoot $TestDrive
        ($batch.Results.Status -join ',') | Should -Be 'Succeeded,Failed,RebootRequired,Skipped'
        $saved = Get-Content -LiteralPath $batch.SummaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $saved.Results[1].ExitCode | Should -Be 123
        $saved.CompletedAt | Should -Not -BeNullOrEmpty
        $saved.Results[1].Plan.Id | Should -Be 'Winget:Example.Failure'
    }
    It 'turns a process exception into one failed result and continues' {
        Mock Install-WinUtilProgramWinget { throw 'Simulated process launch failure' } -ParameterFilter { $Programs[0] -eq 'Example.Failure' }
        $plan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Failed' 'Example.Failure'), (New-TestPackage 'Good' 'Example.Success')))
        $batch = Invoke-WinUtilPackageBatch -Plan $plan -LogRoot $TestDrive
        $batch.Results[0].Status | Should -Be 'Failed'
        $batch.Results[0].Reason | Should -Match 'Simulated process launch failure'
        $batch.Results[1].Status | Should -Be 'Succeeded'
    }
    It 'reports missing package managers as failures without running package commands' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'winget.exe' }
        $plan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Example' 'Example.App')))
        $batch = Invoke-WinUtilPackageBatch -Plan $plan -LogRoot $TestDrive
        $batch.Results[0].Status | Should -Be 'Failed'
        Should -Invoke Install-WinUtilProgramWinget -Times 0 -Exactly
        Should -Invoke Install-WinUtilWinget -Times 0 -Exactly
    }
    It 'contains preparation failure to the affected manager' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'winget.exe' }
        $plan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'One' 'Example.One'), (New-TestPackage 'Two' 'Example.Two'), (New-TestPackage 'Choco' 'Choco.App' 'choco-app')) -Preference Choco)
        $batch = Invoke-WinUtilPackageBatch -Plan $plan -PrepareManagers -LogRoot $TestDrive
        ($batch.Results.Status -join ',') | Should -Be 'Failed,Failed,Succeeded'
        Should -Invoke Install-WinUtilWinget -Times 1 -Exactly
    }
    It 'does not mutate software when it cannot create the result log directory' {
        Mock New-Item { throw 'Access denied' }
        $plan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Example' 'Example.App')))
        $batch = Invoke-WinUtilPackageBatch -Plan $plan -LogRoot $TestDrive
        $batch.Results[0].Status | Should -Be 'Failed'
        $batch.LogWarning | Should -Match 'Access denied'
        Should -Invoke Install-WinUtilProgramWinget -Times 0 -Exactly
    }
}

Describe 'Package dialog layout without starting software operations' {
    It 'inherits the theme and leaves results visible with large fonts and a narrow layout' {
        Add-Type -AssemblyName PresentationFramework
        $owner = New-Object Windows.Window
        $owner.Resources['MainBackgroundColor'] = [Windows.Media.Brushes]::Black
        $owner.Resources['MainForegroundColor'] = [Windows.Media.Brushes]::White
        $owner.Resources['FontSize'] = 22.0
        $script:sync = @{ form = $owner }
        $dialog = Show-WinUtilPackageDialog -Title 'Results' -Description ('Detailed explanation. ' * 60) -Details ('Result details. ' * 40) -PrimaryLabel 'Retry failed items' -CreateOnly
        try {
            $dialog.FontSize | Should -Be 22
            $dialog.Background.ToString() | Should -Be '#FF000000'
            $dialog.Content.Children[1].GetType().Name | Should -Be 'WrapPanel'
            $dialog.Content.Children[2].Foreground.ToString() | Should -Be '#FFFFFFFF'
            $dialog.Content.Measure([Windows.Size]::new(360, 500))
            $dialog.Content.Arrange([Windows.Rect]::new(0, 0, 360, 500))
            $dialog.Content.UpdateLayout()
            $dialog.Content.Children[2].ActualHeight | Should -BeGreaterThan 40
            $dialog.Content.Children[0].MaxHeight | Should -BeLessThan ($dialog.Height * 0.5)
        } finally { $dialog.Close(); $owner.Close() }
    }
}

Describe 'Real software worker and WPF dispatcher boundary' {
    It 'returns progress, results and retry decisions to the UI runspace without hanging' {
        $fixture = Join-Path $PSScriptRoot 'fixtures/package-runspace.ps1'
        $executable = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $stdout = Join-Path $TestDrive 'worker.stdout.log'
        $stderr = Join-Path $TestDrive 'worker.stderr.log'
        $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $fixture), '-LogRoot', ('"{0}"' -f $TestDrive))
        $process = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        try {
            $null = $process.Handle
            # A separate process provides a hard deadline even if the UI dispatcher itself deadlocks.
            $finished = $process.WaitForExit(15000)
            if (-not $finished) { $process.Kill(); $process.WaitForExit() }
            $process.Refresh()
            $finished | Should -BeTrue -Because 'the UI callback must not wait on the worker that is waiting for it'
            $process.ExitCode | Should -Be 0 -Because ((Get-Content $stderr -Raw) + (Get-Content $stdout -Raw))
            (Get-Content $stdout -Raw) | Should -Match 'native mock calls=3'
        } finally { $process.Dispose() }
    }
}

Describe 'GUI and automatic invocation boundaries' {
    BeforeEach {
        $script:sync = @{ ProcessRunning = $false; preferences = @{ packagemanager = 'Winget' }; form = $null }
        $script:onePlan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Example' 'Example.App')))
        Mock Write-Warning {}
        Mock Show-WinUtilPackageDialog { 'Close' }
        Mock Show-WPFInstallAppBusy {}
        Mock Hide-WPFInstallAppBusy {}
        Mock Set-WinUtilTaskbaritem {}
        Mock Invoke-WPFUIThread { & $ScriptBlock }
        Mock Invoke-WinUtilPackageUiAction { $sync["Package${Action}Action"].Invoke() }
        Mock Invoke-WinUtilPackageBatch { [pscustomobject]@{ Results = @(); LogDirectory = ''; LogWarning = '' } }
        Mock Invoke-WPFRunspace { & $ScriptBlock -Plan $ParameterList[0][1] }
    }
    It 'runs automatic imports synchronously without opening dialogs and releases busy state' {
        Invoke-WinUtilPackageOperation -Plan $script:onePlan -NonInteractive | Out-Null
        Should -Invoke Show-WinUtilPackageDialog -Times 0 -Exactly
        Should -Invoke Invoke-WPFRunspace -Times 0 -Exactly
        $script:sync.ProcessRunning | Should -BeFalse
    }
    It 'clears busy when automatic execution throws' {
        Mock Invoke-WinUtilPackageBatch { throw 'Unexpected batch failure' }
        { Invoke-WinUtilPackageOperation -Plan $script:onePlan -NonInteractive } | Should -Throw
        $script:sync.ProcessRunning | Should -BeFalse
    }
    It 'honors cancellation without starting a batch' {
        $script:sync.form = [pscustomobject]@{}
        Invoke-WinUtilPackageOperation -Plan $script:onePlan
        Should -Invoke Invoke-WinUtilPackageBatch -Times 0 -Exactly
        $script:sync.ProcessRunning | Should -BeFalse
    }
    It 'retains the explicit right-click application instead of installing the entire selection' {
        Mock Invoke-WinUtilPackageOperation {}
        Invoke-WPFInstall -PackagesToInstall (New-TestPackage 'Right click' 'Example.RightClick') -NonInteractive
        Should -Invoke Invoke-WinUtilPackageOperation -Times 1 -Exactly -ParameterFilter { $Plan.Count -eq 1 -and $Plan[0].PackageId -eq 'Example.RightClick' }
    }
    It 'retries only failed individual packages and always clears the busy overlay' {
        $script:sync.form = [pscustomobject]@{}
        $script:dialogIndex = 0
        Mock Show-WinUtilPackageDialog { $script:dialogIndex++; if ($script:dialogIndex -le 2) { 'Primary' } else { 'Close' } }
        $failedPlan = @(Get-WinUtilPackagePlan -Packages @((New-TestPackage 'Failed' 'Example.Failed')))[0]
        $goodPlan = $script:onePlan[0]
        $script:failedPlan = $failedPlan
        $script:goodPlan = $goodPlan
        $script:batchIndex = 0
        Mock Invoke-WinUtilPackageBatch {
            $script:batchIndex++
            $results = @([pscustomobject]@{ Id = $script:failedPlan.Id; Name = 'Failed'; Status = 'Succeeded'; Action = 'Install'; Plan = $script:failedPlan })
            if ($script:batchIndex -eq 1) {
                $results[0].Status = 'Failed'
                $results += [pscustomobject]@{ Id = $script:goodPlan.Id; Name = 'Good'; Status = 'Succeeded'; Action = 'Install'; Plan = $script:goodPlan }
            }
            [pscustomobject]@{ Results = $results; LogDirectory = ''; LogWarning = '' }
        }
        Invoke-WinUtilPackageOperation -Plan @($failedPlan, $goodPlan)
        Should -Invoke Invoke-WinUtilPackageBatch -Times 1 -Exactly -ParameterFilter { $Plan.Count -eq 1 -and $Plan[0].Id -eq 'Winget:Example.Failed' }
        $script:sync.LastPackageResults.Count | Should -Be 2
        $script:sync.ProcessRunning | Should -BeFalse
        Should -Invoke Hide-WPFInstallAppBusy -Times 3 -Exactly
    }
}
