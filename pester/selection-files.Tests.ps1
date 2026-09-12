BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($path in @('functions/public/Invoke-WPFImpex.ps1', 'functions/private/Update-WinUtilSelections.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root $path))))
    }
}
Describe 'Portable selection files' {
    BeforeEach {
        $script:sync = @{
            configs = @{ applicationsHashtable = @{ WPFInstallwechat = @{content='微信'} }; tweaks = @{ WPFTweaksActivity = @{Content='活动历史'} }; feature = @{} }
            selectedApps = [System.Collections.Generic.List[string]]::new()
            selectedTweaks = [System.Collections.Generic.List[string]]::new()
            selectedToggles = [System.Collections.Generic.List[string]]::new()
            selectedFeatures = [System.Collections.Generic.List[string]]::new()
        }
        $sync.selectedApps.Add('WPFInstallwechat')
    }
    It 'round-trips a one-item list at a Chinese path with an apostrophe' {
        $path = Join-Path $TestDrive "我的'清单.json"
        Invoke-WPFImpex -type export -Config $path
        [IO.File]::ReadAllText($path).TrimStart() | Should -Match '^\['
        $sync.selectedApps.Clear()
        Invoke-WPFImpex -type import -Config $path
        @($sync.selectedApps) | Should -Contain 'WPFInstallwechat'
        $sync.selectedApps.Count | Should -Be 1
    }
    It 'preserves the current selection when any imported ID is unknown' {
        $path = Join-Path $TestDrive 'unknown.json'
        '["WPFTweaksActivity","WPFInstallno-such-app"]' | Set-Content $path -Encoding UTF8
        { Invoke-WPFImpex -type import -Config $path } | Should -Throw '*WPFInstallno-such-app*'
        $sync.selectedApps.Count | Should -Be 1
        $sync.selectedTweaks.Count | Should -Be 0
    }
    It 'rejects objects without clearing current selection' {
        $path = Join-Path $TestDrive 'object.json'
        '{"command":"do-something"}' | Set-Content $path -Encoding UTF8
        { Invoke-WPFImpex -type import -Config $path } | Should -Throw
        $sync.selectedApps.Count | Should -Be 1
    }
}
