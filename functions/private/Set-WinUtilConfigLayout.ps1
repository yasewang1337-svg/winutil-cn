function Set-WinUtilConfigLayout {
    <# .SYNOPSIS Reflows existing settings panels without rebuilding controls or changing their state. #>
    param(
        [Windows.Controls.Grid]$Grid,
        [double]$AvailableWidth = 0
    )

    if (-not $Grid) {
        if (-not $sync.Form) { return }
        foreach ($name in @('tweakspanel', 'featurespanel')) {
            $target = $sync.Form.FindName($name)
            if ($target) { Set-WinUtilConfigLayout -Grid $target -AvailableWidth $AvailableWidth }
        }
        return
    }
    $panels = @($Grid.Children | Where-Object { $_ -is [Windows.Controls.Border] })
    if ($panels.Count -eq 0) { return }

    # A horizontally scrollable Grid can be wider than the usable viewport.
    # Measure the viewport first so oversized content cannot force two columns.
    if ($AvailableWidth -le 0 -or [double]::IsNaN($AvailableWidth)) {
        $ancestor = [Windows.Media.VisualTreeHelper]::GetParent($Grid)
        while ($ancestor) {
            if ($ancestor -is [Windows.Controls.ScrollViewer] -and $ancestor.ViewportWidth -gt 0) {
                $AvailableWidth = $ancestor.ViewportWidth
                break
            }
            $ancestor = [Windows.Media.VisualTreeHelper]::GetParent($ancestor)
        }
        $content = if ($sync.Form) { $sync.Form.FindName('PageContentGrid') }
        if ($content -and $content.ActualWidth -gt 0) {
            if ($AvailableWidth -le 0) { $AvailableWidth = $content.ActualWidth }
            else { $AvailableWidth = [math]::Min($AvailableWidth, $content.ActualWidth) }
        }
        if ($AvailableWidth -le 0) { $AvailableWidth = $Grid.ActualWidth }
    }
    if ($AvailableWidth -le 0 -or [double]::IsNaN($AvailableWidth) -or [double]::IsInfinity($AvailableWidth)) { return }
    $scale = if ($sync.UiScaleFactor) { [math]::Max(1.0, [double]$sync.UiScaleFactor) } else { 1.0 }
    $columns = if ($AvailableWidth -lt (820 * $scale)) { 1 } else { [math]::Min(2, $panels.Count) }
    if ($Grid.Resources['WinUtilConfigColumnCount'] -eq $columns) { return }
    $Grid.Resources['WinUtilConfigColumnCount'] = $columns

    $Grid.ColumnDefinitions.Clear()
    $Grid.RowDefinitions.Clear()
    for ($index = 0; $index -lt $columns; $index++) {
        $column = [Windows.Controls.ColumnDefinition]::new()
        $column.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
        $Grid.ColumnDefinitions.Add($column)
    }
    $rows = [int][math]::Ceiling($panels.Count / [double]$columns)
    for ($index = 0; $index -lt $rows; $index++) {
        $row = [Windows.Controls.RowDefinition]::new()
        $row.Height = [Windows.GridLength]::Auto
        $Grid.RowDefinitions.Add($row)
    }
    for ($index = 0; $index -lt $panels.Count; $index++) {
        [Windows.Controls.Grid]::SetColumn($panels[$index], $index % $columns)
        [Windows.Controls.Grid]::SetRow($panels[$index], [int][math]::Floor($index / [double]$columns))
    }
}
