BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('public/Invoke-WPFTab.ps1','private/Invoke-WinutilThemeChange.ps1','private/Invoke-WinUtilFontScaling.ps1','private/Initialize-WinUtilWindowChrome.ps1','private/Set-WinUtilNavigationLayout.ps1','private/Test-WinUtilTitleBarSource.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Get-UpdateLayoutTextBlocks($Element) {
        if ($Element -is [Windows.Controls.TextBlock]) { $Element }
        for ($index = 0; $index -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($Element); $index++) {
            Get-UpdateLayoutTextBlocks ([Windows.Media.VisualTreeHelper]::GetChild($Element,$index))
        }
    }
    function Get-UpdateLayoutNaturalTextSize($Text, $Width) {
        # Measure a fresh copy unconstrained vertically; the old fixed-height
        # button constrained its own TextBlock.DesiredSize and hid the clipping.
        $probe = [Windows.Controls.TextBlock]::new()
        $probe.Text = $Text.Text
        $probe.FontFamily = $Text.FontFamily; $probe.FontSize = $Text.FontSize
        $probe.FontWeight = $Text.FontWeight; $probe.FontStyle = $Text.FontStyle
        $probe.TextWrapping = $Text.TextWrapping
        $probe.Measure([Windows.Size]::new($Width,[double]::PositiveInfinity))
        return $probe.DesiredSize
    }
}
Describe 'Windows Update settings remain readable and reachable' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"','' -replace 'x:N','N' -replace '^<Win.*','<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form=$form; preferences=@{}; configs=@{themes=([IO.File]::ReadAllText((Join-Path $script:root 'config/themes.json'))|ConvertFrom-Json)} }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name]=$form.FindName($node.Name) }
    }
    AfterEach { $form.Close() }

    It 'does not clip titles, descriptions or action text at <Width> pixels / <Scale> scale in <Theme>' -ForEach @(
        @{Width=1280;Scale=1.0;Theme='Light'}, @{Width=1280;Scale=1.5;Theme='Light'},
        @{Width=800;Scale=1.0;Theme='Light'}, @{Width=800;Scale=1.5;Theme='Light'},
        @{Width=1280;Scale=1.0;Theme='Dark'}, @{Width=1280;Scale=1.5;Theme='Dark'},
        @{Width=800;Scale=1.0;Theme='Dark'}, @{Width=800;Scale=1.5;Theme='Dark'}
    ) {
        Invoke-WinutilThemeChange -theme $Theme
        Initialize-WinUtilWindowChrome
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        Invoke-WPFTab 'WPFTab4BT'
        Set-WinUtilNavigationLayout -AvailableWidth $Width
        $height = if ($Width -eq 800) { 600 } else { 800 }
        $grid = $form.Content
        $grid.Measure([Windows.Size]::new($Width,$height)); $grid.Arrange([Windows.Rect]::new(0,0,$Width,$height)); $grid.UpdateLayout()
        $scroll = $sync.WPFUpdatesScroll
        $scroll.HorizontalScrollBarVisibility | Should -Be 'Disabled'
        $scroll.ExtentWidth | Should -BeLessOrEqual ($scroll.ViewportWidth + 1)
        foreach ($label in @(Get-UpdateLayoutTextBlocks $sync.WPFUpdatesSettingsList)) {
            if ([string]::IsNullOrWhiteSpace($label.Text)) { continue }
            $natural = Get-UpdateLayoutNaturalTextSize $label $label.ActualWidth
            $label.ActualHeight | Should -BeGreaterOrEqual ($natural.Height - 1) -Because $label.Text
        }
        foreach ($name in @('WPFUpdatesdefault','WPFUpdatessecurity','WPFUpdatesdisable')) {
            $button = $form.FindName($name)
            $button.ActualWidth | Should -BeGreaterThan 0
            $label = @(Get-UpdateLayoutTextBlocks $button)[0]
            $natural = Get-UpdateLayoutNaturalTextSize $label $label.ActualWidth
            $button.ActualHeight | Should -BeGreaterOrEqual ($natural.Height + $button.Padding.Top + $button.Padding.Bottom + $button.BorderThickness.Top + $button.BorderThickness.Bottom - 1)
            $point = $label.TranslatePoint([Windows.Point]::new(0,0),$button)
            ($point.X + $label.ActualWidth) | Should -BeLessOrEqual ($button.ActualWidth + 1)
            ($point.Y + $label.ActualHeight) | Should -BeLessOrEqual ($button.ActualHeight + 1)
            # Each action must be fully reachable by scrolling, including the last one.
            $offset = $button.TranslatePoint([Windows.Point]::new(0,0),$sync.WPFUpdatesSettingsList).Y
            $scroll.ScrollToVerticalOffset([math]::Max(0,$offset - 8)); $grid.UpdateLayout()
            $visiblePoint = $button.TranslatePoint([Windows.Point]::new(0,0),$scroll)
            $visiblePoint.Y | Should -BeGreaterOrEqual -1
            ($visiblePoint.Y + $button.ActualHeight) | Should -BeLessOrEqual ($scroll.ActualHeight + 1)
            ($visiblePoint.X + $button.ActualWidth) | Should -BeLessOrEqual ($scroll.ActualWidth + 1)
        }
    }
}
