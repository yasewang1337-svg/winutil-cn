BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:root = Split-Path $PSScriptRoot -Parent
    . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:root 'functions/private/Initialize-WinUtilISOControls.ps1'))))
}

Describe 'Windows image download selection' {
    BeforeEach {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'xaml/inputXML.xaml'))
        $xml = [xml]($text -replace 'mc:Ignorable="d"', '' -replace 'x:N', 'N' -replace '^<Win.*', '<Window')
        $reader = [Xml.XmlNodeReader]::new($xml)
        try { $form = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
        $script:sync = @{ Form = $form }
        foreach ($node in $xml.SelectNodes('//*[@Name]')) { $sync[$node.Name] = $form.FindName($node.Name) }
        Mock Start-Process {}
        Initialize-WinUtilISOControls
    }
    AfterEach { $form.Close() }

    It 'opens the selected official page once even after repeated initialization' -ForEach @(
        @{ Index = 0; Uri = 'https://www.microsoft.com/zh-cn/software-download/windows11' },
        @{ Index = 1; Uri = 'https://www.microsoft.com/zh-cn/software-download/windows10ISO' }
    ) {
        Initialize-WinUtilISOControls
        $sync.WPFWindowsISODownloadVersion.SelectedIndex = $Index
        Should -Invoke Start-Process -Times 0 -Exactly
        $sync.WPFWin11ISODownloadLink.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq $Uri }
        $sync.WPFWin11ISOPath.Text | Should -Be '未选择 ISO...'
    }

    It 'shows the Windows 10 support note only for Windows 10 without starting a download' {
        $sync.WPFWindowsISODownloadVersion.SelectedIndex = 1
        $sync.WPFWindowsISODownloadHint.Text | Should -Match '2025 年 10 月 14 日'
        $sync.WPFWindowsISODownloadVersion.SelectedIndex = 0
        $sync.WPFWindowsISODownloadHint.Text | Should -Match 'Windows 11'
        $sync.WPFWindowsISODownloadHint.Text | Should -Not -Match '2025'
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'does not launch an unknown URL when the selection is missing or invalid' {
        $sync.WPFWindowsISODownloadVersion.SelectedIndex = -1
        $sync.WPFWin11ISODownloadLink.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        $item = [Windows.Controls.ComboBoxItem]::new(); $item.Content = 'Unknown'; $item.Tag = 'https://example.invalid/'
        $null = $sync.WPFWindowsISODownloadVersion.Items.Add($item)
        $sync.WPFWindowsISODownloadVersion.SelectedItem = $item
        $sync.WPFWin11ISODownloadLink.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        Should -Invoke Start-Process -Times 0 -Exactly
    }
}

Describe 'Windows 10 installation answer file' {
    It 'keeps installation choices interactive and contains no Windows 11 customization payload' {
        $text = [IO.File]::ReadAllText((Join-Path $script:root 'tools/autounattend-win10.xml'))
        $xml = [xml]$text
        $xml.unattend.settings.component.processorArchitecture | Should -Be 'amd64'
        @($xml.SelectNodes('//*[local-name()="DiskConfiguration" or local-name()="ImageInstall" or local-name()="UserAccounts" or local-name()="AutoLogon" or local-name()="ProductKey"]')).Count | Should -Be 0
        @($xml.SelectNodes('//*[local-name()="RunSynchronous" or local-name()="FirstLogonCommands" or local-name()="Extensions"]')).Count | Should -Be 0
        $text | Should -Not -Match 'BypassTPMCheck|BypassNRO|ViVeTool|TaskbarAl|ConfigureStartPins|https?://'
    }
}
