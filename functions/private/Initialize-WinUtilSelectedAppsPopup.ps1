function Initialize-WinUtilSelectedAppsPopup {
    <# .SYNOPSIS Creates a scrollable selection popup that stays open while using it. #>
    $popup = [Windows.Controls.Primitives.Popup]::new()
    $popup.PlacementTarget = $sync.WPFselectedAppsButton
    $popup.Placement = 'Bottom'
    $popup.AllowsTransparency = $true
    $null = $popup.Resources.MergedDictionaries.Add($sync.Form.Resources)
    # Keep button click toggling deterministic. Outside clicks are handled below,
    # rather than dismissing before the placement button's Click event runs.
    $popup.StaysOpen = $true
    $sync.selectedAppsPopup = $popup

    $border = [Windows.Controls.Border]::new()
    $border.Width = 320
    $border.Padding = 12
    $border.CornerRadius = 6
    $border.SetResourceReference([Windows.Documents.TextElement]::FontSizeProperty, 'ButtonFontSize')
    $border.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'PanelBackgroundColor')
    $border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'BorderColor')
    $border.BorderThickness = 1
    $popup.Child = $border
    $layout = [Windows.Controls.DockPanel]::new()
    $border.Child = $layout

    $header = [Windows.Controls.DockPanel]::new()
    $header.Margin = '2,0,2,10'
    [Windows.Controls.DockPanel]::SetDock($header, 'Top')
    $null = $layout.Children.Add($header)

    $close = [Windows.Controls.Button]::new()
    $close.Content = '关闭'
    $close.ToolTip = '关闭已选清单（Esc）'
    $close.HorizontalAlignment = 'Right'
    $close.Margin = '10,0,0,0'
    $close.Padding = '8,3,8,3'
    $close.SetResourceReference([Windows.Controls.Control]::StyleProperty, 'HoverButtonStyle')
    $close.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
    $close.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
    $close.Add_Click({
        $sync.selectedAppsPopup.IsOpen = $false
        $null = $sync.WPFselectedAppsButton.Focus()
    })
    [Windows.Controls.DockPanel]::SetDock($close, 'Right')
    $null = $header.Children.Add($close)
    $sync.SelectedAppsCloseButton = $close
    $title = [Windows.Controls.TextBlock]::new()
    $title.Text = '已选清单'
    $title.FontWeight = 'SemiBold'
    $title.VerticalAlignment = 'Center'
    $title.TextWrapping = 'Wrap'
    $title.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'MainForegroundColor')
    $title.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
    $null = $header.Children.Add($title)
    $sync.SelectedAppsTitle = $title
    $empty = [Windows.Controls.TextBlock]::new()
    $empty.Text = '还没有选择软件。在列表中勾选后，可在这里查看和移除。'
    $empty.TextWrapping = 'Wrap'
    $empty.Margin = '4,4,4,10'
    $empty.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
    $empty.SetResourceReference([Windows.Controls.TextBlock]::FontFamilyProperty, 'FontFamily')
    [Windows.Controls.DockPanel]::SetDock($empty, 'Top')
    $null = $layout.Children.Add($empty)
    $sync.SelectedAppsEmptyText = $empty

    $scroll = [Windows.Controls.ScrollViewer]::new()
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.MaxHeight = 360
    $scroll.CanContentScroll = $false
    $scroll.Focusable = $false
    $null = $layout.Children.Add($scroll)
    $sync.SelectedAppsPopupScroll = $scroll
    $sync.selectedAppsstackPanel = [Windows.Controls.StackPanel]::new()
    $scroll.Content = $sync.selectedAppsstackPanel
    [Windows.Input.KeyboardNavigation]::SetTabNavigation($border, 'Cycle')
    $popup.Add_Opened({
        $width = if ($sync.Form.ActualWidth -gt 0) { $sync.Form.ActualWidth - 32 } else { 320 }
        $height = if ($sync.Form.ActualHeight -gt 0) { $sync.Form.ActualHeight * 0.6 } else { 360 }
        $scale = if ($sync.UiScaleFactor -gt 0) { $sync.UiScaleFactor } else { 1.0 }
        $sync.selectedAppsPopup.Child.Width = [Math]::Max(160, [Math]::Min([Math]::Min(480, 360 * $scale), $width))
        $sync.SelectedAppsPopupScroll.MaxHeight = [Math]::Max(80, [Math]::Min(360, $height))
        $sync.SelectedAppsPopupScroll.ScrollToTop()
        $null = $sync.SelectedAppsCloseButton.Focus()
    })
    $border.Add_PreviewKeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Key -eq 'Escape') {
            $sync.selectedAppsPopup.IsOpen = $false
            $null = $sync.WPFselectedAppsButton.Focus()
            $eventArgs.Handled = $true
        }
    })
    $sync.Form.Add_PreviewMouseDown({
        if ($sync.selectedAppsPopup.IsOpen -and -not $sync.selectedAppsPopup.IsMouseOver -and
            -not $sync.WPFselectedAppsButton.IsMouseOver) {
            $sync.selectedAppsPopup.IsOpen = $false
        }
    })
    $sync.Form.Add_Deactivated({ $sync.selectedAppsPopup.IsOpen = $false })
}
