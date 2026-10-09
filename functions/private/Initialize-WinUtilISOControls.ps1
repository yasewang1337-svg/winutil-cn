function Initialize-WinUtilISOControls {
    # Choosing the download page does not choose or modify a local image.
    if ($sync.WindowsISOControlsInitialized) { return }
    if (-not $sync.WPFWindowsISODownloadVersion -or -not $sync.WPFWin11ISODownloadLink) { return }

    $sync.WPFWindowsISODownloadVersion.Add_SelectionChanged({
        if ($sync.WPFWindowsISODownloadVersion.SelectedItem.Tag -eq 'Windows10') {
            $sync.WPFWindowsISODownloadHint.Text = '选择 Windows 10 22H2 的 64 位 ISO。网页也可能提供媒体创建工具；普通支持已于 2025 年 10 月 14 日结束。'
        } else {
            $sync.WPFWindowsISODownloadHint.Text = '在微软网页选择语言和 Windows 11 的 64 位（x64）ISO。'
        }
    })
    $sync.WPFWin11ISODownloadLink.Add_Click({
        $uri = switch ([string]$sync.WPFWindowsISODownloadVersion.SelectedItem.Tag) {
            'Windows10' { 'https://www.microsoft.com/zh-cn/software-download/windows10ISO' }
            'Windows11' { 'https://www.microsoft.com/zh-cn/software-download/windows11' }
        }
        if ($uri) { Start-Process -FilePath $uri }
    })
    $sync.WindowsISOControlsInitialized = $true
}
