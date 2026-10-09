BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Invoke-WPFFeatureInstall', 'Invoke-WPFGetInstalled')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root "functions/public/$name.ps1"))))
    }
    function Invoke-WPFRunspace { [CmdletBinding()] param($ScriptBlock, $ParameterList); throw 'Real workers are prohibited in these tests.' }
    function Invoke-WinUtilFeatureInstall { param($CheckBox); throw 'Real feature installation is prohibited.' }
    function Invoke-WinUtilCurrentSystem { param($CheckBox); throw 'Real inventory commands are prohibited.' }
    function Test-WinUtilPackageManager { param([switch]$winget); throw 'Real manager detection is prohibited.' }
    function Set-WinUtilTaskbaritem { param($state, $value, $overlay); throw 'Real UI calls are prohibited.' }
    function Show-WinUtilTweakDialog { param($Title, $Message); throw 'Real dialogs are prohibited.' }
    function Invoke-TestMaintenanceWorker {
        $parameters = @{}
        foreach ($pair in $script:workerParameters) { $parameters[[string]$pair[0]] = $pair[1] }
        & $script:maintenanceWorker @parameters
    }
}

Describe 'Legacy task failure cleanup' {
    BeforeEach {
        $dispatcher = [pscustomobject]@{}
        $dispatcher | Add-Member -MemberType ScriptMethod -Name Invoke -Value {
            param([delegate]$Callback)
            $null = $Callback.DynamicInvoke()
        }
        $script:sync = [hashtable]::Synchronized(@{
            Form = [pscustomobject]@{ Dispatcher = $dispatcher }
            ProcessRunning = $false
            preferences = @{ packagemanager = 'Winget' }
            selectedFeatures = [System.Collections.Generic.List[string]]::new()
            WPFInstallExample = [pscustomobject]@{ IsChecked = $false }
        })
        $sync.selectedFeatures.Add('Feature.One')
        $sync.selectedFeatures.Add('Feature.Two')
        $script:maintenanceWorker = $null
        $script:workerParameters = $null
        Mock Invoke-WPFRunspace {
            $sync.ProcessRunning | Should -BeTrue
            $script:maintenanceWorker = $ScriptBlock
            $script:workerParameters = $ParameterList
        }
        Mock Invoke-WinUtilFeatureInstall {}
        Mock Invoke-WinUtilCurrentSystem { 'WPFInstallExample' }
        Mock Test-WinUtilPackageManager { 'installed' }
        Mock Set-WinUtilTaskbaritem {}
        Mock Show-WinUtilTweakDialog { $sync.ProcessRunning | Should -BeTrue }
        Mock Write-Host {}
        Mock Write-Warning {}
        Mock Start-Process { throw 'No native commands may run.' }
    }

    It 'reserves busy state before dispatch and rejects another <Entry> click' -ForEach @(
        @{ Entry = 'features' }, @{ Entry = 'inventory' }
    ) {
        if ($Entry -eq 'features') { Invoke-WPFFeatureInstall; Invoke-WPFFeatureInstall }
        else { Invoke-WPFGetInstalled winget; Invoke-WPFGetInstalled winget }
        $sync.ProcessRunning | Should -BeTrue
        Should -Invoke Invoke-WPFRunspace -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
        Should -Invoke Invoke-WinUtilFeatureInstall -Times 0 -Exactly
        Should -Invoke Invoke-WinUtilCurrentSystem -Times 0 -Exactly
    }

    It 'releases busy state and reports a <Entry> dispatch failure' -ForEach @(
        @{ Entry = 'features' }, @{ Entry = 'inventory' }
    ) {
        Mock Invoke-WPFRunspace { throw 'pool unavailable' }
        if ($Entry -eq 'features') { Invoke-WPFFeatureInstall } else { Invoke-WPFGetInstalled winget }
        $sync.ProcessRunning | Should -BeFalse
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { $Message -match 'pool unavailable' }
        Should -Invoke Set-WinUtilTaskbaritem -Times 1 -Exactly -ParameterFilter { $state -eq 'Error' }
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'clears busy after a <Entry> worker exception without reporting success' -ForEach @(
        @{ Entry = 'features' }, @{ Entry = 'inventory' }
    ) {
        if ($Entry -eq 'features') {
            Mock Invoke-WinUtilFeatureInstall { throw 'feature unsupported' }
            Invoke-WPFFeatureInstall
        } else {
            Mock Invoke-WinUtilCurrentSystem { throw 'inventory unavailable' }
            Invoke-WPFGetInstalled winget
        }
        Invoke-TestMaintenanceWorker
        $sync.ProcessRunning | Should -BeFalse
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { $Message -match 'unsupported|unavailable' }
        Should -Invoke Set-WinUtilTaskbaritem -Times 0 -Exactly -ParameterFilter { $overlay -eq 'checkmark' }
        if ($Entry -eq 'features') { Invoke-WPFFeatureInstall } else { Invoke-WPFGetInstalled winget }
        Should -Invoke Invoke-WPFRunspace -Times 2 -Exactly
    }

    It 'releases busy even when the <Entry> window dispatcher is unavailable' -ForEach @(
        @{ Entry = 'features' }, @{ Entry = 'inventory' }
    ) {
        $sync.Form.Dispatcher | Add-Member -MemberType ScriptMethod -Name Invoke -Force -Value { throw 'dispatcher unavailable' }
        if ($Entry -eq 'features') { Invoke-WPFFeatureInstall } else { Invoke-WPFGetInstalled winget }
        { Invoke-TestMaintenanceWorker } | Should -Not -Throw
        $sync.ProcessRunning | Should -BeFalse
        Should -Invoke Write-Warning -Times 2 -Exactly
    }

    It 'uses the captured feature selection and reports finite progress after success' {
        Invoke-WPFFeatureInstall
        $sync.selectedFeatures.Clear()
        $sync.selectedFeatures.Add('Unexpected.LaterSelection')
        Invoke-TestMaintenanceWorker
        Should -Invoke Invoke-WinUtilFeatureInstall -Times 2 -Exactly
        Should -Invoke Invoke-WinUtilFeatureInstall -Times 0 -Exactly -ParameterFilter { $CheckBox -eq 'Unexpected.LaterSelection' }
        Should -Invoke Set-WinUtilTaskbaritem -Times 1 -Exactly -ParameterFilter { $value -eq 0.5 }
        Should -Invoke Set-WinUtilTaskbaritem -Times 1 -Exactly -ParameterFilter { $value -eq 1 }
        Should -Invoke Show-WinUtilTweakDialog -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }

    It 'does not dispatch an empty feature selection' {
        $sync.selectedFeatures.Clear()
        Invoke-WPFFeatureInstall
        Should -Invoke Invoke-WPFRunspace -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }

    It 'applies successful inventory selections for manager <Manager>' -ForEach @(
        @{ Manager = 'Winget'; Expected = 'winget' }, @{ Manager = 'Choco'; Expected = 'choco' }
    ) {
        $sync.preferences.packagemanager = $Manager
        Invoke-WPFGetInstalled winget
        Invoke-TestMaintenanceWorker
        $sync.WPFInstallExample.IsChecked | Should -BeTrue
        $sync.ProcessRunning | Should -BeFalse
        Should -Invoke Invoke-WinUtilCurrentSystem -Times 1 -Exactly -ParameterFilter { $CheckBox -eq $Expected }
        Should -Invoke Show-WinUtilTweakDialog -Times 0 -Exactly
    }

    It 'does not dispatch a WinGet scan when the manager is absent' {
        Mock Test-WinUtilPackageManager { 'not-installed' }
        Invoke-WPFGetInstalled winget
        Should -Invoke Invoke-WPFRunspace -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }
}

Describe 'Windows Update reset scope' {
    It 'preserves unrelated policy trees and system security templates in <Name>' -ForEach @(
        @{ Name = 'Invoke-WPFFixesUpdate' }, @{ Name = 'Invoke-WPFUpdatesdefault' }
    ) {
        # Parse all branches including Aggressive, without dot-sourcing either reset entry point.
        $path = Join-Path $root "functions/public/$Name.ps1"
        $tokens = $null; $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
        $parseErrors.Count | Should -Be 0
        $commands = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
        $forbidden = @(
            'HKCU:\Software\Policies', 'HKLM:\Software\Policies',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies',
            'HKCU:\Software\Microsoft\WindowsSelfHost', 'HKLM:\Software\Microsoft\WindowsSelfHost',
            'HKLM:\Software\Microsoft\Policies', 'HKLM:\Software\WOW6432Node\Microsoft\Policies',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies'
        )
        foreach ($command in $commands) {
            $command.GetCommandName() | Should -Not -Match '^(secedit|secedit\.exe)$'
            $strings = @($command.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } | ForEach-Object Value)
            if ($command.GetCommandName() -eq 'Remove-Item') {
                foreach ($value in $strings) { $value.TrimEnd('\') | Should -Not -BeIn $forbidden }
            }
            if ($command.GetCommandName() -eq 'Start-Process') {
                @($strings | Where-Object { $_ -match '^secedit(\.exe)?$' }).Count | Should -Be 0
                $command.Extent.Text | Should -Not -Match '(?i)\bRD\s+/S.*GroupPolicy'
            }
        }
        $ast.Extent.Text | Should -Not -Match 'Reset All Windows Update Settings to Stock|Windows Local Policies Reset to Default'
    }
}

Describe 'Real maintenance workers and WPF dispatcher boundary' {
    It 'runs inventory and feature success, failure and retry on real worker/UI threads' {
        $fixture = Join-Path $PSScriptRoot 'fixtures/maintenance-runspace.ps1'
        $executable = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $stdout = Join-Path $TestDrive 'maintenance-worker.stdout.log'
        $stderr = Join-Path $TestDrive 'maintenance-worker.stderr.log'
        $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $fixture))
        $process = Start-Process -FilePath $executable -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        try {
            $null = $process.Handle
            # A hard deadline protects the test suite from a cross-runspace dispatcher deadlock.
            $finished = $process.WaitForExit(20000)
            if (-not $finished) { $process.Kill(); $process.WaitForExit() }
            $process.Refresh()
            $finished | Should -BeTrue -Because 'workers and UI callbacks must not wait on each other indefinitely'
            $process.ExitCode | Should -Be 0 -Because ((Get-Content $stderr -Raw) + (Get-Content $stdout -Raw))
            (Get-Content $stdout -Raw) | Should -Match 'scenarios=6; callbacks kept busy; no system commands'
        } finally { $process.Dispose() }
    }
}
