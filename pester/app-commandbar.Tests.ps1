BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('private/Test-WinUtilInventoryCurrent.ps1', 'private/Update-WinUtilInventoryUi.ps1', 'private/Invalidate-WinUtilInventory.ps1', 'private/Initialize-WinUtilAppCommandBar.ps1', 'public/Invoke-WPFUIElements.ps1', 'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $root "functions/$file"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Invoke-WPFButton { param($Button) }
    $script:configuration = Get-Content (Join-Path $root 'config/appnavigation.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'scripts/main.ps1'), [ref]$tokens, [ref]$errors)
    $script:wireButtons = $ast.Find({
        param($node)
        $node -is [Management.Automation.Language.PipelineAst] -and
        $node.Extent.Text.StartsWith('$sync.keys | ForEach-Object')
    }, $true).Extent.Text
    if (-not $wireButtons) { throw 'Cannot locate production button event registration' }
}

Describe 'Software commands remain usable after moving into a command bar' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $script:form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{Form=$form; preferences=@{}; configs=@{themes=(Get-Content (Join-Path $root 'config/themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json)}}
        Mock Set-Preferences {}
        Mock Invoke-WPFButton {}
        Invoke-WinutilThemeChange -theme Light
        Invoke-WPFUIElements -configVariable $configuration -targetGridName appscategory -columncount 1
        . ([scriptblock]::Create($wireButtons))
    }
    AfterEach { $form.Close() }

    It 'keeps every existing software command reachable, with primary actions outside menus' {
        foreach ($entry in $configuration.PSObject.Properties) {
            $sync[$entry.Name] | Should -Not -BeNullOrEmpty -Because $entry.Name
            $sync[$entry.Name].Name | Should -Be $entry.Name
        }
        $sync.WPFInstall | Should -BeOfType ([Windows.Controls.Button])
        $sync.WPFDetectInstalled | Should -BeOfType ([Windows.Controls.Button])
        $sync.WPFselectedAppsButton | Should -BeOfType ([Windows.Controls.Button])
        $sync.WPFBundlecn_office | Should -BeOfType ([Windows.Controls.MenuItem])
        $sync.WPFGetInstalled | Should -BeOfType ([Windows.Controls.MenuItem])
        $sync.WingetRadioButton.IsChecked | Should -BeTrue
        $sync.InstallInventoryStatus.Text | Should -Match '尚未检测'
        Should -Invoke Invoke-WPFButton -Times 0 -Exactly
    }

    It 'dispatches the primary action only once using the real startup wiring' {
        $sync.WPFInstall.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        Should -Invoke Invoke-WPFButton -Times 1 -Exactly -ParameterFilter { $Button -eq 'WPFInstall' }
    }

    It 'dispatches detection once and exposes a wrapped quiet status line' {
        $sync.WPFDetectInstalled.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        Should -Invoke Invoke-WPFButton -Times 1 -Exactly -ParameterFilter { $Button -eq 'WPFDetectInstalled' }
        $sync.InstallInventoryStatus.TextWrapping | Should -Be 'Wrap'
    }

    It 'shows source, completion time, match count and limitations for a fresh snapshot' {
        $sync.SoftwareInventory = [pscustomobject]@{ Manager='Winget'; CompletedAt=[datetime]'2026-10-12T10:30:00'; MatchedKeys=@('WPFInstallone') }
        Update-WinUtilInventoryUi
        $sync.InstallInventoryStatus.Text | Should -Match 'WinGet.*10-12 10:30.*目录匹配 1 项.*未识别不代表未安装'
        Invalidate-WinUtilInventory -Reason '已启动软件操作，'
        $sync.InstallInventoryStatus.Text | Should -Match '历史结果.*已启动软件操作.*重新检测'
    }

    It 'keeps offline WinGet detection disabled through refresh and enables local Chocolatey' {
        $script:PARAM_OFFLINE = $true
        try {
            Update-WinUtilInventoryUi
            $sync.WPFDetectInstalled.IsEnabled | Should -BeFalse
            $sync.WPFGetInstalled.IsEnabled | Should -BeFalse
            $sync.WPFDetectInstalled.ToolTip | Should -Match '离线模式'
            $sync.preferences.packagemanager = 'Choco'
            Update-WinUtilInventoryUi
            $sync.WPFDetectInstalled.IsEnabled | Should -BeTrue
            $sync.WPFGetInstalled.IsEnabled | Should -BeTrue
        } finally { $script:PARAM_OFFLINE = $false }
    }

    It 'opening a menu does not execute its child actions' {
        $sync.InstallBundlesMenu.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
        $sync.InstallMoreMenu.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
        Should -Invoke Invoke-WPFButton -Times 0 -Exactly
    }

    It 'dispatches bundle and maintenance commands once without bubbling to a second action' {
        $sync.WPFBundlecn_office.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
        $sync.WPFGetInstalled.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
        Should -Invoke Invoke-WPFButton -Times 1 -Exactly -ParameterFilter { $Button -eq 'WPFBundlecn_office' }
        Should -Invoke Invoke-WPFButton -Times 1 -Exactly -ParameterFilter { $Button -eq 'WPFGetInstalled' }
        Should -Invoke Invoke-WPFButton -Times 2 -Exactly
    }

    It 'keeps package sources mutually exclusive and the FOSS toggle dispatches once' {
        $sync.ChocoRadioButton.IsChecked = $true
        $sync.WingetRadioButton.IsChecked | Should -BeFalse
        $sync.WPFToggleFOSSHighlight.IsChecked = $false
        Should -Invoke Invoke-WPFButton -Times 1 -Exactly -ParameterFilter { $Button -eq 'WPFToggleFOSSHighlight' }
    }

    It 'wraps commands within a narrow content area at 150 percent text size' {
        Invoke-WinUtilFontScaling -ScaleFactor 1.5
        $hostGrid = $form.FindName('appscategory')
        $hostGrid.Measure([Windows.Size]::new(620, [double]::PositiveInfinity))
        $hostGrid.Arrange([Windows.Rect]::new(0, 0, 620, $hostGrid.DesiredSize.Height))
        $hostGrid.UpdateLayout()
        foreach ($element in $sync.InstallCommandBar.Children) {
            $point = $element.TranslatePoint([Windows.Point]::new(0, 0), $hostGrid)
            ($point.X + $element.ActualWidth) | Should -BeLessOrEqual 621
            $element.ActualWidth | Should -BeGreaterThan 0
        }
    }
}
