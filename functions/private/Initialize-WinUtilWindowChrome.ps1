function Initialize-WinUtilWindowChrome {
    <# .SYNOPSIS Creates the same restrained title bar in the application and layout previews. #>
    $panel = $sync.Form.FindName('NavLogoPanel')
    if ($panel) {
        $panel.Children.Clear()
        $title = [Windows.Controls.TextBlock]::new()
        $title.Text = 'WinUtil CN'
        $title.FontWeight = 'SemiBold'
        $title.VerticalAlignment = 'Center'
        $title.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
        $title.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'ButtonFontSize')
        $title.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
        $null = $panel.Children.Add($title)
    }
    if (-not $sync.NavigationResizeRegistered) {
        $sync.Form.Add_SizeChanged({ Set-WinUtilNavigationLayout })
        $sync.NavigationResizeRegistered = $true
    }
    if (-not $sync.TitleBarPointerRegistered) {
        # Keep toggle-button behavior deterministic while dismissing toolbar
        # popups on clicks elsewhere, without turning content into a drag area.
        $sync.Form.Add_PreviewMouseDown({
            foreach ($name in @('Settings', 'Theme', 'FontScaling')) {
                $popup = $sync["${name}Popup"]
                $button = $sync["${name}Button"]
                if ($popup -and $popup.IsOpen -and -not $popup.IsMouseOver -and
                    -not ($button -and $button.IsMouseOver)) {
                    $popup.IsOpen = $false
                }
            }
        })
        $titleBar = $sync.Form.FindName('GridBesideNavDockPanel')
        if ($titleBar) {
            $titleBar.Add_MouseLeftButtonDown({
                param($sender, $eventArgs)
                if (-not (Test-WinUtilTitleBarSource -Source $eventArgs.OriginalSource)) { return }
                Invoke-WPFPopup -Action Hide -Popups @('Settings', 'Theme', 'FontScaling')
                if ($eventArgs.ClickCount -eq 2) {
                    $sync.Form.WindowState = if ($sync.Form.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' }
                } elseif ($eventArgs.LeftButton -eq 'Pressed') {
                    $sync.Form.DragMove()
                }
                $eventArgs.Handled = $true
            })
            $sync.TitleBarPointerRegistered = $true
        }
    }
    Set-WinUtilNavigationLayout
}
