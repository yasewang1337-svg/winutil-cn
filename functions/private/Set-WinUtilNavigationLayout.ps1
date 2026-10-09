function Set-WinUtilNavigationLayout {
    <# .SYNOPSIS Keeps page content usable by collapsing navigation labels on narrow windows. #>
    param([double]$AvailableWidth = 0)
    if (-not $sync.Form) { return }
    $grid = $sync.Form.FindName('WPFMainGrid')
    if (-not $grid -or $grid.ColumnDefinitions.Count -lt 2) { return }
    if ($AvailableWidth -le 0) { $AvailableWidth = $sync.Form.ActualWidth }
    if ($AvailableWidth -le 0) { $AvailableWidth = $sync.Form.Width }
    if ([double]::IsNaN($AvailableWidth) -or $AvailableWidth -le 0) { $AvailableWidth = 1200 }
    $compact = $AvailableWidth -le 1000
    $grid.ColumnDefinitions[0].Width = [Windows.GridLength]::new($(if ($compact) { 56 } else { 184 }))
    foreach ($number in 1..6) {
        $label = $sync.Form.FindName("WPFTab${number}Label")
        if ($label) { $label.Visibility = $(if ($compact) { 'Collapsed' } else { 'Visible' }) }
    }
    $content = $sync.Form.FindName('PageContentGrid')
    if ($content) { $content.Margin = [Windows.Thickness]::new($(if ($compact) { 12 } else { 20 }),12,$(if ($compact) { 12 } else { 20 }),0) }
}
