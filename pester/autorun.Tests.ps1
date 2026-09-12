BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root 'functions/public/Invoke-WinUtilAutoRun.ps1'))))
    function Invoke-WPFtweaksbutton {}
    function Invoke-WPFInstall { param([switch]$NonInteractive) }
}
Describe 'Command-line plan completion' {
    BeforeEach {
        $script:sync = @{ selectedTweaks = @('WPFTweaksActivity'); selectedToggles = @(); selectedFeatures = @(); selectedApps = @('WPFInstallwechat'); ProcessRunning = $false }
        Mock Invoke-WPFInstall { $sync.LastPackageResults = @([pscustomobject]@{Status='Succeeded';NeedsReboot=$false}) }
    }
    It 'stops before installing when settings failed' {
        Mock Invoke-WPFtweaksbutton { $sync.LastTweakResults = @([pscustomobject]@{Status='Failed'}) }
        { Invoke-WinUtilAutoRun } | Should -Throw
        Should -Invoke Invoke-WPFInstall -Times 0 -Exactly
    }
    It 'does not report completion when settings returned no result' {
        Mock Invoke-WPFtweaksbutton {}
        { Invoke-WinUtilAutoRun } | Should -Throw
        Should -Invoke Invoke-WPFInstall -Times 0 -Exactly
    }
    It 'propagates partial software failures' {
        Mock Invoke-WPFtweaksbutton { $sync.LastTweakResults = @([pscustomobject]@{Status='Success'}) }
        Mock Invoke-WPFInstall { $sync.LastPackageResults = @([pscustomobject]@{Status='Failed';NeedsReboot=$false}) }
        { Invoke-WinUtilAutoRun } | Should -Throw
    }
    It 'runs the supported plan with noninteractive software execution' {
        Mock Invoke-WPFtweaksbutton { $sync.LastTweakResults = @([pscustomobject]@{Status='Success'}) }
        { Invoke-WinUtilAutoRun } | Should -Not -Throw
        Should -Invoke Invoke-WPFInstall -Times 1 -Exactly -ParameterFilter { $NonInteractive }
    }
}
