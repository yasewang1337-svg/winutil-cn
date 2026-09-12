function Invoke-WPFHome {
    <# .SYNOPSIS
        Home shortcuts navigate or select a plan; they never run a system change.
    #>
    param([Parameter(Mandatory)][string]$Action)
    switch ($Action) {
        'Install' { Invoke-WPFTab 'WPFTab1BT' }
        'Manage' { Invoke-WPFTab 'WPFTab1BT' }
        'Settings' {
            Invoke-WPFTab 'WPFTab2BT'
            if (-not $sync.ProcessRunning) { Invoke-WPFPresets 'Minimal' -checkboxfilterpattern 'WPFTweak*' }
        }
        'Repair' { Invoke-WPFTab 'WPFTab3BT' }
        'History' { Invoke-WPFTweakHistory }
        'Import' { if (-not $sync.ProcessRunning) { Invoke-WPFImpex -type 'import'; Invoke-WPFTab 'WPFTab1BT' } }
        'Export' { if (-not $sync.ProcessRunning) { Invoke-WPFImpex -type 'export' } }
        'Help' { Start-Process 'https://github.com/yasewang1337-svg/winutil-cn/blob/main/docs/content/userguide/getting-started/_index.md' }
    }
}
