BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @(
        'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1',
        'private/Initialize-InstallCategoryAppList.ps1', 'private/Initialize-InstallAppEntry.ps1',
        'public/Invoke-WPFToggleAllCategories.ps1', 'public/Invoke-WPFButton.ps1'
    )) { . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file")))) }
    function Set-Preferences { param([switch]$save) }
    function Set-WinUtilProgressBar { param($label, $percent) }
    function Get-UiContrastRatio($First, $Second) {
        $values = foreach ($color in @($First, $Second)) {
            $channels = foreach ($value in @($color.R, $color.G, $color.B)) {
                $channel = $value / 255.0
                if ($channel -le 0.04045) { $channel / 12.92 } else { [math]::Pow(($channel + 0.055) / 1.055, 2.4) }
            }
            $channels[0] * 0.2126 + $channels[1] * 0.7152 + $channels[2] * 0.0722
        }
        ([math]::Max($values[0], $values[1]) + 0.05) / ([math]::Min($values[0], $values[1]) + 0.05)
    }
}
Describe 'Readable themes and predictable interface state' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form = $form; preferences = @{}; configs = @{
            themes = [IO.File]::ReadAllText((Join-Path $script:root 'config/themes.json')) | ConvertFrom-Json
            feature = @{}
        } }
        $sync.WPFToggleFOSSHighlight = [Windows.Controls.CheckBox]::new()
        $sync.WPFToggleFOSSHighlight.IsChecked = $true
        Invoke-WinutilThemeChange -theme Dark
    }
    AfterEach { $form.Close() }

    It 'keeps normal, secondary and FOSS text readable on <Theme> list states' -ForEach @(@{Theme='Dark'}, @{Theme='Light'}) {
        Invoke-WinutilThemeChange -theme $Theme
        foreach ($background in @('MainBackgroundColor','PanelBackgroundColor','AppInstallHighlightedColor','AppInstallSelectedColor')) {
            foreach ($foreground in @('MainForegroundColor','SecondaryForegroundColor','FOSSHighlightColor')) {
                $ratio = Get-UiContrastRatio $form.Resources[$foreground].Color $form.Resources[$background].Color
                $ratio | Should -BeGreaterOrEqual 4.5 -Because "$foreground on $background in $Theme"
            }
        }
        foreach ($background in @('ButtonPrimaryColor','ButtonPrimaryHoverColor','ButtonPrimaryPressedColor')) {
            (Get-UiContrastRatio $form.Resources.PrimaryButtonForegroundColor.Color $form.Resources[$background].Color) | Should -BeGreaterOrEqual 4.5
        }
    }
    It 'keeps the FOSS switch effective across theme changes and repeated toggling' {
        Invoke-WPFButton -Button WPFToggleFOSSHighlight
        $form.Resources.FOSSColor.Color | Should -Be $form.Resources.FOSSHighlightColor.Color
        Invoke-WinutilThemeChange -theme Light
        $form.Resources.FOSSColor.Color | Should -Be $form.Resources.FOSSHighlightColor.Color
        $sync.WPFToggleFOSSHighlight.IsChecked = $false
        Invoke-WPFButton -Button WPFToggleFOSSHighlight
        $form.Resources.FOSSColor.Color | Should -Be $form.Resources.MainForegroundColor.Color
        Invoke-WinutilThemeChange -theme Dark
        $sync.WPFToggleFOSSHighlight.IsChecked | Should -BeFalse
        $form.Resources.FOSSColor.Color | Should -Be $form.Resources.MainForegroundColor.Color
        $sync.WPFToggleFOSSHighlight.IsChecked = $true
        Invoke-WPFButton -Button WPFToggleFOSSHighlight
        $form.Resources.FOSSColor.Color | Should -Be $form.Resources.FOSSHighlightColor.Color
    }
    It 'preserves applied scaling on a theme change without applying an unconfirmed slider value' {
        $sync.FontScalingValue = $form.FindName('FontScalingValue')
        Invoke-WinUtilFontScaling -ScaleFactor 1.5
        $form.FindName('FontScalingSlider').Value = 2.0
        Invoke-WinutilThemeChange -theme Light
        $form.Resources.FontSize | Should -Be 21
        $form.Resources.AppEntryFontSize | Should -Be 21
        $form.Resources.AppEntryDescriptionFontSize | Should -Be 18
        $form.Resources.PageTitleFontSize | Should -Be 36
        $sync.FontScalingValue.Text | Should -Be '150%'
        Invoke-WinutilThemeChange -theme Dark
        $form.Resources.FontSize | Should -Be 21
    }
    It 'makes category collapse available through the native keyboard-invokable button action' {
        $sync.ItemsControl = [Windows.Controls.ItemsControl]::new()
        $sync.configs.applicationsHashtable = @{ WPFInstallFixture = @{Content='Fixture';Description='Fixture details';Category='Tools'} }
        Initialize-InstallCategoryAppList -TargetElement $sync.ItemsControl -Apps $sync.configs.applicationsHashtable
        $category = $sync.ItemsControl.Items[0]
        $button = $category.Children[0]
        $button | Should -BeOfType ([Windows.Controls.Button])
        $button.Focusable | Should -BeTrue
        $button.IsTabStop | Should -BeTrue
        $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        $category.Children[1].Visibility | Should -Be 'Collapsed'
        $button.Content | Should -Be '+ Tools'
        Invoke-WPFToggleAllCategories -Action Expand
        $category.Children[1].Visibility | Should -Be 'Visible'
        $button.Content | Should -Be '- Tools'
        Invoke-WPFToggleAllCategories -Action Collapse
        $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        $category.Children[1].Visibility | Should -Be 'Visible'
    }
    It 'shows the search hint only for an empty visible search field' {
        $search = $form.FindName('SearchBar')
        $hint = $search.Parent.Children | Where-Object { $_ -is [Windows.Controls.TextBlock] -and $_.Text -eq '搜索名称或用途' }
        $hint.Visibility | Should -Be 'Visible'
        $hint.IsHitTestVisible | Should -BeFalse
        $search.Text = 'editor'
        $hint.Visibility | Should -Be 'Collapsed'
        $search.Text = ''
        $search.Visibility = 'Collapsed'
        $hint.Visibility | Should -Be 'Collapsed'
    }
    It 'renders dropdown chrome and leaf text with live theme resources instead of the system menu palette' {
        $menu = [Windows.Controls.Menu]::new()
        $heading = [Windows.Controls.MenuItem]::new(); $heading.Header = 'Commands'
        $item = [Windows.Controls.MenuItem]::new(); $item.Header = 'Command item'
        $null = $heading.Items.Add($item); $null = $menu.Items.Add($heading)
        $null = $form.FindName('NavLogoPanel').Children.Add($menu)
        $form.Content.Measure([Windows.Size]::new(1280,800)); $form.Content.Arrange([Windows.Rect]::new(0,0,1280,800)); $form.Content.UpdateLayout()
        $null = $heading.ApplyTemplate()
        $popup = $heading.Template.FindName('PART_Popup',$heading)
        foreach ($theme in @('Dark','Light')) {
            Invoke-WinutilThemeChange -theme $theme
            $surface = $popup.Child
            $surface.Measure([Windows.Size]::new(340,440)); $surface.Arrange([Windows.Rect]::new(0,0,340,$surface.DesiredSize.Height)); $surface.UpdateLayout()
            $surface.Background.Color | Should -Be $form.Resources.PanelBackgroundColor.Color
            $item.Foreground.Color | Should -Be $form.Resources.MainForegroundColor.Color
            (Get-UiContrastRatio $item.Foreground.Color $surface.Background.Color) | Should -BeGreaterOrEqual 4.5
            $item.ActualHeight | Should -BeGreaterThan 0
        }
    }
    It 'keeps primary home-action content inside its button at <Scale> scaling' -ForEach @(@{Scale=1.0}, @{Scale=1.5}) {
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        $form.FindName('WPFTab6').IsSelected = $true
        $grid = $form.Content
        $grid.Measure([Windows.Size]::new(800,600)); $grid.Arrange([Windows.Rect]::new(0,0,800,600)); $grid.UpdateLayout()
        foreach ($name in @('WPFHomeInstall','WPFHomeManage','WPFHomeSettings')) {
            $button = $form.FindName($name)
            $presenter = [Windows.Media.VisualTreeHelper]::GetChild([Windows.Media.VisualTreeHelper]::GetChild($button,0),0)
            $point = $presenter.TranslatePoint([Windows.Point]::new(0,0),$button)
            ($point.X + $presenter.ActualWidth) | Should -BeLessOrEqual ($button.ActualWidth + 1)
            ($point.Y + $presenter.ActualHeight) | Should -BeLessOrEqual ($button.ActualHeight + 1)
            ($button.TranslatePoint([Windows.Point]::new(0,0),$grid).X + $button.ActualWidth) | Should -BeLessOrEqual 801
        }
    }
}
