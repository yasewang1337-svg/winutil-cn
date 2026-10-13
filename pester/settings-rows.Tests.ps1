BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @(
        'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1',
        'private/Set-WinUtilConfigLayout.ps1', 'private/Set-WinUtilNavigationLayout.ps1',
        'private/New-WinUtilSettingRow.ps1', 'private/Initialize-WinUtilSettingToolTip.ps1',
        'private/Update-WinUtilTweakSelectionUi.ps1', 'private/Find-TweaksByNameOrDescription.ps1',
        'private/Invoke-WinUtilKeyboardShortcut.ps1',
        'private/Initialize-WinUtilTweakUiCallbacks.ps1',
        'private/Reset-WPFCheckBoxes.ps1', 'public/Invoke-WPFUIElements.ps1',
        'public/Invoke-WPFSelectedCheckboxesUpdate.ps1', 'public/Invoke-WPFtweaksbutton.ps1'
    )) { . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file")))) }
    function Set-Preferences { param([switch]$save) }
    function Get-WinUtilToggleStatus { param($Toggle) return $false }
    function Invoke-WinUtilTweakToggle { param($Sender, $Enabled) $sync.ToggleCalls.Add([pscustomobject]@{ Name=$Sender.Name; Enabled=$Enabled }) }
    function Update-WinUtilAppSelectionUi {}
    function Confirm-WinUtilTweakPlan { param($Tweaks, $DNSProvider) $sync.Plan = @{ Tweaks=@($Tweaks); DNS=$DNSProvider }; return $true }
    function Invoke-WPFRunspace { param($ParameterList, $ScriptBlock) $sync.RunParameters = $ParameterList }
    function Get-SettingRows {
        param($Grid)
        foreach ($section in $Grid.Children) {
            foreach ($item in $section.Child.Children[0].Items) {
                if ($item -is [Windows.Controls.Border] -and $item.Tag.WinUtilSettingRow) { $item }
            }
        }
    }
    function Set-SettingFixtureSize {
        param([double]$Width=1280, [double]$Height=800, [double]$Scale=1.0)
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        Set-WinUtilNavigationLayout -AvailableWidth $Width
        $sync.Form.Content.Measure([Windows.Size]::new($Width, $Height))
        $sync.Form.Content.Arrange([Windows.Rect]::new(0, 0, $Width, $Height))
        $sync.Form.Content.UpdateLayout()
        $sync.Form.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
        $sync.Form.Content.UpdateLayout()
    }
}

Describe 'Setting rows preserve native actions and explain the entire row' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form=$form; preferences=@{}; configs=@{
            themes=[IO.File]::ReadAllText((Join-Path $script:root 'config/themes.json')) | ConvertFrom-Json
            regiondns=[pscustomobject]@{ International='Default Cloudflare Google'; Domestic='Default AliDNS DNSPod' }
        }; selectedTweaks=[Collections.Generic.List[string]]::new(); selectedApps=[Collections.Generic.List[string]]::new()
            selectedFeatures=[Collections.Generic.List[string]]::new(); selectedToggles=[Collections.Generic.List[string]]::new()
            ToggleCalls=[Collections.Generic.List[object]]::new(); ProcessRunning=$false }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name] = $form.FindName($node.Name) }
        Invoke-WinutilThemeChange -theme Dark
        $fixture = [pscustomobject]@{
            WPFTweaksAlpha = [pscustomobject]@{ Content='Alpha setting with a long readable title'; Description='Full literal [*] description. More detail for keyboard and pointer users.'; Category='Common'; Panel='1'; Link='https://example.invalid/alpha' }
            WPFTweaksBeta = [pscustomobject]@{ Content='Beta setting'; Description='A different operation'; Category='z__Advanced'; Panel='1' }
            WPFToggleFixture = [pscustomobject]@{ Content='Immediate setting'; Description='This switch applies immediately'; Category='Switches'; Panel='2'; Type='Toggle' }
            WPFActionFixture = [pscustomobject]@{ Content='Open a native control panel'; Description='The action remains an original button'; Category='Actions'; Panel='2'; Type='Button' }
            WPFchangedns = [pscustomobject]@{ Content='DNS provider'; Description='Choose a provider then review changes'; Category='Actions'; Panel='2'; Type='Combobox'; ComboItems='Default Cloudflare Google' }
            WPFDNSRegion = [pscustomobject]@{ Content='DNS region'; Category='Actions'; Panel='2'; Type='Combobox'; ComboItems='International Domestic'; LinkedCombo='WPFchangedns'; LinkedData='regiondns' }
        }
        Invoke-WPFUIElements -configVariable $fixture -targetGridName tweakspanel -columncount 2
        $form.FindName('WPFTab2').IsSelected = $true
        Set-SettingFixtureSize
        $rows = @(Get-SettingRows -Grid $form.FindName('tweakspanel'))
        $row = @($rows | Where-Object { $_.Tag.Key -eq 'WPFTweaksAlpha' })[0]
        $checkbox = $sync.WPFTweaksAlpha
    }
    AfterEach {
        foreach ($entry in $rows) { if ($entry.ToolTip -is [Windows.Controls.ToolTip]) { $entry.ToolTip.IsOpen = $false } }
        $form.Close()
    }

    It 'exposes the same full description across the row without eager popup construction' {
        $row.ToolTip | Should -Be $row.Tag.Description
        $checkbox.ToolTip | Should -BeNullOrEmpty
        $checkbox.Content.IsHitTestVisible | Should -BeFalse
        [Windows.Automation.AutomationProperties]::GetHelpText($checkbox) | Should -Be $row.Tag.Description
        [Windows.Automation.AutomationProperties]::GetName($checkbox) | Should -Be $row.Tag.Title
        $sync.WPFTweaksAlphaLink.ToolTip | Should -Be 'https://example.invalid/alpha'
        @($rows | Where-Object { $_.ToolTip -is [Windows.Controls.ToolTip] }).Count | Should -Be 0
        Initialize-WinUtilSettingToolTip -Row $row
        $tip = $row.ToolTip
        $tip.Content.Children[1].Text | Should -Be $row.Tag.Description
        Initialize-WinUtilSettingToolTip -Row $row
        [object]::ReferenceEquals($tip, $row.ToolTip) | Should -BeTrue
        $sync.ToggleCalls.Count | Should -Be 0
    }

    It 'changes selection exactly once for Space and never applies a setting' {
        $parameters = [Windows.Interop.HwndSourceParameters]::new('Isolated setting keyboard fixture')
        $parameters.WindowStyle = 0
        $source = [Windows.Interop.HwndSource]::new($parameters)
        try {
            foreach ($kind in @('KeyDown', 'KeyUp')) {
                $event = [Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice, $source, 0, [Windows.Input.Key]::Space)
                $event.RoutedEvent = if ($kind -eq 'KeyDown') { [Windows.UIElement]::KeyDownEvent } else { [Windows.UIElement]::KeyUpEvent }
                $checkbox.RaiseEvent($event)
            }
        } finally { $source.Dispose() }
        $checkbox.IsChecked | Should -BeTrue
        $sync.selectedTweaks.Count | Should -Be 1
        $sync.selectedTweaks[0] | Should -Be 'WPFTweaksAlpha'
        $checkbox.Template.FindName('SettingCheckMark', $checkbox).Visibility | Should -Be 'Visible'
        $form.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
        $row.Background.ToString() | Should -Be $form.Resources['AppInstallSelectedColor'].ToString()
        $sync.ToggleCalls.Count | Should -Be 0
        $checkbox.IsChecked = $false
        $sync.selectedTweaks.Count | Should -Be 0
    }

    It 'opens help with F1 and dismisses it with Escape without applying or selecting' {
        $sync.SearchBar.Text = 'preserve this search'
        $form.Add_PreviewKeyDown({ param($sender,$eventArgs) Invoke-WinUtilKeyboardShortcut -EventArgs $eventArgs })
        $parameters = [Windows.Interop.HwndSourceParameters]::new('Isolated setting help fixture')
        $parameters.WindowStyle = 0
        $source = [Windows.Interop.HwndSource]::new($parameters)
        try {
            foreach ($key in @([Windows.Input.Key]::F1, [Windows.Input.Key]::Escape)) {
                $event = [Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice, $source, 0, $key)
                $event.RoutedEvent = [Windows.UIElement]::PreviewKeyDownEvent
                $checkbox.RaiseEvent($event)
                $event.Handled | Should -BeTrue
                $row.ToolTip.IsOpen | Should -Be ($key -eq [Windows.Input.Key]::F1)
            }
        } finally { $source.Dispose() }
        $sync.selectedTweaks.Count | Should -Be 0
        $sync.ToggleCalls.Count | Should -Be 0
        $sync.SearchBar.Text | Should -Be 'preserve this search'
    }

    It 'dismisses keyboard help on focus loss and when navigating away' {
        $parameters = [Windows.Interop.HwndSourceParameters]::new('Isolated setting navigation fixture')
        $parameters.WindowStyle = 0
        $source = [Windows.Interop.HwndSource]::new($parameters)
        $surface = $form.Content
        $form.Content = $null
        try {
            $source.RootVisual = $surface
            $surface.Measure([Windows.Size]::new(1280,800))
            $surface.Arrange([Windows.Rect]::new(0,0,1280,800))
            $surface.UpdateLayout()
            Initialize-WinUtilSettingToolTip -Row $row
            $row.ToolTip.PlacementTarget = $checkbox
            $row.ToolTip.IsOpen = $true
            $lostFocus = [Windows.Input.KeyboardFocusChangedEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice,0,$checkbox,$sync.SearchBar)
            $lostFocus.RoutedEvent = [Windows.UIElement]::LostKeyboardFocusEvent
            $checkbox.RaiseEvent($lostFocus)
            $row.ToolTip.IsOpen | Should -BeFalse
            $row.ToolTip.IsOpen = $true
            $row.IsVisible | Should -BeTrue
            $form.FindName('WPFTab3').IsSelected = $true
            $surface.UpdateLayout()
            $row.ToolTip.IsOpen | Should -BeFalse
        } finally {
            $source.RootVisual = $null
            $source.Dispose()
            $form.Content = $surface
        }
        $sync.selectedTweaks.Count | Should -Be 0
        $sync.ToggleCalls.Count | Should -Be 0
    }

    It 'limits an immediate change to its native switch' {
        $immediate = @($rows | Where-Object { $_.Tag.Kind -eq 'Immediate' })[0]
        $mouse = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 0, [Windows.Input.MouseButton]::Left)
        $mouse.RoutedEvent = [Windows.UIElement]::MouseLeftButtonUpEvent
        $immediate.RaiseEvent($mouse)
        $sync.ToggleCalls.Count | Should -Be 0
        $sync.WPFToggleFixture.IsChecked = $true
        $sync.ToggleCalls.Count | Should -Be 1
        $sync.ToggleCalls[0].Enabled | Should -BeTrue
        $sync.selectedTweaks.Count | Should -Be 0
    }

    It 'treats search characters literally and preserves choices through rich help, no results, and clear' {
        $checkbox.IsChecked = $true
        $sync.WPFchangedns.SelectedIndex = 2
        Initialize-WinUtilSettingToolTip -Row $row
        Find-TweaksByNameOrDescription -SearchString '  [*]  '
        @($rows | Where-Object { $_.Visibility -eq 'Visible' }).Count | Should -Be 1
        $row.Visibility | Should -Be 'Visible'
        Find-TweaksByNameOrDescription -SearchString 'No matching setting'
        $sync.WPFTweakFilterEmpty.Visibility | Should -Be 'Visible'
        @($rows | Where-Object { $_.Visibility -eq 'Visible' }).Count | Should -Be 0
        foreach ($section in $form.FindName('tweakspanel').Children) {
            $section.Visibility | Should -Be 'Collapsed'
            @($section.Child.Children[0].Items | Where-Object { $_ -is [Windows.Controls.Label] -and $_.Visibility -eq 'Visible' }).Count | Should -Be 0
        }
        Find-TweaksByNameOrDescription -SearchString ''
        $sync.WPFTweakFilterEmpty.Visibility | Should -Be 'Collapsed'
        @($rows | Where-Object { $_.Visibility -eq 'Visible' }).Count | Should -Be 6
        $checkbox.IsChecked | Should -BeTrue
        $sync.WPFchangedns.SelectedIndex | Should -Be 2
        $sync.selectedTweaks.Count | Should -Be 1
        $sync.ToggleCalls.Count | Should -Be 0
    }

    It 'keeps DNS-only changes reviewable but does not enable restore without a selection' {
        $sync.WPFTweaksbutton.IsEnabled | Should -BeFalse
        $sync.WPFUndoall.IsEnabled | Should -BeFalse
        [Windows.Controls.ToolTipService]::GetShowOnDisabled($sync.WPFTweaksbutton) | Should -BeTrue
        $sync.WPFchangedns.SelectedIndex = 1
        $sync.WPFTweaksbutton.IsEnabled | Should -BeTrue
        $sync.WPFUndoall.IsEnabled | Should -BeFalse
        $sync.WPFSelectedTweaksSummary.Text | Should -Match '1'
        Invoke-WPFtweaksbutton
        $sync.Plan.DNS | Should -Be 'Cloudflare'
        $sync.Plan.Tweaks.Count | Should -Be 0
        @($sync.RunParameters | Where-Object { $_[0] -eq 'DNSProvider' })[0][1] | Should -Be 'Cloudflare'
        $sync.ProcessRunning = $false
        $sync.WPFchangedns.SelectedIndex = 0
        $sync.WPFTweaksbutton.IsEnabled | Should -BeFalse
        $sync.WPFSelectedTweaksSummary.Text | Should -Match '0'
    }

    It 'refreshes an imported selection even when checkbox values do not change and respects a busy operation' {
        $checkbox.IsChecked = $true
        $sync.WPFSelectedTweaksSummary.Text = 'stale'
        Reset-WPFCheckBoxes
        $sync.WPFSelectedTweaksSummary.Text | Should -Match '1'
        $sync.WPFUndoall.IsEnabled | Should -BeTrue
        $sync.ProcessRunning = $true
        $sync.WPFTweaksbutton.IsEnabled = $false
        $sync.WPFUndoall.IsEnabled = $false
        Update-WinUtilTweakSelectionUi
        $sync.WPFTweaksbutton.IsEnabled | Should -BeFalse
        $sync.WPFUndoall.IsEnabled | Should -BeFalse
        $sync.ToggleCalls.Count | Should -Be 0
        Initialize-WinUtilTweakUiCallbacks
        $sync.ProcessRunning = $false
        $sync.TweakProgressPercent = 100
        $sync.TweakProgressAction.Invoke()
        $sync.WPFTweaksbutton.IsEnabled | Should -BeTrue
        $sync.WPFUndoall.IsEnabled | Should -BeTrue
        $sync.ProcessRunning = $true
        $checkbox.IsChecked = $false
        $sync.ProcessRunning = $false
        $sync.TweakProgressAction.Invoke()
        $sync.WPFTweaksbutton.IsEnabled | Should -BeFalse
        $sync.WPFUndoall.IsEnabled | Should -BeFalse
    }

    It 'replaces regional DNS options without duplicates or stale pending state' {
        foreach ($index in @(1,0,1,0)) {
            $sync.WPFchangedns.SelectedIndex = 1
            $sync.WPFTweaksbutton.IsEnabled | Should -BeTrue
            $sync.WPFDNSRegion.SelectedIndex = $index
            $sync.WPFchangedns.Items.Count | Should -Be 3
            $sync.WPFchangedns.SelectedIndex | Should -Be 0
            $sync.WPFchangedns.Text | Should -Be 'Default'
            $sync.WPFTweaksbutton.IsEnabled | Should -BeFalse
            $sync.WPFSelectedTweaksSummary.Text | Should -Match '0'
            $expected = if ($index -eq 1) { 'AliDNS' } else { 'Cloudflare' }
            $sync.WPFchangedns.Items[1].Content | Should -Be $expected
        }
        $sync.ToggleCalls.Count | Should -Be 0
    }

    It 'resets the scroll only when the trimmed query changes' {
        Set-SettingFixtureSize -Width 800 -Height 600 -Scale 1.5
        Find-TweaksByNameOrDescription -SearchString ''
        $scroll = $sync.WPFTweaksScroll
        $scroll.ScrollToBottom()
        $form.Content.UpdateLayout()
        $form.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
        $offset = $scroll.VerticalOffset
        $offset | Should -BeGreaterThan 0
        Find-TweaksByNameOrDescription -SearchString '  '
        $form.Content.UpdateLayout()
        $scroll.VerticalOffset | Should -Be $offset
        Find-TweaksByNameOrDescription -SearchString 'Alpha'
        $form.Content.UpdateLayout()
        $form.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
        $scroll.VerticalOffset | Should -Be 0
    }

    It 'keeps long titles inside a native row at <Width> pixels in <Theme> at <Scale>' -ForEach @(
        @{ Width=1280; Theme='Dark'; Scale=1.0 }, @{ Width=800; Theme='Dark'; Scale=1.5 },
        @{ Width=1280; Theme='Light'; Scale=1.5 }, @{ Width=800; Theme='Light'; Scale=1.5 }
    ) {
        Invoke-WinutilThemeChange -theme $Theme
        Set-SettingFixtureSize -Width $Width -Height 800 -Scale $Scale
        $checkbox.ActualWidth | Should -BeGreaterThan 100
        $checkbox.ActualWidth | Should -BeLessOrEqual $row.ActualWidth
        $checkbox.Content.Children[0].TextWrapping | Should -Be 'Wrap'
        $checkbox.Content.Children[0].Foreground.ToString() | Should -Be $form.Resources['MainForegroundColor'].ToString()
        $checkbox.Content.Children[1].TextTrimming | Should -Be 'CharacterEllipsis'
        $checkbox.Content.Children[0].FontSize | Should -Be ([double]$sync.configs.themes.shared.FontSize * $Scale)
        Initialize-WinUtilSettingToolTip -Row $row
        $row.ToolTip.Foreground.ToString() | Should -Be $form.Resources['MainForegroundColor'].ToString()
        [double]::IsNaN($sync.WPFActionFixture.Width) | Should -BeTrue
        $sync.WPFActionFixture.ActualWidth | Should -BeGreaterThan 100
        $sync.WPFActionFixture.BorderBrush.Color.A | Should -BeGreaterThan 0
        $actionLeft = $sync.WPFActionFixture.Content.TransformToAncestor($sync.WPFActionFixture).Transform([Windows.Point]::new(0,0)).X
        $actionLeft | Should -BeLessThan ($sync.WPFActionFixture.ActualWidth / 4)
        $actionPeer = [Windows.Automation.Peers.UIElementAutomationPeer]::CreatePeerForElement($sync.WPFActionFixture)
        $actionPeer.GetPattern([Windows.Automation.Peers.PatternInterface]::Invoke) | Should -Not -BeNullOrEmpty
        $sync.WPFchangedns.SelectedIndex | Should -Be 0
    }
}
