function Initialize-WinUtilSettingToolTip {
    <# .SYNOPSIS Materializes a setting's full description only on hover or F1. #>
    param([Parameter(Mandatory)][Windows.Controls.Border]$Row)
    if ($Row.ToolTip -is [Windows.Controls.ToolTip]) { return }
    $details = $Row.Tag
    if (-not $details.WinUtilSettingRow) { return }
    $tip = [Windows.Controls.ToolTip]::new()
    $tip.Resources.MergedDictionaries.Add($sync.Form.Resources)
    $tip.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'ToolTipBackgroundColor')
    $tip.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'MainForegroundColor')
    $tip.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'BorderColor')
    $tip.SetResourceReference([Windows.Controls.Control]::FontFamilyProperty, 'FontFamily')
    $tip.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, 'FontSize')
    $tip.SetResourceReference([Windows.FrameworkElement]::MaxWidthProperty, 'ToolTipWidth')
    $tip.Padding = '14'
    $content = [Windows.Controls.StackPanel]::new()
    $title = [Windows.Controls.TextBlock]::new()
    $title.Text = $details.Title
    $title.TextWrapping = 'Wrap'
    $title.FontWeight = 'SemiBold'
    $title.SetResourceReference([Windows.Controls.TextBlock]::FontSizeProperty, 'HeaderFontSize')
    $null = $content.Children.Add($title)
    if (-not [string]::IsNullOrWhiteSpace($details.Description)) {
        $description = [Windows.Controls.TextBlock]::new()
        $description.Text = $details.Description
        $description.TextWrapping = 'Wrap'
        $description.Margin = '0,8,0,0'
        $null = $content.Children.Add($description)
    }
    $hintText = switch ($details.Kind) {
        'Selection' { '勾选只加入待办；点击页面操作按钮后再执行。' }
        'Immediate' { '操作这个开关会直接应用设置。' }
        'Choice' { '先选择选项，再使用对应操作按钮。' }
        default { '' }
    }
    if ($hintText) {
        $hint = [Windows.Controls.TextBlock]::new()
        $hint.Text = $hintText
        $hint.TextWrapping = 'Wrap'
        $hint.Margin = '0,10,0,0'
        $hint.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'SecondaryForegroundColor')
        $null = $content.Children.Add($hint)
    }
    $tip.Content = $content
    $Row.ToolTip = $tip
    # Register only after this row has actually shown help. Dismiss a keyboard
    # popup when its owner loses focus or leaves the active/filtered page.
    $Row.Add_LostKeyboardFocus({
        param($sender, $eventArgs)
        if (-not $sender.IsKeyboardFocusWithin -and $sender.ToolTip -is [Windows.Controls.ToolTip]) {
            $sender.ToolTip.IsOpen = $false
        }
    })
    $Row.Add_IsVisibleChanged({
        param($sender, $eventArgs)
        if (-not $eventArgs.NewValue -and $sender.ToolTip -is [Windows.Controls.ToolTip]) {
            $sender.ToolTip.IsOpen = $false
        }
    })
}
