function Find-TweaksByNameOrDescription {
    <# .SYNOPSIS Filters setting rows by literal text without changing pending choices. #>
    param([string]$SearchString = '')
    if (-not $sync -or -not $sync.Form) { return }
    $panel = $sync.Form.FindName('tweakspanel')
    if (-not $panel) { return }
    $SearchString = ([string]$SearchString).Trim()
    $queryChanged = $panel.Resources['WinUtilSettingSearchQuery'] -cne $SearchString
    $panel.Resources['WinUtilSettingSearchQuery'] = $SearchString
    $showAll = [string]::IsNullOrWhiteSpace($SearchString)
    $matchCount = 0
    foreach ($section in $panel.Children) {
        if ($section -isnot [Windows.Controls.Border] -or $section.Child -isnot [Windows.Controls.DockPanel]) { continue }
        $items = @($section.Child.Children | Where-Object { $_ -is [Windows.Controls.ItemsControl] })
        if ($items.Count -eq 0) { continue }
        $sectionVisible = $false
        $categoryLabel = $null
        $categoryVisible = $false
        foreach ($item in $items[0].Items) {
            if ($item -is [Windows.Controls.Label]) {
                if ($categoryLabel) { $categoryLabel.Visibility = if ($categoryVisible) { 'Visible' } else { 'Collapsed' } }
                $categoryLabel = $item
                $categoryVisible = $false
                continue
            }
            $values = @()
            if ($item -is [Windows.Controls.Border] -and $item.Tag -and $item.Tag.WinUtilSettingRow) {
                # Metadata stays stable when a plain tooltip becomes a rich popup
                # or a text label is replaced by a multi-line visual container.
                $values = @($item.Tag.Title, $item.Tag.Description, $item.Tag.Key)
            } else {
                # Keep older/extension-generated controls searchable as well.
                $controls = @($item)
                if ($item -is [Windows.Controls.Panel]) { $controls = @($item.Children) }
                foreach ($control in $controls) {
                    if ($control -is [Windows.Controls.ContentControl]) {
                        $values += [string]$control.Content
                        $values += [Windows.Automation.AutomationProperties]::GetName($control)
                        $values += [Windows.Automation.AutomationProperties]::GetHelpText($control)
                    }
                    if ($control.ToolTip -is [string]) { $values += $control.ToolTip }
                }
            }
            $matches = $showAll
            if (-not $matches) {
                foreach ($value in $values) {
                    if ([string]$value -and ([string]$value).IndexOf($SearchString, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $matches = $true
                        break
                    }
                }
            }
            $item.Visibility = if ($matches) { 'Visible' } else { 'Collapsed' }
            if ($matches) { $categoryVisible = $true; $sectionVisible = $true; $matchCount++ }
        }
        if ($categoryLabel) { $categoryLabel.Visibility = if ($categoryVisible) { 'Visible' } else { 'Collapsed' } }
        $section.Visibility = if ($sectionVisible) { 'Visible' } else { 'Collapsed' }
    }
    $emptyState = $sync.Form.FindName('WPFTweakFilterEmpty')
    if ($emptyState) { $emptyState.Visibility = if (-not $showAll -and $matchCount -eq 0) { 'Visible' } else { 'Collapsed' } }
    if ($queryChanged) {
        $scroll = $sync.Form.FindName('WPFTweaksScroll')
        if ($scroll) { $scroll.ScrollToTop() }
    }
}
