function Initialize-WinUtilAppActions {
    <# Accessible per-app actions. Opening the menu never executes a package operation. #>
    $popup = [Windows.Controls.Primitives.Popup]::new()
    $popup.StaysOpen = $false
    $popup.Placement = 'Bottom'
    $popup.AllowsTransparency = $true
    if ($sync.Form) { $null = $popup.Resources.MergedDictionaries.Add($sync.Form.Resources) }
    $sync.appPopup = $popup
    $border = [Windows.Controls.Border]::new()
    $border.Width = 300; $border.Padding = 6; $border.CornerRadius = 6; $border.BorderThickness = 1
    $border.Focusable = $true
    $border.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'PanelBackgroundColor')
    $border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BorderColor')
    $border.SetResourceReference([Windows.Documents.TextElement]::FontFamilyProperty, 'FontFamily')
    $border.SetResourceReference([Windows.Documents.TextElement]::FontSizeProperty, 'ButtonFontSize')
    [Windows.Input.KeyboardNavigation]::SetTabNavigation($border, 'Cycle')
    $popup.Child = $border
    $panel = [Windows.Controls.StackPanel]::new()
    $border.Child = $panel
    $heading = [Windows.Controls.TextBlock]::new()
    $heading.TextWrapping = 'Wrap'; $heading.Margin = '10,6,10,10'; $heading.FontWeight = 'SemiBold'
    $heading.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
    $sync.AppActionsHeading = $heading
    $null = $panel.Children.Add($heading)
    $sync.AppActionButtons = @{}
    foreach ($definition in @(
        @{ Id = 'Install'; Text = '安装 / 升级此软件'; Hint = '先核对这一个软件的操作计划，再确认执行。' },
        @{ Id = 'Uninstall'; Text = '卸载此软件'; Hint = '先核对卸载计划，再确认执行。' },
        @{ Id = 'Info'; Text = '访问软件官网'; Hint = '在默认浏览器中打开目录记录的官网。' }
    )) {
        $button = [Windows.Controls.Button]::new()
        $button.Tag = $definition.Id; $button.Content = $definition.Text; $button.ToolTip = $definition.Hint
        $button.SetResourceReference([Windows.Controls.Control]::StyleProperty, 'HoverButtonStyle')
        $button.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'ButtonFontSize')
        $button.Width = [double]::NaN; $button.Height = [double]::NaN
        $button.Padding = '10,8'; $button.Margin = '0,2,0,2'; $button.MinHeight = 36
        $button.HorizontalContentAlignment = 'Left'
        [Windows.Automation.AutomationProperties]::SetName($button, $definition.Text)
        $button.Add_Click({
            $key = [string]$sync.appPopupSelectedApp
            $app = $sync.configs.applicationsHashtable[$key]
            $sync.appPopup.IsOpen = $false
            if (-not $app) { return }
            switch ([string]$this.Tag) {
                'Install' {
                    if ($sync.ProcessRunning -or $PARAM_OFFLINE -or ($sync.WPFInstall -and -not $sync.WPFInstall.IsEnabled)) { return }
                    Invoke-WPFInstall -PackagesToInstall $app
                }
                'Uninstall' {
                    if ($sync.ProcessRunning -or $PARAM_OFFLINE -or ($sync.WPFUninstall -and -not $sync.WPFUninstall.IsEnabled)) { return }
                    Invoke-WPFUnInstall -PackagesToUninstall $app
                }
                'Info' {
                    if ($PARAM_OFFLINE) { return }
                    $address = $null
                    if ([Uri]::TryCreate([string]$app.link, [UriKind]::Absolute, [ref]$address) -and $address.Scheme -in @('https', 'http')) {
                        try { Start-Process -FilePath $address.AbsoluteUri -ErrorAction Stop | Out-Null }
                        catch { Show-WinUtilTweakDialog -Title '无法打开官网' -Message '默认浏览器未能打开网站。请检查默认浏览器设置后再试。' | Out-Null }
                    }
                }
            }
        })
        $sync.AppActionButtons[$definition.Id] = $button
        $null = $panel.Children.Add($button)
    }
    $border.Add_PreviewKeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Key -eq 'Escape') {
            $sync.appPopup.IsOpen = $false
            if ($sync[$sync.appPopupSelectedApp]) { $null = $sync[$sync.appPopupSelectedApp].Focus() }
            $eventArgs.Handled = $true
        }
    })
    $popup.Add_Opened({
        $scale = if ($sync.UiScaleFactor -gt 0) { $sync.UiScaleFactor } else { 1.0 }
        $available = if ($sync.Form -and $sync.Form.ActualWidth -gt 32) { $sync.Form.ActualWidth - 32 } else { 600 }
        $sync.appPopup.Child.Width = [Math]::Min($available, [Math]::Min(480, 300 * $scale))
        # Right-click openings also need focus here so Escape closes this menu,
        # not the search field. The border remains a focus target when offline.
        $first = @('Install', 'Uninstall', 'Info') | ForEach-Object { $sync.AppActionButtons[$_] } | Where-Object IsEnabled | Select-Object -First 1
        if ($first) { $null = $first.Focus() }
        else { $null = $sync.appPopup.Child.Focus() }
    })
}
