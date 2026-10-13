BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @(
        'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1',
        'private/Set-WinUtilConfigLayout.ps1', 'private/Set-WinUtilNavigationLayout.ps1',
        'public/Invoke-WPFUIElements.ps1'
    )) { . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file")))) }
    function Set-Preferences { param([switch]$save) }
    function Invoke-WPFSelectedCheckboxesUpdate { param($type, $checkboxName) }
    function Get-WinUtilToggleStatus { param($Toggle) return $false }
    function Invoke-WinUtilTweakToggle { throw 'UI tests must never change system settings.' }
}

Describe 'Crown interface keeps native controls and existing selections usable' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form = $form; preferences = @{}; configs = @{
            themes = [IO.File]::ReadAllText((Join-Path $script:root 'config/themes.json')) | ConvertFrom-Json
        } }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name] = $form.FindName($node.Name) }
        Invoke-WinutilThemeChange -theme Dark
    }
    AfterEach { $form.Close() }

    It 'reflows <GridName> without replacing controls or changing pending choices' -ForEach @(
        @{ GridName = 'tweakspanel' }, @{ GridName = 'featurespanel' }
    ) {
        $fixture = [pscustomobject]@{
            WPFTweaksLayoutFixture = [pscustomobject]@{ Content = 'Keep my selection'; Category = 'Choices'; Panel = '1' }
            WPFLayoutComboFixture = [pscustomobject]@{ Content = 'Keep my option'; Category = 'Options'; Panel = '2'; Type = 'Combobox'; ComboItems = 'First Second Third' }
        }
        Invoke-WPFUIElements -configVariable $fixture -targetGridName $GridName -columncount 2
        $grid = $form.FindName($GridName)
        $checkbox = $sync.WPFTweaksLayoutFixture
        $combo = $sync.WPFLayoutComboFixture
        $checkbox.IsChecked = $true
        $combo.SelectedIndex = 2
        $panels = @($grid.Children)
        Set-WinUtilConfigLayout -Grid $grid -AvailableWidth 1100
        $grid.ColumnDefinitions.Count | Should -Be 2
        Set-WinUtilConfigLayout -Grid $grid -AvailableWidth 600
        $grid.ColumnDefinitions.Count | Should -Be 1
        $grid.RowDefinitions.Count | Should -Be $panels.Count
        [Windows.Controls.Grid]::GetRow($panels[1]) | Should -BeGreaterThan ([Windows.Controls.Grid]::GetRow($panels[0]))
        $row = $grid.RowDefinitions[0]
        Set-WinUtilConfigLayout -Grid $grid -AvailableWidth 650
        [object]::ReferenceEquals($row, $grid.RowDefinitions[0]) | Should -BeTrue -Because 'unchanged layout must not rebuild rows on every size event'
        Set-WinUtilConfigLayout -Grid $grid -AvailableWidth 1100
        $grid.ColumnDefinitions.Count | Should -Be 2
        [Windows.Controls.Grid]::GetColumn($panels[1]) | Should -Not -Be ([Windows.Controls.Grid]::GetColumn($panels[0]))
        [object]::ReferenceEquals($checkbox, $sync.WPFTweaksLayoutFixture) | Should -BeTrue
        [object]::ReferenceEquals($combo, $sync.WPFLayoutComboFixture) | Should -BeTrue
        [object]::ReferenceEquals($panels[0], $grid.Children[0]) | Should -BeTrue
        $checkbox.IsChecked | Should -BeTrue
        $combo.SelectedIndex | Should -Be 2
        Invoke-WinUtilFontScaling -ScaleFactor 1.5
        Set-WinUtilConfigLayout -Grid $grid -AvailableWidth 1100
        $grid.ColumnDefinitions.Count | Should -Be 1
        Set-WinUtilConfigLayout -Grid $grid -AvailableWidth 1800
        $grid.ColumnDefinitions.Count | Should -Be 2
        $checkbox.IsChecked | Should -BeTrue
        $combo.SelectedIndex | Should -Be 2

        # Exercise the real Grid SizeChanged hook as the containing viewport is
        # arranged again, rather than relying only on the explicit-width API.
        Invoke-WinUtilFontScaling -ScaleFactor 1.0
        $tab = if ($GridName -eq 'tweakspanel') { 'WPFTab2' } else { 'WPFTab3' }
        $form.FindName($tab).IsSelected = $true
        foreach ($width in @(1280, 800, 1280)) {
            Set-WinUtilNavigationLayout -AvailableWidth $width
            $form.Content.Measure([Windows.Size]::new($width, 800))
            $form.Content.Arrange([Windows.Rect]::new(0, 0, $width, 800))
            $form.Content.UpdateLayout()
            $form.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
            $form.Content.UpdateLayout()
            $expectedColumns = if ($width -eq 800) { 1 } else { 2 }
            $grid.ColumnDefinitions.Count | Should -Be $expectedColumns -Because "real viewport resizing must trigger reflow at $width pixels"
            $checkbox.IsChecked | Should -BeTrue
            $combo.SelectedIndex | Should -Be 2
        }
        Set-WinUtilNavigationLayout -AvailableWidth 800
        $form.Content.Measure([Windows.Size]::new(800, 600))
        $form.Content.Arrange([Windows.Rect]::new(0, 0, 800, 600))
        $form.Content.UpdateLayout()
        $form.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
        $grid.ColumnDefinitions.Count | Should -Be 1
        Invoke-WPFUIElements -configVariable $fixture -targetGridName $GridName -columncount 2
        $form.Content.UpdateLayout()
        $grid.ColumnDefinitions.Count | Should -Be 1 -Because 'initialization must invalidate the previous compact-layout cache before rebuilding columns'
        $grid.RowDefinitions.Count | Should -Be $grid.Children.Count
    }

    It 'preserves native checked-state feedback in the <Theme> theme' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        Invoke-WinutilThemeChange -theme $Theme
        $hostPanel = $form.FindName('NavLogoPanel')
        foreach ($kind in @('CheckBox', 'RadioButton')) {
            $control = if ($kind -eq 'CheckBox') { [Windows.Controls.CheckBox]::new() } else { [Windows.Controls.RadioButton]::new() }
            $control.Content = 'Selectable fixture'
            $null = $hostPanel.Children.Add($control)
            $form.Content.Measure([Windows.Size]::new(1280, 800))
            $form.Content.Arrange([Windows.Rect]::new(0, 0, 1280, 800))
            $form.Content.UpdateLayout()
            $null = $control.ApplyTemplate()
            $control.Focusable | Should -BeTrue
            $control.IsTabStop | Should -BeTrue
            $indicatorName = if ($kind -eq 'CheckBox') { 'CheckMarkContainer' } else { 'InnerCircle' }
            $indicator = $control.Template.FindName($indicatorName, $control)
            $indicator | Should -Not -BeNullOrEmpty
            $control.IsChecked = $true
            $indicator.Visibility | Should -Be 'Visible'
            $control.IsChecked = $false
            $indicator.Visibility | Should -Be 'Collapsed'
            $control.Foreground.Color | Should -Be $form.Resources.MainForegroundColor.Color
            $peer = [Windows.Automation.Peers.UIElementAutomationPeer]::CreatePeerForElement($control)
            $pattern = if ($kind -eq 'CheckBox') { [Windows.Automation.Peers.PatternInterface]::Toggle } else { [Windows.Automation.Peers.PatternInterface]::SelectionItem }
            $peer.GetPattern($pattern) | Should -Not -BeNullOrEmpty
        }
    }

    It 'keeps marked advanced tweak categories after ordinary categories across locale sorting' {
        $common = [string][char]0x5E38 + ' Common'
        $fixture = [pscustomobject]@{
            WPFTweaksAdvancedFixture = [pscustomobject]@{ Content = 'Advanced option'; Category = 'z__Advanced'; Panel = '1' }
            WPFTweaksCommonFixture = [pscustomobject]@{ Content = 'Common option'; Category = $common; Panel = '1' }
            WPFTweaksOtherFixture = [pscustomobject]@{ Content = 'Other option'; Category = 'Other'; Panel = '1' }
        }
        Invoke-WPFUIElements -configVariable $fixture -targetGridName tweakspanel -columncount 2
        $items = $form.FindName('tweakspanel').Children[0].Child.Children[0].Items
        $labels = @($items | Where-Object { $_ -is [Windows.Controls.Label] } | ForEach-Object { $_.Content })
        $ordinary = @(@($common, 'Other') | Sort-Object)
        $labels[0] | Should -Be $ordinary[0]
        $labels[1] | Should -Be $ordinary[1]
        $labels[2] | Should -Be 'Advanced'
    }

    It 'keeps hover text readable and supplies an explicit visible keyboard-focus treatment' {
        foreach ($kind in @('CheckBox', 'RadioButton')) {
            $control = if ($kind -eq 'CheckBox') { [Windows.Controls.CheckBox]::new() } else { [Windows.Controls.RadioButton]::new() }
            $null = $form.FindName('NavLogoPanel').Children.Add($control)
            $null = $control.ApplyTemplate()
            $hover = @($control.Template.Triggers | Where-Object { $_ -is [Windows.Trigger] -and $_.Property.Name -eq 'IsMouseOver' })
            foreach ($trigger in $hover) {
                @($trigger.Setters | Where-Object { $_.Property.Name -eq 'Foreground' }).Count | Should -Be 0 -Because 'hover must not fade the control label into its surface'
            }
            $focus = @($control.Template.Triggers | Where-Object { $_ -is [Windows.Trigger] -and $_.Property.Name -in @('IsKeyboardFocused', 'IsKeyboardFocusWithin') })
            $focus.Count | Should -BeGreaterThan 0 -Because "$kind must expose keyboard focus even without a mouse hover"
            @($focus.Setters | Where-Object { $_.Property.Name -in @('BorderBrush', 'BorderThickness', 'Stroke', 'StrokeThickness', 'Visibility') }).Count | Should -BeGreaterThan 0
        }
    }

    It 'keeps <Style> switch state clear in <Theme> without running an action' -ForEach @(
        @{Style='ToggleSwitchStyle'; Theme='Dark'}, @{Style='ToggleSwitchStyle'; Theme='Light'},
        @{Style='ColorfulToggleSwitchStyle'; Theme='Dark'}, @{Style='ColorfulToggleSwitchStyle'; Theme='Light'}
    ) {
        Invoke-WinutilThemeChange -theme $Theme
        $control = [Windows.Controls.CheckBox]::new()
        $control.Style = $form.Resources[$Style]
        $null = $form.FindName('NavLogoPanel').Children.Add($control)
        $null = $control.ApplyTemplate()
        $track = $control.Template.FindName('SwitchTrack', $control)
        $thumb = $control.Template.FindName('SwitchThumb', $control)
        $control.IsChecked = $false
        $thumb.HorizontalAlignment | Should -Be 'Left'
        $track.Background.Color | Should -Be $form.Resources.ButtonBackgroundColor.Color
        $control.IsChecked = $true
        $thumb.HorizontalAlignment | Should -Be 'Right'
        $track.Background.Color | Should -Be $form.Resources.AccentColor.Color
        $thumb.Fill.Color | Should -Be $form.Resources.PrimaryButtonForegroundColor.Color
        Invoke-WinUtilFontScaling -ScaleFactor 1.5
        $control.IsChecked | Should -BeTrue
        $form.Resources.ToggleSwitchWidth | Should -Be ([double]$sync.configs.themes.shared.ToggleSwitchWidth * 1.5)
        $form.Resources.ToggleSwitchHeight | Should -Be ([double]$sync.configs.themes.shared.ToggleSwitchHeight * 1.5)
        $focus = @($control.Template.Triggers | Where-Object { $_ -is [Windows.Trigger] -and $_.Property.Name -in @('IsKeyboardFocused', 'IsKeyboardFocusWithin') })
        $focus.Count | Should -BeGreaterThan 0
        $peer = [Windows.Automation.Peers.CheckBoxAutomationPeer]::new($control)
        $peer.GetPattern([Windows.Automation.Peers.PatternInterface]::Toggle) | Should -Not -BeNullOrEmpty
        $control.IsChecked = $false
        $thumb.HorizontalAlignment | Should -Be 'Left'
    }
}
