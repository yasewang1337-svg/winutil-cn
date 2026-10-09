BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('Initialize-InstallAppEntry', 'Invoke-WinutilThemeChange', 'Invoke-WinUtilFontScaling')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/private/$file.ps1"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Invoke-WPFSelectedCheckboxesUpdate {
        param($type, $checkboxName)
        $script:selectionEvents.Add("${type}:$checkboxName")
    }
    function Show-WinUtilAppActions { param($AppKey, $PlacementTarget, [switch]$Keyboard) }
    function Find-TestAppToolTip($Element) {
        while ($Element) {
            $tip = [Windows.Controls.ToolTipService]::GetToolTip($Element)
            if ($null -ne $tip) { return $tip }
            $Element = [Windows.LogicalTreeHelper]::GetParent($Element)
        }
    }
}

Describe 'Software row descriptions and input' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $script:form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{
            Form = $form; preferences = @{}
            configs = @{ themes = Get-Content (Join-Path $script:root 'config/themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json }
        }
        $script:Apps = @{
            WPFInstallHover = @{ content = 'Everything 文件搜索'; description = '按文件名瞬间定位文件和文件夹。适合查找文档、照片和下载文件。'; winget = 'voidtools.Everything'; choco = 'everything' }
        }
        $script:selectionEvents = [Collections.Generic.List[string]]::new()
        Invoke-WinutilThemeChange -theme Dark
        $script:panel = [Windows.Controls.WrapPanel]::new()
        $null = $form.FindName('appspanel').Children.Add($panel)
        $script:checkbox = Initialize-InstallAppEntry -TargetElement $panel -AppKey 'WPFInstallHover'
        $sync.WPFInstallHover = $checkbox
        $script:border = $checkbox.Parent
        $script:tip = $border.ToolTip
        Mock Show-WinUtilAppActions {}
    }
    AfterEach { $tip.IsOpen = $false; $form.Close() }

    It 'uses one descriptive tooltip for the name, summary, checkbox and row padding' {
        $checkbox.ToolTip | Should -BeNullOrEmpty
        $checkbox.Content.ToolTip | Should -BeNullOrEmpty
        foreach ($element in @($checkbox.Content.Children[0], $checkbox.Content.Children[1], $checkbox.Content, $checkbox, $border)) {
            [object]::ReferenceEquals((Find-TestAppToolTip $element), $tip) | Should -BeTrue
        }
        $tip.Content.Children[0].Text | Should -Be $Apps.WPFInstallHover.content
        $tip.Content.Children[1].Text | Should -Be $Apps.WPFInstallHover.description
        $tip.Content.Children[2].Text | Should -Be "winget: voidtools.Everything`nchoco: everything"
    }

    It 'shows complete literal descriptions without interpreting markup or PowerShell' {
        $Apps.WPFInstallLiteral = @{ content = '<软件名称>'; description = '<b>说明</b> $(Get-Date) <script>alert(1)</script>' }
        $literal = Initialize-InstallAppEntry -TargetElement $panel -AppKey 'WPFInstallLiteral'
        $literal.Parent.ToolTip.Content.Children[1].Text | Should -Be $Apps.WPFInstallLiteral.description
        $literal.Parent.ToolTip.Content.Children.Count | Should -Be 2
        [Windows.Automation.AutomationProperties]::GetHelpText($literal) | Should -Be $Apps.WPFInstallLiteral.description
    }

    It 'provides readable fallback text and omits unavailable package IDs' {
        $Apps.WPFInstallEmpty = @{ content = '示例软件'; description = '  '; winget = 'na'; choco = '' }
        $empty = Initialize-InstallAppEntry -TargetElement $panel -AppKey 'WPFInstallEmpty'
        $empty.Parent.ToolTip.Content.Children[1].Text | Should -Match '^暂无详细介绍'
        $empty.Parent.ToolTip.Content.Children.Count | Should -Be 2
        [Windows.Automation.AutomationProperties]::GetHelpText($empty) | Should -Match '^暂无详细介绍'
    }

    It 'keeps a compact one-line summary while preserving full multiline help' {
        $Apps.WPFInstallMultiline = @{ content = '示例软件'; description = "第一段用途。`r`n第二段说明。`t补充信息。" }
        $multiline = Initialize-InstallAppEntry -TargetElement $panel -AppKey 'WPFInstallMultiline'
        $multiline.Content.Children[1].Text | Should -Be '第一段用途。 第二段说明。 补充信息。'
        $multiline.Content.Children[1].TextWrapping | Should -Be 'NoWrap'
        $multiline.Content.Children[1].TextTrimming | Should -Be 'CharacterEllipsis'
        $multiline.Parent.ToolTip.Content.Children[1].Text | Should -Be $Apps.WPFInstallMultiline.description
        [Windows.Automation.AutomationProperties]::GetHelpText($multiline) | Should -Be $Apps.WPFInstallMultiline.description
    }

    It 'exposes the same full description to keyboard screen-reader users' {
        $peer = [Windows.Automation.Peers.CheckBoxAutomationPeer]::new($checkbox)
        $peer.GetName() | Should -Be $Apps.WPFInstallHover.content
        $peer.GetHelpText() | Should -Be $Apps.WPFInstallHover.description
        $checkbox.IsTabStop | Should -BeTrue
        $checkbox.Focusable | Should -BeTrue
        $selectionEvents.Count | Should -Be 0
    }

    It 'waits briefly and limits tooltip lifetime while allowing movement between rows' {
        [Windows.Controls.ToolTipService]::GetInitialShowDelay($border) | Should -Be 550
        [Windows.Controls.ToolTipService]::GetBetweenShowDelay($border) | Should -Be 150
        [Windows.Controls.ToolTipService]::GetShowDuration($border) | Should -Be 18000
    }

    It 'toggles row padding once per mouse click' {
        $event = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 0, [Windows.Input.MouseButton]::Left)
        $event.RoutedEvent = [Windows.UIElement]::MouseLeftButtonUpEvent
        $border.RaiseEvent($event)
        $checkbox.IsChecked | Should -BeTrue
        $selectionEvents.Count | Should -Be 1
        $selectionEvents[0] | Should -Be 'Add:WPFInstallHover'
        $event = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 1, [Windows.Input.MouseButton]::Left)
        $event.RoutedEvent = [Windows.UIElement]::MouseLeftButtonUpEvent
        $border.RaiseEvent($event)
        $checkbox.IsChecked | Should -BeFalse
        $selectionEvents.Count | Should -Be 2
        $selectionEvents[1] | Should -Be 'Remove:WPFInstallHover'
    }

    It 'toggles the native checkbox only once through its accessible activation' {
        $peer = [Windows.Automation.Peers.CheckBoxAutomationPeer]::new($checkbox)
        $provider = [Windows.Automation.Provider.IToggleProvider]$peer.GetPattern([Windows.Automation.Peers.PatternInterface]::Toggle)
        $provider.Toggle()
        $checkbox.IsChecked | Should -BeTrue
        $selectionEvents.Count | Should -Be 1
        $provider.Toggle()
        $checkbox.IsChecked | Should -BeFalse
        $selectionEvents.Count | Should -Be 2
    }

    It 'keeps mouse releases on the <Target> inside the checkbox without a second row toggle' -ForEach @(
        @{ Target = 'name' }, @{ Target = 'description' }, @{ Target = 'checkbox' }
    ) {
        $peer = [Windows.Automation.Peers.CheckBoxAutomationPeer]::new($checkbox)
        $provider = [Windows.Automation.Provider.IToggleProvider]$peer.GetPattern([Windows.Automation.Peers.PatternInterface]::Toggle)
        $provider.Toggle()
        $element = switch ($Target) {
            'name' { $checkbox.Content.Children[0] }
            'description' { $checkbox.Content.Children[1] }
            default { $checkbox }
        }
        $border.Measure([Windows.Size]::new(400, 400))
        $border.Arrange([Windows.Rect]::new(0, 0, $border.DesiredSize.Width, $border.DesiredSize.Height))
        $border.UpdateLayout()
        $event = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 0, [Windows.Input.MouseButton]::Left)
        $event.RoutedEvent = [Windows.Input.Mouse]::MouseUpEvent
        $element.RaiseEvent($event)
        $event.Handled | Should -BeTrue
        $checkbox.IsChecked | Should -BeTrue
        $selectionEvents.Count | Should -Be 1
    }

    It 'opens the app actions by right-click without changing selection' {
        $event = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 0, [Windows.Input.MouseButton]::Right)
        $event.RoutedEvent = [Windows.UIElement]::MouseRightButtonUpEvent
        $border.RaiseEvent($event)
        Should -Invoke Show-WinUtilAppActions -Times 1 -Exactly -ParameterFilter { $AppKey -eq 'WPFInstallHover' -and $PlacementTarget -eq $border -and -not $Keyboard }
        $event.Handled | Should -BeTrue
        $selectionEvents.Count | Should -Be 0
    }

    It 'opens the app actions with the keyboard menu key without changing selection' {
        $parameters = [Windows.Interop.HwndSourceParameters]::new('WinUtil isolated keyboard test')
        $parameters.WindowStyle = 0
        $source = [Windows.Interop.HwndSource]::new($parameters)
        try {
            $event = [Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice, $source, 0, [Windows.Input.Key]::Apps)
            $event.RoutedEvent = [Windows.UIElement]::PreviewKeyDownEvent
            $checkbox.RaiseEvent($event)
        } finally { $source.Dispose() }
        Should -Invoke Show-WinUtilAppActions -Times 1 -Exactly -ParameterFilter { $AppKey -eq 'WPFInstallHover' -and $PlacementTarget -eq $checkbox -and $Keyboard }
        $event.Handled | Should -BeTrue
        $selectionEvents.Count | Should -Be 0
    }

    It 'toggles once for a complete Space key press and does not open actions' {
        $parameters = [Windows.Interop.HwndSourceParameters]::new('WinUtil isolated checkbox key test')
        $parameters.WindowStyle = 0
        $source = [Windows.Interop.HwndSource]::new($parameters)
        try {
            $down = [Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice, $source, 0, [Windows.Input.Key]::Space)
            $down.RoutedEvent = [Windows.UIElement]::KeyDownEvent
            $checkbox.RaiseEvent($down)
            $up = [Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice, $source, 1, [Windows.Input.Key]::Space)
            $up.RoutedEvent = [Windows.UIElement]::KeyUpEvent
            $checkbox.RaiseEvent($up)
        } finally { $source.Dispose() }
        $checkbox.IsChecked | Should -BeTrue
        $selectionEvents.Count | Should -Be 1
        Should -Invoke Show-WinUtilAppActions -Times 0 -Exactly
    }

    It 'inherits readable theme colors and scaled text at <Theme> <Scale>' -ForEach @(
        @{ Theme = 'Dark'; Scale = 1.0 }, @{ Theme = 'Light'; Scale = 1.0 },
        @{ Theme = 'Dark'; Scale = 1.5 }, @{ Theme = 'Light'; Scale = 1.5 }
    ) {
        Invoke-WinutilThemeChange -theme $Theme
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        $tip.ApplyTemplate() | Out-Null
        $tip.Measure([Windows.Size]::new(800, 1000))
        $tip.Arrange([Windows.Rect]::new(0, 0, $tip.DesiredSize.Width, $tip.DesiredSize.Height))
        $tip.UpdateLayout()
        $tip.Background.ToString() | Should -Be $sync.Form.Resources['ToolTipBackgroundColor'].ToString()
        $tip.Foreground.ToString() | Should -Be $sync.Form.Resources['MainForegroundColor'].ToString()
        $tip.Content.Children[1].FontSize | Should -Be ([double]$sync.configs.themes.shared.FontSize * $Scale)
        $tip.Content.Children[0].FontSize | Should -Be ([double]$sync.configs.themes.shared.HeaderFontSize * $Scale)
        $tip.ActualWidth | Should -BeLessOrEqual ([double]$sync.configs.themes.shared.ToolTipWidth * $Scale)
        $tip.Content.Children[1].TextWrapping | Should -Be 'Wrap'
        $tip.Content.Children[1].TextTrimming | Should -Be 'None'
        $tip.Content.Children[1].ActualHeight | Should -BeGreaterThan $tip.Content.Children[1].FontSize
        $selectionEvents.Count | Should -Be 0
    }
}
