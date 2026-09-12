BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('public/Invoke-WPFTab.ps1', 'public/Invoke-WPFHome.ps1', 'private/Set-WinUtilWindowBounds.ps1', 'private/Invoke-WinutilThemeChange.ps1', 'private/Invoke-WinUtilFontScaling.ps1')) {
        . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root "functions/$file"))))
    }
    function Set-Preferences { param([switch]$save) }
    function Find-AppsByNameOrDescription { param($SearchString) }
    function Find-TweaksByNameOrDescription { param($SearchString) }
    function Invoke-WPFPresets { param($preset, $checkboxfilterpattern) }
}

Describe 'Chinese navigation and first-use layout' {
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
    }
    AfterEach { $form.Close() }

    It 'selects translated tabs and filters by stable control identity' {
        $form.FindName('WPFTab1').Header = '任意中文软件页'
        Invoke-WPFTab 'WPFTab1BT'
        $sync.currentTab | Should -Be 'WPFTab1'
        $sync.SearchBar.Visibility | Should -Be 'Visible'
        $sync.WPFTabNav.SelectedItem.Name | Should -Be 'WPFTab1'
        Should -Invoke Find-AppsByNameOrDescription -Times 1 -Exactly
        Invoke-WPFTab 'WPFTab6BT'
        $sync.WPFTabNav.SelectedItem.Name | Should -Be 'WPFTab6'
        $sync.SearchBar.Visibility | Should -Be 'Collapsed'
        $sync.WPFTab1BT.IsChecked | Should -BeFalse
    }

    It 'does not navigate through a disabled tab' {
        Invoke-WPFTab 'WPFTab6BT'
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
}
