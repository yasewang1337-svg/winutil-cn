function Show-WinUtilTweakDialog {
    <# .SYNOPSIS A scrollable settings plan/result dialog, available in both UI and worker runspaces. #>
    param([string]$Title, [string]$Message, [switch]$Confirm, [switch]$CreateOnly)
    $dialog = New-Object Windows.Window
    $dialog.Title = $Title
    if ($sync.Form -is [Windows.Window] -and $sync.Form.IsVisible) {
        $dialog.Owner = $sync.Form
        $dialog.WindowStartupLocation = 'CenterOwner'
    } else { $dialog.WindowStartupLocation = 'CenterScreen' }
    $dialog.Width = [Math]::Min(760, [Windows.SystemParameters]::WorkArea.Width * 0.9)
    $dialog.Height = [Math]::Min(650, [Windows.SystemParameters]::WorkArea.Height * 0.85)
    $dialog.FontFamily = 'Microsoft YaHei UI'
    $dialog.FontSize = 15
    $dialog.Background = [Windows.Media.Brushes]::White
    $dialog.Foreground = [Windows.Media.Brushes]::Black
    $dialog.Tag = $false
    if ($sync.Form -is [Windows.Window]) {
        $background = $sync.Form.TryFindResource('MainBackgroundColor')
        $foreground = $sync.Form.TryFindResource('MainForegroundColor')
        $fontSize = $sync.Form.TryFindResource('FontSize')
        $fontFamily = $sync.Form.TryFindResource('FontFamily')
        if ($background) { $dialog.Background = $background }
        if ($foreground) { $dialog.Foreground = $foreground }
        if ($fontSize) { $dialog.FontSize = [Math]::Max(14, [double]$fontSize) }
        if ($fontFamily) { $dialog.FontFamily = $fontFamily }
    }
    $panel = New-Object Windows.Controls.DockPanel
    $panel.Margin = '20'
    $buttons = New-Object Windows.Controls.StackPanel
    $buttons.Orientation = 'Horizontal'
    $buttons.HorizontalAlignment = 'Right'
    $buttons.Margin = '0,15,0,0'
    [Windows.Controls.DockPanel]::SetDock($buttons, 'Bottom')
    $close = New-Object Windows.Controls.Button
    $close.Content = '关闭'
    if ($Confirm) { $close.Content = '取消' }
    $close.MinWidth = 90
    $close.Padding = '12,7'
    $close.IsCancel = $true
    $close.Background = $dialog.Background
    $close.Foreground = $dialog.Foreground
    $close.Add_Click({ $dialog.Tag = $false; $dialog.Close() }.GetNewClosure())
    $buttons.Children.Add($close) | Out-Null
    if ($Confirm) {
        $accept = New-Object Windows.Controls.Button
        $accept.Content = '确认执行'
        $accept.MinWidth = 110
        $accept.Padding = '12,7'
        $accept.Margin = '12,0,0,0'
        $accept.Background = $dialog.Background
        $accept.Foreground = $dialog.Foreground
        $accept.Add_Click({ $dialog.Tag = $true; $dialog.Close() }.GetNewClosure())
        $buttons.Children.Add($accept) | Out-Null
    }
    $panel.Children.Add($buttons) | Out-Null
    $text = New-Object Windows.Controls.TextBox
    $text.Text = $Message
    $text.IsReadOnly = $true
    $text.TextWrapping = 'Wrap'
    $text.VerticalScrollBarVisibility = 'Auto'
    $text.HorizontalScrollBarVisibility = 'Disabled'
    $text.Background = $dialog.Background
    $text.Foreground = $dialog.Foreground
    $text.BorderThickness = 0
    $text.Padding = '5'
    $panel.Children.Add($text) | Out-Null
    $dialog.Content = $panel
    if ($CreateOnly) { return $dialog }
    $dialog.ShowDialog() | Out-Null
    return $dialog.Tag -eq $true
}
