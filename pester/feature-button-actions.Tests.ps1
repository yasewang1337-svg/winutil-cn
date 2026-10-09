BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @(
        'public/Invoke-WPFButton.ps1', 'private/Invoke-WinUtilFeatureButton.ps1',
        'private/Invoke-WinUtilFeatureAction.ps1', 'private/Invoke-WinUtilMirrorAction.ps1',
        'private/Invoke-WinUtilMirrorCommand.ps1'
    )) { . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root "functions/$file")))) }
    $script:featureSource = Join-Path $root 'config/feature.json'
    $script:calledFunction = $null
    foreach ($name in @(
        'Invoke-WPFFixesNTPPool', 'Invoke-WPFFeatureInstall', 'Invoke-WPFPanelAutologin',
        'Invoke-WPFFixesUpdate', 'Invoke-WPFFixesNetwork', 'Invoke-WPFSystemRepair',
        'Invoke-WPFFixesWinget', 'Invoke-WinUtilInstallPSProfile',
        'Invoke-WinUtilUninstallPSProfile', 'Invoke-WPFSSHServer'
    )) { Set-Item -LiteralPath "function:$name" -Value { $script:calledFunction = $MyInvocation.MyCommand.Name } }
    function Show-WinUtilTweakDialog { param($Title, $Message, [switch]$Confirm); throw 'Real dialogs are forbidden.' }
    function Set-WinUtilProgressBar { param($label, $percent) }
}

Describe 'Configured feature buttons' {
    BeforeEach {
        $script:sync = @{ ProcessRunning = $false; configs = @{ feature = ([IO.File]::ReadAllText($script:featureSource) | ConvertFrom-Json) } }
        $script:calledFunction = $null
        Mock Show-WinUtilTweakDialog { $true }
        Mock Write-Warning {}
        Mock Start-Process { throw 'Real processes are forbidden.' }
        Mock Invoke-WinUtilFeatureAction {}
    }

    It 'dispatches every existing button and never treats checkbox scripts as buttons' {
        $buttons = @($sync.configs.feature.PSObject.Properties | Where-Object { $_.Value.Type -eq 'Button' })
        $buttons.Count | Should -Be 30
        foreach ($entry in $buttons) {
            $entry.Value.InvokeScript | Should -BeNullOrEmpty
            $script:calledFunction = $null
            Invoke-WPFButton -Button $entry.Name
            if ($entry.Value.function) { $script:calledFunction | Should -BeExactly $entry.Value.function }
        }
        Should -Invoke Invoke-WinUtilFeatureAction -Times 20 -Exactly
        Should -Invoke Show-WinUtilTweakDialog -Times 0 -Exactly
        Invoke-WPFButton -Button 'WPFFeaturenfs'
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { -not $Confirm }
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'rejects <Kind> without falling through to another handler' -ForEach @(
        @{ Kind = 'script text'; Button = 'WPFPanelControl'; Changes = @{ InvokeScript = @('Write-Output injected') } }
        @{ Kind = 'unknown action'; Button = 'WPFPanelControl'; Changes = @{ Action = 'Panel.Unknown' } }
        @{ Kind = 'action assigned to the wrong button'; Button = 'WPFPanelControl'; Changes = @{ Action = 'Panel.Power' } }
        @{ Kind = 'function assigned to the wrong button'; Button = 'WPFFixesNetwork'; Changes = @{ function = 'Invoke-WPFSSHServer' } }
        @{ Kind = 'arbitrary command'; Button = 'WPFFixesNetwork'; Changes = @{ function = 'Start-Process' } }
        @{ Kind = 'mixed function and action'; Button = 'WPFFixesNetwork'; Changes = @{ Action = 'Panel.Control' } }
        @{ Kind = 'wrong type'; Button = 'WPFPanelControl'; Changes = @{ Type = 'CheckBox' } }
    ) {
        foreach ($name in $Changes.Keys) { $sync.configs.feature.$Button | Add-Member -MemberType NoteProperty -Name $name -Value $Changes[$name] -Force }
        Invoke-WPFButton -Button $Button
        $script:calledFunction | Should -BeNullOrEmpty
        Should -Invoke Invoke-WinUtilFeatureAction -Times 0 -Exactly
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { -not $Confirm }
    }

    It 'rejects a new unreviewed configuration button' {
        $sync.configs.feature | Add-Member -MemberType NoteProperty -Name 'UnexpectedButton' -Value ([pscustomobject]@{ Type = 'Button'; Action = 'Panel.Control' })
        Invoke-WPFButton -Button UnexpectedButton
        Should -Invoke Invoke-WinUtilFeatureAction -Times 0 -Exactly
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly
    }

    It 'does not resolve an allowed function name to an alias or application' {
        Mock Get-Command { throw 'Function unavailable' } -ParameterFilter { $Name -eq 'Invoke-WPFFixesNetwork' -and $CommandType -eq 'Function' }
        Invoke-WPFButton -Button WPFFixesNetwork
        $script:calledFunction | Should -BeNullOrEmpty
        Should -Invoke Get-Command -Times 1 -Exactly -ParameterFilter { $CommandType -eq 'Function' }
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly
    }
}

Describe 'Fixed system-panel and mirror dispatch' {
    BeforeEach {
        Mock Start-Process {}
        Mock Invoke-WinUtilMirrorAction {}
    }
    It 'opens <Action> using the fixed system executable and arguments' -ForEach @(
        @{ Action = 'Panel.Control'; File = 'control.exe'; PanelArguments = ''; Explorer = $false }
        @{ Action = 'Panel.Computer'; File = 'mmc.exe'; PanelArguments = 'COMPMGMT'; Explorer = $false }
        @{ Action = 'Panel.Network'; File = 'control.exe'; PanelArguments = 'ncpa.cpl'; Explorer = $false }
        @{ Action = 'Panel.Power'; File = 'control.exe'; PanelArguments = 'powercfg.cpl'; Explorer = $false }
        @{ Action = 'Panel.Printer'; File = 'explorer.exe'; PanelArguments = 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}'; Explorer = $true }
        @{ Action = 'Panel.Region'; File = 'control.exe'; PanelArguments = 'intl.cpl'; Explorer = $false }
        @{ Action = 'Panel.Restore'; File = 'rstrui.exe'; PanelArguments = ''; Explorer = $false }
        @{ Action = 'Panel.Sound'; File = 'control.exe'; PanelArguments = 'mmsys.cpl'; Explorer = $false }
        @{ Action = 'Panel.System'; File = 'control.exe'; PanelArguments = 'sysdm.cpl'; Explorer = $false }
        @{ Action = 'Panel.Timedate'; File = 'control.exe'; PanelArguments = 'timedate.cpl'; Explorer = $false }
    ) {
        $directory = [Environment]::SystemDirectory
        if ($Explorer) { $directory = $env:SystemRoot }
        $expectedPath = Join-Path $directory $File
        $expectedArguments = $PanelArguments
        if ($PanelArguments -eq 'COMPMGMT') { $expectedArguments = '"{0}"' -f (Join-Path $directory 'compmgmt.msc') }
        elseif ($PanelArguments -like '*.cpl') { $expectedArguments = '"{0}"' -f (Join-Path $directory $PanelArguments) }
        Invoke-WinUtilFeatureAction -Action $Action
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $expectedPath -and ($ArgumentList -join ' ') -eq $expectedArguments -and $ErrorAction -eq 'Stop'
        }
    }
    It 'routes both modes of all five managers without evaluating a command string' {
        foreach ($tool in @('Pip', 'Npm', 'Yarn', 'Conda', 'Go')) {
            Invoke-WinUtilFeatureAction -Action "Mirror.$tool.CN"
            Invoke-WinUtilFeatureAction -Action "Mirror.$tool.Official"
        }
        Should -Invoke Invoke-WinUtilMirrorAction -Times 5 -Exactly -ParameterFilter { $Reset }
        Should -Invoke Invoke-WinUtilMirrorAction -Times 5 -Exactly -ParameterFilter { -not $Reset }
        Should -Invoke Start-Process -Times 0 -Exactly
    }
    It 'rejects action text containing additional commands' {
        { Invoke-WinUtilFeatureAction -Action 'Panel.Control; Write-Output injected' } | Should -Throw
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Invoke-WinUtilMirrorAction -Times 0 -Exactly
    }
}

Describe 'Confirmed package-manager configuration changes' {
    BeforeEach {
        $script:sync = @{ ProcessRunning = $false }
        Mock Show-WinUtilTweakDialog { $true }
        Mock Get-Command { [pscustomobject]@{ Source = "C:\Tool Path\$Name" } } -ParameterFilter { $CommandType -eq 'Application' }
        Mock Invoke-WinUtilMirrorCommand { '' }
        Mock Write-Host {}
    }
    It 'does nothing when the user cancels' {
        Mock Show-WinUtilTweakDialog { $false }
        Invoke-WinUtilMirrorAction -Tool Npm
        Should -Invoke Get-Command -Times 0 -Exactly
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }
    It 'rejects a busy session before confirmation' {
        $sync.ProcessRunning = $true
        { Invoke-WinUtilMirrorAction -Tool Go } | Should -Throw
        Should -Invoke Show-WinUtilTweakDialog -Times 0 -Exactly
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly
    }
    It 'reserves the operation while a confirmation dialog pumps nested events' {
        Mock Show-WinUtilTweakDialog {
            $sync.ProcessRunning | Should -BeTrue
            { Invoke-WinUtilMirrorAction -Tool Go } | Should -Throw
            $false
        }
        Invoke-WinUtilMirrorAction -Tool Npm
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }
    It 'releases busy state after a confirmation error' {
        Mock Show-WinUtilTweakDialog { throw 'dialog unavailable' }
        { Invoke-WinUtilMirrorAction -Tool Pip } | Should -Throw '*dialog unavailable*'
        $sync.ProcessRunning | Should -BeFalse
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly
    }
    It 'reports a missing tool without success output' {
        Mock Get-Command { $null } -ParameterFilter { $CommandType -eq 'Application' }
        { Invoke-WinUtilMirrorAction -Tool Npm } | Should -Throw
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly
        Should -Invoke Write-Host -Times 0 -Exactly
    }
    It 'uses <Tool> fixed arguments in <Mode> mode through the installed application' -ForEach @(
        @{ Tool = 'Npm'; Mode = 'CN'; Reset = $false; File = 'npm.cmd'; Arguments = 'config|set|registry|https://registry.npmmirror.com' }
        @{ Tool = 'Npm'; Mode = 'Official'; Reset = $true; File = 'npm.cmd'; Arguments = 'config|set|registry|https://registry.npmjs.org' }
        @{ Tool = 'Yarn'; Mode = 'CN'; Reset = $false; File = 'yarn.cmd'; Arguments = 'config|set|registry|https://registry.npmmirror.com' }
        @{ Tool = 'Yarn'; Mode = 'Official'; Reset = $true; File = 'yarn.cmd'; Arguments = 'config|set|registry|https://registry.yarnpkg.com' }
        @{ Tool = 'Go'; Mode = 'CN'; Reset = $false; File = 'go.exe'; Arguments = 'env|-w|GOPROXY=https://goproxy.cn,direct' }
        @{ Tool = 'Go'; Mode = 'Official'; Reset = $true; File = 'go.exe'; Arguments = 'env|-w|GOPROXY=https://proxy.golang.org,direct' }
        @{ Tool = 'Pip'; Mode = 'CN'; Reset = $false; File = 'pip.exe'; Arguments = 'config|set|global.index-url|https://pypi.tuna.tsinghua.edu.cn/simple' }
    ) {
        $expectedFile = "C:\Tool Path\$File"
        $expectedArguments = $Arguments
        Invoke-WinUtilMirrorAction -Tool $Tool -Reset:$Reset
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { $Confirm }
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 1 -Exactly -ParameterFilter { $FilePath -eq $expectedFile -and ($Arguments -join '|') -eq $expectedArguments }
        $sync.ProcessRunning | Should -BeFalse
    }
    It 'does not disable TLS verification when setting the pip mirror' {
        Invoke-WinUtilMirrorAction -Tool Pip
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly -ParameterFilter { $Arguments -contains 'global.trusted-host' }
    }
    It 'skips absent pip keys during reset and removes only keys reported present' {
        Mock Invoke-WinUtilMirrorCommand { "global.index-url='https://example.invalid/simple'" } -ParameterFilter { ($Arguments -join '|') -eq 'config|list' }
        Invoke-WinUtilMirrorAction -Tool Pip -Reset
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 1 -Exactly -ParameterFilter { ($Arguments -join '|') -eq 'config|unset|global.index-url' }
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 0 -Exactly -ParameterFilter { ($Arguments -join '|') -eq 'config|unset|global.trusted-host' }
    }
    It 'keeps default conda configuration unchanged when no channels key exists' {
        Mock Invoke-WinUtilMirrorCommand { '{"get":{},"success":true}' }
        Invoke-WinUtilMirrorAction -Tool Conda -Reset
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 1 -Exactly
    }
    It 'removes an existing conda channels override on reset' {
        Mock Invoke-WinUtilMirrorCommand { '{"get":{"channels":["example"]},"success":true}' } -ParameterFilter { $Arguments -contains '--get' }
        Invoke-WinUtilMirrorAction -Tool Conda -Reset
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 1 -Exactly -ParameterFilter { ($Arguments -join '|') -eq 'config|--remove-key|channels' }
    }
    It 'does not report success when conda returns an invalid configuration response' {
        Mock Invoke-WinUtilMirrorCommand { '{"success":false,"error":"fixture"}' }
        { Invoke-WinUtilMirrorAction -Tool Conda -Reset } | Should -Throw
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 1 -Exactly
        Should -Invoke Write-Host -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }
    It 'stops a multistep change on failure and always releases busy state' {
        Mock Invoke-WinUtilMirrorCommand { $sync.ProcessRunning | Should -BeTrue; throw 'exit code 17' }
        { Invoke-WinUtilMirrorAction -Tool Conda } | Should -Throw '*17*'
        Should -Invoke Invoke-WinUtilMirrorCommand -Times 1 -Exactly
        Should -Invoke Write-Host -Times 0 -Exactly
        $sync.ProcessRunning | Should -BeFalse
    }
}

Describe 'Native wrapper exit status and arguments' {
    It 'preserves separated arguments in an installed cmd wrapper path containing spaces' {
        $directory = Join-Path $TestDrive 'tool path'
        $null = New-Item -Path $directory -ItemType Directory -Force
        $wrapper = Join-Path $directory 'fixture.cmd'
        [IO.File]::WriteAllText($wrapper, "@echo off`r`necho %1^|%2^|%3^|%4`r`nexit /b 0`r`n", [Text.Encoding]::ASCII)
        $result = Invoke-WinUtilMirrorCommand -FilePath $wrapper -Arguments @('config', 'set', 'registry', 'https://registry.npmjs.org')
        $result | Should -Be 'config|set|registry|https://registry.npmjs.org'
    }
    It 'throws for a native nonzero exit instead of reporting success' {
        $wrapper = Join-Path $TestDrive 'failure.cmd'
        [IO.File]::WriteAllText($wrapper, "@echo off`r`necho fixture failure 1>&2`r`nexit /b 17`r`n", [Text.Encoding]::ASCII)
        { Invoke-WinUtilMirrorCommand -FilePath $wrapper -Arguments @('config', 'set') } | Should -Throw '*17*fixture failure*'
    }
}
