BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('public/Invoke-WPFTab.ps1', 'public/Invoke-WPFHome.ps1', 'private/Set-WinUtilWindowBounds.ps1', 'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1', 'private/Initialize-WinUtilWindowChrome.ps1', 'private/Set-WinUtilNavigationLayout.ps1', 'private/Test-WinUtilTitleBarSource.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Find-AppsByNameOrDescription { param($SearchString) }
    function Find-TweaksByNameOrDescription { param($SearchString) }
    function Invoke-WPFPresets { param($preset, $checkboxfilterpattern) }
}

Describe 'Chinese navigation and first-use layout' {
    It 'dismisses toolbar popups on outside clicks without pre-toggling their own button' {
        Initialize-WinUtilWindowChrome
        $sync.ThemePopup = [pscustomobject]@{IsOpen=$true;IsMouseOver=$false}
        $sync.ThemeButton = [pscustomobject]@{IsMouseOver=$true}
        $click = [Windows.Input.MouseButtonEventArgs]::new([Windows.Input.InputManager]::Current.PrimaryMouseDevice, 0, [Windows.Input.MouseButton]::Left)
        $click.RoutedEvent = [Windows.UIElement]::PreviewMouseDownEvent
        $form.RaiseEvent($click)
        $sync.ThemePopup.IsOpen | Should -BeTrue
        $sync.ThemeButton.IsMouseOver = $false
        $form.RaiseEvent($click)
        $sync.ThemePopup.IsOpen | Should -BeFalse
    }
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [System.Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form = $form; preferences = @{}; configs = @{ themes = Get-Content (Join-Path $script:root 'config/themes.json') -Raw -Encoding UTF8 | ConvertFrom-Json } }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $script:sync[$node.Name] = $form.FindName($node.Name) }
        Mock Set-Preferences {}
        Mock Find-AppsByNameOrDescription {}
        Mock Find-TweaksByNameOrDescription {}
        Invoke-WinutilThemeChange -theme Dark
        Initialize-WinUtilWindowChrome
    }
    AfterEach { $form.Close() }

    It 'selects translated tabs and filters by stable control identity' {
        $form.FindName('WPFTab1').Header = '任意中文软件页'
        Invoke-WPFTab 'WPFTab1BT'
        $sync.currentTab | Should -Be 'WPFTab1'
        $sync.SearchBar.Visibility | Should -Be 'Visible'
        $sync.WPFTabNav.SelectedItem.Name | Should -Be 'WPFTab1'
        $sync.WPFPageTitle.Text | Should -Be '软件管理'
        $sync.WPFSearchRow.Visibility | Should -Be 'Visible'
        Should -Invoke Find-AppsByNameOrDescription -Times 1 -Exactly
        Invoke-WPFTab 'WPFTab6BT'
        $sync.WPFTabNav.SelectedItem.Name | Should -Be 'WPFTab6'
        $sync.SearchBar.Visibility | Should -Be 'Collapsed'
        $sync.WPFTab1BT.IsChecked | Should -BeFalse
        $sync.WPFPageTitle.Text | Should -Be '首页'
        $sync.WPFSearchRow.Visibility | Should -Be 'Collapsed'
    }

    It 'does not navigate through a disabled tab' {
        Invoke-WPFTab 'WPFTab6BT'
        Set-WinUtilNavigationLayout -AvailableWidth 800
        $sync.WPFTab1BT.IsEnabled = $false
        Invoke-WPFTab 'WPFTab1BT'
        $sync.currentTab | Should -Be 'WPFTab6'
    }

    It 'fits a laptop work area expressed in device-independent pixels' {
        Set-WinUtilWindowBounds -Window $form -WorkArea ([Windows.Rect]::new(0, 0, 910, 480))
        $form.Width | Should -BeLessOrEqual 910
        $form.Height | Should -BeLessOrEqual 480
        $form.MinHeight | Should -BeLessOrEqual 480
    }

    It 'measures the home page at 800 pixels and <Scale> font scaling' -ForEach @(@{Scale=1.0}, @{Scale=1.5}) {
        Invoke-WinUtilFontScaling -ScaleFactor $Scale
        Invoke-WPFTab 'WPFTab6BT'
        $rootGrid = $form.Content
        $rootGrid.Measure([Windows.Size]::new(800, 600))
        $rootGrid.Arrange([Windows.Rect]::new(0, 0, 800, 600))
        $rootGrid.UpdateLayout()
        foreach ($name in @('WPFHomeInstall','WPFHomeManage','WPFHomeSettings','WPFHomeImport','WPFHomeHistory','WPFCloseButton')) {
            $button = $form.FindName($name)
            $point = $button.TranslatePoint([Windows.Point]::new(0, 0), $rootGrid)
            $button.ActualWidth | Should -BeGreaterThan 0 -Because $name
            ($point.X + $button.ActualWidth) | Should -BeLessOrEqual 801 -Because $name
        }
    }
    It 'collapses navigation labels at narrow widths without losing accessible page names or selection' {
        Invoke-WPFTab 'WPFTab4BT'
        Set-WinUtilNavigationLayout -AvailableWidth 800
        $sync.WPFMainGrid.ColumnDefinitions[0].Width.Value | Should -Be 56
        foreach ($number in 1..6) {
            $form.FindName("WPFTab${number}Label").Visibility | Should -Be 'Collapsed'
            [Windows.Automation.AutomationProperties]::GetName($sync["WPFTab${number}BT"]) | Should -Not -BeNullOrEmpty
            $sync["WPFTab${number}BT"].ToolTip | Should -Not -BeNullOrEmpty
        }
        $sync.WPFTab4BT.IsChecked | Should -BeTrue
        Set-WinUtilNavigationLayout -AvailableWidth 1280
        $sync.WPFMainGrid.ColumnDefinitions[0].Width.Value | Should -Be 184
        $form.FindName('WPFTab4Label').Visibility | Should -Be 'Visible'
        $sync.WPFTab4BT.IsChecked | Should -BeTrue
    }
    It 'initializes the actual production title bar once and keeps its theme resources live' {
        Initialize-WinUtilWindowChrome
        $sync.NavLogoPanel.Children.Count | Should -Be 1
        $title = $sync.NavLogoPanel.Children[0]
        $title.Text | Should -Be 'WinUtil CN'
        $title.Effect | Should -BeNullOrEmpty
        Invoke-WinutilThemeChange -theme Light
        $title.Foreground.Color | Should -Be $form.Resources.MainForegroundColor.Color
    }
    It 'accepts title and empty title-bar hits for window gestures while excluding controls and page content' {
        Invoke-WPFTab 'WPFTab6BT'
        $grid = $form.Content
        $grid.Measure([Windows.Size]::new(1280,800)); $grid.Arrange([Windows.Rect]::new(0,0,1280,800)); $grid.UpdateLayout()
        foreach ($x in @(20,150,350,750)) {
            $hit = [Windows.Media.VisualTreeHelper]::HitTest($grid,[Windows.Point]::new($x,22))
            Test-WinUtilTitleBarSource -Source $hit.VisualHit | Should -BeTrue
        }
        Test-WinUtilTitleBarSource -Source $sync.ThemeButton | Should -BeFalse
        Test-WinUtilTitleBarSource -Source $sync.WPFCloseButton | Should -BeFalse
        Test-WinUtilTitleBarSource -Source $sync.WPFHomeInstall | Should -BeFalse
        Test-WinUtilTitleBarSource -Source $sync.WPFPageTitle | Should -BeFalse
    }
}
