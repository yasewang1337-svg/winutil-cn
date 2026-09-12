BeforeAll {
    $script:originalLocalAppData = $env:LOCALAPPDATA
    $private = Join-Path $PSScriptRoot '../functions/private'
    foreach ($name in @('Get-WinUtilTweakRegistryState', 'Get-WinUtilTweakHistory', 'Save-WinUtilTweakHistory', 'Restore-WinUtilTweakHistory', 'Set-WinUtilRegistry', 'Set-WinUtilService', 'Invoke-WinUtilTweaks', 'Confirm-WinUtilTweakPlan', 'Invoke-WinUtilTweakBatch', 'Invoke-WinUtilTweakToggle', 'New-WinUtilTweakRestorePoint', 'Initialize-WinUtilTweakUiCallbacks')) {
        . ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $private "$name.ps1") -Raw -Encoding UTF8)))
    }
    . ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $private 'Get-WinUtilToggleStatus.ps1') -Raw -Encoding UTF8)))
    . ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $PSScriptRoot '../functions/public/Invoke-WPFTweakHistory.ps1') -Raw -Encoding UTF8)))
    function Show-WinUtilTweakDialog { param($Title, $Message) }
    function Invoke-WPFSelectedCheckboxesUpdate { param($type, $checkboxName) }
    function Set-WinUtilDNS { param($DNSProvider) }
    function Remove-WinUtilAPPX { param($Name) }
    function Get-ComputerRestorePoint { [CmdletBinding()] param() }
    function Enable-ComputerRestore { [CmdletBinding()] param($Drive) }
    function Checkpoint-Computer { [CmdletBinding()] param($Description, $RestorePointType) }
}

AfterAll { $env:LOCALAPPDATA = $script:originalLocalAppData }

Describe 'Isolated tweak snapshots and precise recovery' {
    BeforeEach {
        $env:LOCALAPPDATA = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:entry = [pscustomobject]@{ Path = 'HKCU:\Software\WinUtilTest'; Name = 'Setting'; Type = 'DWord'; Value = 1; OriginalValue = 0 }
        $script:sync = @{ configs = @{ tweaks = @{ Example = [pscustomobject]@{ Content = 'Example'; Description = 'Example'; registry = @($script:entry) } } } }
        Mock Get-WinUtilTweakRegistryState {
            param($Path, $Name)
            [pscustomobject]@{ Kind = 'Registry'; Path = $Path; Name = $Name; Exists = $true; ValueType = 'String'; Value = 'custom value'; State = 'Pending' }
        }
        Mock Set-WinUtilRegistry {}
        Mock Set-WinUtilService {}
        Mock Write-Warning {}
        Mock Set-WinUtilDNS {}
    }

    It 'persists the actual previous type and value before writing' {
        Mock Set-WinUtilRegistry {
            $saved = @(Get-WinUtilTweakHistory -TweakId Example)
            $saved.Count | Should -Be 1
            $saved[0].Entries[0].Value | Should -Be 'custom value'
            $saved[0].Entries[0].ValueType | Should -Be 'String'
            $saved[0].Entries[0].State | Should -Be 'Applying'
        }
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Success'
        (Get-WinUtilTweakHistory -TweakId Example).Entries[0].State | Should -Be 'Applied'
    }

    It 'does not modify settings when the snapshot cannot be saved' {
        Mock Save-WinUtilTweakHistory { throw 'disk unavailable' }
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Failed'
        Should -Invoke Set-WinUtilRegistry -Times 0 -Exactly
    }

    It 'does not modify anything when a previous value cannot be read' {
        Mock Get-WinUtilTweakRegistryState { throw [UnauthorizedAccessException]::new('denied') }
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Failed'
        Should -Invoke Set-WinUtilRegistry -Times 0 -Exactly
    }

    It 'keeps a recovery record when a change throws' {
        Mock Set-WinUtilRegistry { throw 'write denied' }
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Failed'
        $record = Get-WinUtilTweakHistory -TweakId Example
        $record.Status | Should -Be 'Failed'
        $record.Entries[0].State | Should -Be 'Applying'
    }

    It 'restores the actual value and kind instead of the configured OriginalValue' {
        Invoke-WinUtilTweaks Example | Out-Null
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Success'
        Should -Invoke Set-WinUtilRegistry -Times 1 -Exactly -ParameterFilter { $Value -eq 'custom value' -and $Type -eq 'String' }
        (Get-WinUtilTweakHistory -TweakId Example).Restored | Should -BeTrue
    }

    It 'removes a value that did not exist before the change' {
        Mock Get-WinUtilTweakRegistryState {
            param($Path, $Name)
            [pscustomobject]@{ Kind = 'Registry'; Path = $Path; Name = $Name; Exists = $false; ValueType = $null; Value = $null; State = 'Pending' }
        }
        Invoke-WinUtilTweaks Example | Out-Null
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Success'
        Should -Invoke Set-WinUtilRegistry -Times 1 -Exactly -ParameterFilter { $Value -eq '<RemoveEntry>' }
    }

    It 'skips unknown historical state without overwriting current settings' {
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Skipped'
        Should -Invoke Set-WinUtilRegistry -Times 0 -Exactly
    }

    It 'retries incomplete recovery and skips already restored entries' {
        $script:sync.configs.tweaks.Example.registry += [pscustomobject]@{ Path = $script:entry.Path; Name = 'Other'; Type = 'DWord'; Value = 2; OriginalValue = 0 }
        Invoke-WinUtilTweaks Example | Out-Null
        Mock Set-WinUtilRegistry { if ($Name -eq 'Setting') { throw 'denied' } }
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Failed'
        (Get-WinUtilTweakHistory -TweakId Example).Entries[1].State | Should -Be 'Restored'
        Mock Set-WinUtilRegistry {}
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Success'
        Should -Invoke Set-WinUtilRegistry -Times 2 -Exactly -ParameterFilter { $Name -eq 'Other' }
    }

    It 'refuses a recorded target absent from current configuration' {
        Invoke-WinUtilTweaks Example | Out-Null
        $script:sync.configs.tweaks.Example.registry = @()
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Failed'
        Should -Invoke Set-WinUtilRegistry -Times 1 -Exactly
    }

    It 'retains binary and empty multi-string values across disk serialization' {
        $record = [pscustomobject]@{ SchemaVersion = 1; Id = [guid]::NewGuid().ToString('N'); TweakId = 'Example'; CreatedAt = [DateTime]::UtcNow.ToString('o'); Entries = @([pscustomobject]@{ Value = [byte[]]@(0, 128, 255) }, [pscustomobject]@{ Value = [string[]]@() }) }
        Save-WinUtilTweakHistory $record
        $read = Get-WinUtilTweakHistory -TweakId Example
        $read.Entries[0].Value | Should -BeOfType [byte]
        @($read.Entries[0].Value).Count | Should -Be 3
        $read.Entries[0].Value[2] | Should -Be 255
        @($read.Entries[1].Value).Count | Should -Be 0
    }

    It 'reports a script error as failure instead of success' {
        $script:sync.configs.tweaks.Example | Add-Member NoteProperty InvokeScript @("throw 'script failure'")
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Failed'
    }

    It 'does not claim complete verification or recovery for arbitrary script effects' {
        $script:sync.configs.tweaks.Example | Add-Member NoteProperty InvokeScript @('1 | Out-Null')
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Unverified'
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Partial'
    }

    It 'applies a configured off target as a new operation and records its actual previous value' {
        (Invoke-WinUtilTweaks Example -ApplyDefault).Status | Should -Be 'Success'
        Should -Invoke Set-WinUtilRegistry -Times 1 -Exactly -ParameterFilter { $Value -eq 0 }
        (Get-WinUtilTweakHistory -TweakId Example).Entries[0].Value | Should -Be 'custom value'
    }

    It 'preserves a customized service startup configuration when requested' {
        $script:sync.configs.tweaks.Example | Add-Member NoteProperty service @([pscustomobject]@{ Name = 'TestService'; StartupType = 'Disabled'; OriginalType = 'Automatic' })
        Mock Get-Service { [pscustomobject]@{ StartType = 'Manual' } }
        (Invoke-WinUtilTweaks Example).Status | Should -Be 'Partial'
        Should -Invoke Set-WinUtilService -Times 0 -Exactly
    }

    It 'restores service startup and the original delayed-start registry value' {
        $script:sync.configs.tweaks.Example | Add-Member NoteProperty service @([pscustomobject]@{ Name = 'TestService'; StartupType = 'Disabled'; OriginalType = 'Automatic' })
        Mock Get-Service { [pscustomobject]@{ StartType = 'Automatic' } }
        Mock Get-WinUtilTweakRegistryState -ParameterFilter { $Name -eq 'DelayedAutoStart' } {
            param($Path, $Name)
            [pscustomobject]@{ Kind = 'Registry'; Path = $Path; Name = $Name; Exists = $true; ValueType = 'DWord'; Value = 1; State = 'Pending' }
        }
        Invoke-WinUtilTweaks Example | Out-Null
        (Invoke-WinUtilTweaks Example -undo $true).Status | Should -Be 'Success'
        Should -Invoke Set-WinUtilService -Times 1 -Exactly -ParameterFilter { $Name -eq 'TestService' -and $StartupType -eq 'Automatic' }
        Should -Invoke Set-WinUtilRegistry -Times 1 -Exactly -ParameterFilter { $Name -eq 'DelayedAutoStart' -and $Value -eq 1 }
    }

    It 'stops remaining tweaks and DNS after restore-point failure and clears busy state' {
        $script:sync.configs.tweaks.WPFTweaksRestorePoint = [pscustomobject]@{ Content = 'Restore point' }
        $script:sync.ProcessRunning = $true
        Mock Invoke-WinUtilTweaks { [pscustomobject]@{ TweakId = $CheckBox; Name = $CheckBox; Status = 'Failed'; Message = 'restore unavailable'; HistoryId = $null } }
        Invoke-WinUtilTweakBatch -Tweaks @('Example', 'WPFTweaksRestorePoint') -DNSProvider 'Provider'
        $script:sync.ProcessRunning | Should -BeFalse
        $script:sync.LastTweakResults[0].TweakId | Should -Be 'WPFTweaksRestorePoint'
        @($script:sync.LastTweakResults | Where-Object Status -EQ 'Skipped').Count | Should -Be 2
        Should -Invoke Invoke-WinUtilTweaks -Times 1 -Exactly
        Should -Invoke Set-WinUtilDNS -Times 0 -Exactly
    }

    It 'refuses script operations in unattended mode' {
        $script:sync.configs.tweaks.Example | Add-Member NoteProperty InvokeScript @("throw 'must not run'")
        { Confirm-WinUtilTweakPlan -Tweaks @('Example') } | Should -Throw '*自动模式仅执行*'
    }

    It 'allows recorded registry operations in unattended mode' {
        Confirm-WinUtilTweakPlan -Tweaks @('Example') | Should -BeTrue
    }

    It 'reads back a failed toggle and prevents recursive events' {
        $sender = [pscustomobject]@{ Name = 'Example'; IsChecked = $true }
        Mock Invoke-WinUtilTweaks { [pscustomobject]@{ Status = 'Failed'; Message = 'denied' } }
        Mock Get-WinUtilToggleStatus { $false }
        Mock Invoke-WPFSelectedCheckboxesUpdate {}
        Invoke-WinUtilTweakToggle -Sender $sender -Enabled $true | Out-Null
        $sender.IsChecked | Should -BeFalse
        $script:sync.TweakToggleUpdating | Should -BeFalse
        Should -Invoke Invoke-WPFSelectedCheckboxesUpdate -Times 1 -Exactly -ParameterFilter { $type -eq 'Remove' }
        $script:sync.TweakToggleUpdating = $true
        Invoke-WinUtilTweakToggle -Sender $sender -Enabled $false | Out-Null
        Should -Invoke Invoke-WinUtilTweaks -Times 1 -Exactly
    }

    It 'keeps a completed result dialog separate from a later job result' {
        $script:sync.Form = [pscustomobject]@{ Title = 'Mock UI' }
        $script:sync.LastTweakResults = @([pscustomobject]@{ Status = 'Failed'; Name = 'Later job'; Message = 'Later result' })
        $earlier = @([pscustomobject]@{ Status = 'Success'; Name = 'Earlier job'; Message = 'Earlier result' })
        Mock Show-WinUtilTweakDialog {}
        Initialize-WinUtilTweakUiCallbacks
        $script:sync.TweakResultsAction.Invoke([object]$earlier)
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { $Message -like '*Earlier job*' -and $Message -notlike '*Later job*' }
    }
}

Describe 'Read-only registry snapshot' {
    BeforeEach {
        $script:key = [pscustomobject]@{ Value = '%USERPROFILE%\Downloads'; Disposed = $false }
        $script:key | Add-Member ScriptMethod GetValueNames { return @('Target') }
        $script:key | Add-Member ScriptMethod GetValueKind { return [Microsoft.Win32.RegistryValueKind]::ExpandString }
        $script:key | Add-Member ScriptMethod GetValue { param($name, $default, $options); $options | Should -Be ([Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames); return $this.Value }
        $script:key | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
        Mock Get-Item { $script:key }
        Mock New-Item { throw 'Registry writes forbidden' }
        Mock Get-ItemProperty { throw 'Whole-key enumeration forbidden' }
    }
    It 'preserves expand-string text without expanding it' {
        $state = Get-WinUtilTweakRegistryState -Path 'HKCU:\Test' -Name Target
        $state.Value | Should -Be '%USERPROFILE%\Downloads'
        $state.ValueType | Should -Be 'ExpandString'
        $script:key.Disposed | Should -BeTrue
        Should -Invoke Get-ItemProperty -Times 0 -Exactly
    }
    It 'distinguishes absent values from empty values' {
        (Get-WinUtilTweakRegistryState -Path 'HKCU:\Test' -Name Missing).Exists | Should -BeFalse
        $script:key.Value = ''
        $state = Get-WinUtilTweakRegistryState -Path 'HKCU:\Test' -Name Target
        $state.Exists | Should -BeTrue
        $state.Value | Should -Be ''
    }
    It 'propagates access errors instead of fabricating an absent value' {
        Mock Get-Item { throw [UnauthorizedAccessException]::new('denied') }
        { Get-WinUtilTweakRegistryState -Path 'HKCU:\Test' -Name Target } | Should -Throw
        Should -Invoke New-Item -Times 0 -Exactly
    }
}

Describe 'Restore-point verification and conservative presets' {
    It 'completes real worker execution and returns results on the WPF UI thread' {
        $engine = Join-Path $PSHOME 'pwsh.exe'
        if (-not (Test-Path -LiteralPath $engine)) { $engine = Join-Path $PSHOME 'powershell.exe' }
        $fixture = Join-Path $PSScriptRoot 'fixtures/tweak-runspace.ps1'
        $stdout = Join-Path $TestDrive 'tweak-worker-out.log'
        $stderr = Join-Path $TestDrive 'tweak-worker-err.log'
        $arguments = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $fixture + '"'))
        $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        # PS 5.1 needs an open process handle to retain ExitCode after a fast exit.
        $null = $process.Handle
        try {
            if (-not $process.WaitForExit(15000)) { throw 'Worker UI callback timed out' }
            $process.ExitCode | Should -Be 0 -Because (Get-Content $stderr -Raw)
            Get-Content $stdout -Raw | Should -Match 'real worker dispatch and WPF dispatcher callback passed'
        } finally {
            if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
            $process.Dispose()
        }
    }

    It 'does not report a restore point that was never created' {
        Mock Get-ComputerRestorePoint { [pscustomobject]@{ Description = 'Old restore point' } }
        Mock Checkpoint-Computer {}
        { New-WinUtilTweakRestorePoint } | Should -Throw '*后续修改已停止*'
    }
    It 'propagates restore-point creation failure' {
        Mock Get-ComputerRestorePoint { [pscustomobject]@{ Description = 'Old restore point' } }
        Mock Checkpoint-Computer { throw 'protection unavailable' }
        { New-WinUtilTweakRestorePoint } | Should -Throw '*protection unavailable*'
    }
    It 'keeps Minimal and Standard free of scripts, application removal and service changes' {
        $presets = Get-Content (Join-Path $PSScriptRoot '../config/preset.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $tweaks = Get-Content (Join-Path $PSScriptRoot '../config/tweaks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($preset in @('Minimal', 'Standard')) {
            foreach ($id in $presets.$preset) {
                [bool]$tweaks.$id.registry | Should -BeTrue
                [bool]$tweaks.$id.InvokeScript | Should -BeFalse
                [bool]$tweaks.$id.appx | Should -BeFalse
                [bool]$tweaks.$id.service | Should -BeFalse
            }
        }
    }
}
