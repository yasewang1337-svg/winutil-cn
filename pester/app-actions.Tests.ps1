BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    foreach ($name in @('Initialize-WinUtilAppActions', 'Show-WinUtilAppActions')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $PSScriptRoot "../functions/private/$name.ps1"))))
    }
    function Invoke-WPFInstall { param($PackagesToInstall) }
    function Invoke-WPFUnInstall { param($PackagesToUninstall) }
    function Show-WinUtilTweakDialog { param($Title, $Message) }
    function Invoke-MenuClick($Button) {
        $Button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    }
}

Describe 'Readable per-app action menu' {
    BeforeEach {
        $script:PARAM_OFFLINE = $false
        $script:sync = @{
            ProcessRunning = $false
            Form = [Windows.Window]::new()
            configs = @{ applicationsHashtable = @{
                WPFInstallAlpha = @{ content='软件甲'; winget='Vendor.Alpha'; link='https://example.com/alpha' }
                WPFInstallBeta = @{ content='软件乙'; winget='Vendor.Beta'; link='https://example.com/beta' }
            } }
            WPFInstall = [Windows.Controls.Button]::new()
            WPFUninstall = [Windows.Controls.Button]::new()
        }
        Initialize-WinUtilAppActions
        $script:realPopup = $sync.appPopup
        # Exercise real controls and callbacks, but never display a popup on the host desktop.
        $sync.appPopup = [pscustomobject]@{ IsOpen=$false; PlacementTarget=$null }
        Mock Invoke-WPFInstall {}
        Mock Invoke-WPFUnInstall {}
        Mock Start-Process {}
        Mock Show-WinUtilTweakDialog {}
    }
    AfterEach { $realPopup.IsOpen = $false; $sync.Form.Close() }
    It 'shares live theme resources with the detached popup' {
        $sync.Form.Resources['PanelBackgroundColor'] = [Windows.Media.Brushes]::White
        $realPopup.Child.Background | Should -Be ([Windows.Media.Brushes]::White)
        $sync.Form.Resources['PanelBackgroundColor'] = [Windows.Media.Brushes]::Black
        $realPopup.Child.Background | Should -Be ([Windows.Media.Brushes]::Black)
    }
    It 'exposes readable keyboard-focusable operations and a cycling focus scope' {
        @($sync.AppActionButtons.Values | Where-Object { -not $_.Focusable }).Count | Should -Be 0
        $sync.AppActionButtons.Install.Content | Should -Be '安装 / 升级此软件'
        $sync.AppActionButtons.Uninstall.Content | Should -Be '卸载此软件'
        $sync.AppActionButtons.Info.Content | Should -Be '访问软件官网'
        [Windows.Input.KeyboardNavigation]::GetTabNavigation($realPopup.Child) | Should -Be 'Cycle'
        $realPopup.StaysOpen | Should -BeFalse
    }
    It 'opening updates the heading and scope without changing or installing software' {
        Show-WinUtilAppActions -AppKey WPFInstallBeta -PlacementTarget $sync.WPFInstall -Keyboard
        $sync.AppActionsHeading.Text | Should -Be '软件乙'
        $sync.appPopupSelectedApp | Should -Be 'WPFInstallBeta'
        $sync.AppActionsKeyboard | Should -BeTrue
        $sync.appPopup.IsOpen | Should -BeTrue
        Should -Invoke Invoke-WPFInstall -Times 0
        Should -Invoke Invoke-WPFUnInstall -Times 0
    }
    It 'installs only the app in the menu after closing it' {
        Show-WinUtilAppActions -AppKey WPFInstallBeta -PlacementTarget $sync.WPFInstall
        Invoke-MenuClick $sync.AppActionButtons.Install
        $sync.appPopup.IsOpen | Should -BeFalse
        Should -Invoke Invoke-WPFInstall -Times 1 -Exactly -ParameterFilter { $PackagesToInstall.winget -eq 'Vendor.Beta' }
        Should -Invoke Invoke-WPFUnInstall -Times 0
    }
    It 'keeps uninstall separate from installation' {
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        Invoke-MenuClick $sync.AppActionButtons.Uninstall
        Should -Invoke Invoke-WPFUnInstall -Times 1 -Exactly -ParameterFilter { $PackagesToUninstall.winget -eq 'Vendor.Alpha' }
        Should -Invoke Invoke-WPFInstall -Times 0
    }
    It 'blocks operations if a task starts after the menu opens' {
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        $sync.ProcessRunning = $true
        Invoke-MenuClick $sync.AppActionButtons.Install
        Invoke-MenuClick $sync.AppActionButtons.Uninstall
        Should -Invoke Invoke-WPFInstall -Times 0
        Should -Invoke Invoke-WPFUnInstall -Times 0
    }
    It 'respects busy, offline and disabled main actions' {
        $sync.ProcessRunning = $true
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        $sync.AppActionButtons.Install.IsEnabled | Should -BeFalse
        $sync.AppActionButtons.Uninstall.IsEnabled | Should -BeFalse
        $sync.ProcessRunning = $false
        $script:PARAM_OFFLINE = $true
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        @($sync.AppActionButtons.Values | Where-Object IsEnabled).Count | Should -Be 0
        Invoke-MenuClick $sync.AppActionButtons.Info
        Should -Invoke Start-Process -Times 0
        $script:PARAM_OFFLINE = $false
        $sync.WPFInstall.IsEnabled = $false
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        $sync.AppActionButtons.Install.IsEnabled | Should -BeFalse
        $sync.AppActionButtons.Uninstall.IsEnabled | Should -BeTrue
    }
    It 'rejects local or missing website targets and stale app keys' {
        $sync.configs.applicationsHashtable.WPFInstallAlpha.link = 'file:///C:/Windows/notepad.exe'
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        $sync.AppActionButtons.Info.IsEnabled | Should -BeFalse
        Invoke-MenuClick $sync.AppActionButtons.Info
        Should -Invoke Start-Process -Times 0
        $sync.appPopup.IsOpen = $false
        Show-WinUtilAppActions -AppKey Unknown -PlacementTarget $null
        $sync.appPopup.IsOpen | Should -BeFalse
    }
    It 'opens the recorded website and reports browser failures' {
        Show-WinUtilAppActions -AppKey WPFInstallAlpha -PlacementTarget $sync.WPFInstall
        Invoke-MenuClick $sync.AppActionButtons.Info
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'https://example.com/alpha' }
        Mock Start-Process { throw 'Browser unavailable' }
        Invoke-MenuClick $sync.AppActionButtons.Info
        Should -Invoke Show-WinUtilTweakDialog -Times 1 -Exactly -ParameterFilter { $Title -eq '无法打开官网' }
    }
}
