function Show-WinUtilPackageDialog {
    <# Scrollable, keyboard-accessible review/results. Call on the UI thread. #>
    param(
        [string]$Title, [string]$Description, [string]$Details,
        [string]$PrimaryLabel = '开始执行', [string]$CloseLabel = '取消', [string]$LogDirectory,
        [switch]$CreateOnly
    )
    $dialog = New-Object Windows.Window
    $dialog.Title = $Title
    if ($sync.form -is [Windows.Window] -and $sync.form.IsVisible) {
        $dialog.Owner = $sync.form; $dialog.WindowStartupLocation = 'CenterOwner'
    } else { $dialog.WindowStartupLocation = 'CenterScreen' }
    $dialog.Width = [Math]::Min(820, [System.Windows.SystemParameters]::WorkArea.Width - 32)
    $dialog.Height = [Math]::Min(610, [System.Windows.SystemParameters]::WorkArea.Height - 32)
    $dialog.MaxHeight = [System.Windows.SystemParameters]::WorkArea.Height - 32
    $dialog.MinWidth = 360; $dialog.MinHeight = 260; $dialog.FontSize = 15
    $dialog.FontFamily = 'Microsoft YaHei UI'; $dialog.Tag = 'Close'
    $dialog.Background = [Windows.Media.Brushes]::White
    $dialog.Foreground = [Windows.Media.Brushes]::Black
    if ($sync.form -is [Windows.Window]) {
        $background = $sync.form.TryFindResource('MainBackgroundColor')
        $foreground = $sync.form.TryFindResource('MainForegroundColor')
        $fontSize = $sync.form.TryFindResource('FontSize')
        $fontFamily = $sync.form.TryFindResource('FontFamily')
        if ($background) { $dialog.Background = $background }
        if ($foreground) { $dialog.Foreground = $foreground }
        if ($fontSize) { $dialog.FontSize = [Math]::Max(14, [double]$fontSize) }
        if ($fontFamily) { $dialog.FontFamily = $fontFamily }
    }
    $layout = New-Object Windows.Controls.DockPanel
    $layout.Margin = 20; $layout.Background = $dialog.Background; $dialog.Content = $layout
    $intro = New-Object Windows.Controls.TextBlock
    $intro.Text = $Description; $intro.TextWrapping = 'Wrap'; $intro.Margin = '0,0,0,14'
    $introScroll = New-Object Windows.Controls.ScrollViewer
    $introScroll.Content = $intro; $introScroll.VerticalScrollBarVisibility = 'Auto'
    $introScroll.HorizontalScrollBarVisibility = 'Disabled'; $introScroll.MaxHeight = $dialog.Height * 0.28
    [Windows.Controls.DockPanel]::SetDock($introScroll, 'Top')
    $null = $layout.Children.Add($introScroll)
    $dialog.Add_SizeChanged({ $introScroll.MaxHeight = [Math]::Max(48, $dialog.ActualHeight * 0.28) }.GetNewClosure())
    $buttons = New-Object Windows.Controls.WrapPanel
    $buttons.Orientation = 'Horizontal'; $buttons.HorizontalAlignment = 'Right'; $buttons.Margin = '0,14,0,0'
    [Windows.Controls.DockPanel]::SetDock($buttons, 'Bottom')
    $null = $layout.Children.Add($buttons)
    if ($LogDirectory -and (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
        $logButton = New-Object Windows.Controls.Button
        $logButton.Content = '打开日志文件夹'; $logButton.Padding = '12,8'; $logButton.Margin = '0,0,8,0'
        $logButton.Background = $dialog.Background; $logButton.Foreground = $dialog.Foreground
        $logButton.Add_Click({
            try { Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $LogDirectory) -ErrorAction Stop | Out-Null }
            catch { $null = [Windows.MessageBox]::Show("无法打开日志文件夹：$LogDirectory", 'WinUtil CN') }
        }.GetNewClosure())
        $null = $buttons.Children.Add($logButton)
    }
    $close = New-Object Windows.Controls.Button
    $close.Content = $CloseLabel; $close.Padding = '16,8'; $close.Margin = '0,0,8,0'; $close.IsCancel = $true
    $close.Background = $dialog.Background; $close.Foreground = $dialog.Foreground
    $close.Add_Click({ $dialog.Close() }.GetNewClosure())
    $null = $buttons.Children.Add($close)
    if ($PrimaryLabel) {
        $primary = New-Object Windows.Controls.Button
        $primary.Content = $PrimaryLabel; $primary.Padding = '16,8'
        $primary.Background = $dialog.Background; $primary.Foreground = $dialog.Foreground
        $primary.Add_Click({ $dialog.Tag = 'Primary'; $dialog.Close() }.GetNewClosure())
        $null = $buttons.Children.Add($primary)
    }
    $textBox = New-Object Windows.Controls.TextBox
    $textBox.Text = $Details; $textBox.IsReadOnly = $true; $textBox.TextWrapping = 'Wrap'
    $textBox.Background = $dialog.Background; $textBox.Foreground = $dialog.Foreground
    $textBox.VerticalScrollBarVisibility = 'Auto'; $textBox.Padding = 12
    $null = $layout.Children.Add($textBox)
    if ($CreateOnly) { return $dialog }
    $null = $dialog.ShowDialog()
    return [string]$dialog.Tag
}
